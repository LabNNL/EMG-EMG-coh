function spmInfo = run_spm_condition_on_spectrum(T, condLevels, freqRef, HS)

    spmInfo = struct('ran', false, 'ok', false, 'label', '', 'clusters', [], 'spmi', [], 'nTimePoints', 0);

    try
        subj = categories(removecats(T.subject));
        subjKeep = {};

        for i = 1:numel(subj)
            s = subj{i};
            Ts = T(T.subject == s, :);
            condPresent = categories(removecats(Ts.condition));

            if HS.require_complete_case_for_condition
                if all(ismember(condLevels, condPresent))
                    subjKeep{end+1} = s; %#ok<AGROW>
                end
            else
                if numel(condPresent) >= 2
                    subjKeep{end+1} = s; %#ok<AGROW>
                end
            end
        end

        if isempty(subjKeep)
            spmInfo.label = 'Condition SPM not run';
            return;
        end

        Y = [];
        A = [];
        SUBJ = [];

        freqRef = freqRef(:)';
        nFreqRef = numel(freqRef);

        subjCounter = 0;

        for i = 1:numel(subjKeep)
            subjCounter = subjCounter + 1;
            s = subjKeep{i};

            for ic = 1:numel(condLevels)
                cName = condLevels{ic};
                idx = T.subject == s & T.condition == cName;

                if ~any(idx)
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

                if size(X,2) ~= nFreqRef
                    if size(X,1) == nFreqRef && size(X,2) ~= nFreqRef
                        X = X';
                    end
                end

                if size(X,2) ~= nFreqRef
                    warning('Skipping one subject-condition block in SPM because spectrum width is inconsistent.');
                    continue;
                end

                xmean = mean(X, 1, 'omitnan');

                Y = [Y; xmean]; %#ok<AGROW>
                A = [A; ic]; %#ok<AGROW>
                SUBJ = [SUBJ; subjCounter]; %#ok<AGROW>
            end
        end

        if isempty(Y) || numel(unique(A)) < 2 || numel(unique(SUBJ)) < 2
            spmInfo.label = 'Condition SPM not run';
            return;
        end

        P = make_spectrum_spm_params(HS);

        [spmi, testName] = run_spm_anova1rm_switch(Y, A, SUBJ, P);

        spmInfo.spmi = spmi;
        spmInfo.testName = testName;
        spmInfo.methodLabel = get_spm_method_label_switch(P);
        spmInfo.spmi = spmi;

        spmInfo.ran = true;
        spmInfo.ok = true;
        spmInfo.label = sprintf('Condition SPM p < %.3f', HS.spm_alpha);
        spmInfo.clusters = extract_spm_clusters(spmi, freqRef);
        spmInfo.nTimePoints = numel(freqRef);

    catch ME
        spmInfo.ran = true;
        spmInfo.ok = false;
        spmInfo.label = sprintf('Condition SPM failed: %s', ME.message);
        spmInfo.clusters = [];
        spmInfo.spmi = [];
        spmInfo.nTimePoints = 0;
    end
end

function [spmi, testName] = run_spm_anova1rm_switch(Y, A, SUBJ, P)
% Repeated-measures one-way ANOVA: condition effect within subjects.

    if P.use_nonparametric
        assert(~isempty(which('spm1d.stats.nonparam.anova1rm')), 'Non-parametric anova1rm not found in this SPM1D installation.');

        spm = spm1d.stats.nonparam.anova1rm(Y, A, SUBJ);
        testName = "SnPM anova1rm";
    else
        spm = spm1d.stats.anova1rm(Y, A, SUBJ);
        testName = "SPM anova1rm";
    end

    spmi = infer_spm_object_switch(spm, P, false);
end