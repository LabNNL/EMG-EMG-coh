function spmInfo = run_spm_age_on_spectrum(T, ageLevels, freqRef, HS)

    spmInfo = struct('ran', false, 'ok', false, 'label', '', 'clusters', [], 'spmi', [], 'nTimePoints', 0);

    try
        Y = [];
        A = [];

        freqRef = freqRef(:)';
        nFreqRef = numel(freqRef);

        for ig = 1:numel(ageLevels)
            gName = ageLevels{ig};
            idx = T.age_group == gName;

            if sum(idx) < HS.min_subjects_per_group
                continue;
            end

            specs = T.Spectrum(idx);

            if iscell(specs)
                X = cat(1, specs{:});
            else
                X = specs;
            end

            X = squeeze(X);

            if isvector(X)
                X = X(:)';
            end

            % keep only spectra with correct width
            if size(X,2) ~= nFreqRef
                if size(X,1) == nFreqRef && size(X,2) ~= nFreqRef
                    X = X';
                end
            end

            if size(X,2) ~= nFreqRef
                warning('Skipping one age-group block in SPM because spectrum width is inconsistent.');
                continue;
            end

            Y = [Y; X]; %#ok<AGROW>
            A = [A; repmat(ig, size(X,1), 1)]; %#ok<AGROW>
        end

        if isempty(Y) || numel(unique(A)) < 2
            spmInfo.label = 'Age SPM not run';
            return;
        end

        P = make_spectrum_spm_params(HS);

        [spmi, testName] = run_spm_anova1_switch(Y, A, P);

        spmInfo.spmi = spmi;
        spmInfo.testName = testName;
        spmInfo.methodLabel = get_spm_method_label_switch(P);
        spmInfo.ran = true;
        spmInfo.ok = true;
        spmInfo.label = sprintf('Age SPM p < %.3f', HS.spm_alpha);
        spmInfo.clusters = extract_spm_clusters(spmi, freqRef);
        spmInfo.spmi = spmi;
        spmInfo.nTimePoints = numel(freqRef);

    catch ME
        spmInfo.ran = true;
        spmInfo.ok = false;
        spmInfo.label = sprintf('Age SPM failed: %s', ME.message);
        spmInfo.clusters = [];
        spmInfo.spmi = [];
        spmInfo.nTimePoints = 0;
    end
end

function [spmi, testName] = run_spm_anova1_switch(Y, A, P)
% Between-subject one-way ANOVA: age effect within condition, etc.

    if P.use_nonparametric
        assert(~isempty(which('spm1d.stats.nonparam.anova1')), 'Non-parametric anova1 not found in this SPM1D installation.');

        spm = spm1d.stats.nonparam.anova1(Y, A);
        testName = "SnPM anova1";
    else
        spm = spm1d.stats.anova1(Y, A);
        testName = "SPM anova1";
    end

    spmi = infer_spm_object_switch(spm, P, false);
end
