function spmInfo = run_spm_mixed_age_condition_on_spectrum(T, ageLevels, condLevels, freqRef, HS)
%RUN_SPM_MIXED_AGE_CONDITION_ON_SPECTRUM
% Mixed spectrum SPM:
%   age_group = between-subject factor
%   condition = within-subject repeated factor
%   subject   = repeated unit
%
% Input T should already be leg-averaged:
%   one row = subject x condition x pair
%
% This function uses complete-case subjects across conditions.

    spmInfo = struct();
    spmInfo.ran = false;
    spmInfo.ok = false;
    spmInfo.label = "";
    spmInfo.spmi_age = [];
    spmInfo.spmi_condition = [];
    spmInfo.spmi_interaction = [];
    spmInfo.n_subjects = 0;
    spmInfo.n_rows = 0;
    spmInfo.age_levels_used = strings(0,1);
    spmInfo.condition_levels_used = strings(0,1);

    try
        if isempty(T)
            spmInfo.label = "Mixed SPM not run: empty table";
            return;
        end

        freqRef = freqRef(:)';
        nFreqRef = numel(freqRef);

        % ---------- keep only valid requested age/condition levels ----------
        ageLevels = string(ageLevels(:));
        condLevels = string(condLevels(:));

        ageLevels = ageLevels(ageLevels ~= "");
        condLevels = condLevels(condLevels ~= "");

        if numel(ageLevels) < 2 || numel(condLevels) < 2
            spmInfo.label = "Mixed SPM not run: need >=2 age groups and >=2 conditions";
            return;
        end

        % ---------- complete-case subjects across conditions ----------
        if ~isfield(HS, 'mixed_require_complete_case') || HS.mixed_require_complete_case
            Tcc = keep_only_complete_subjects_for_conditions(T, cellstr(condLevels));
        else
            Tcc = T;
        end

        if isempty(Tcc)
            spmInfo.label = "Mixed SPM not run: no complete-case subjects";
            return;
        end

        subjList = categories(removecats(Tcc.subject));

        Y = [];
        A = [];      % age-group labels
        B = [];      % condition labels
        SUBJ = [];   % subject labels

        subjCounter = 0;
        ageUsed = strings(0,1);

        for iS = 1:numel(subjList)

            s = subjList{iS};
            Ts = Tcc(Tcc.subject == s, :);

            % Each subject should have one age group
            agHere = categories(removecats(Ts.age_group));
            if numel(agHere) ~= 1
                continue;
            end

            ag = string(agHere{1});
            ia = find(ageLevels == ag, 1);

            if isempty(ia)
                continue;
            end

            % Require all conditions for this subject
            condPresent = string(categories(removecats(Ts.condition)));
            if ~all(ismember(condLevels, condPresent))
                continue;
            end

            subjCounter = subjCounter + 1;
            ageUsed(end+1,1) = ag; %#ok<AGROW>

            for ic = 1:numel(condLevels)

                cName = condLevels(ic);
                idx = Ts.condition == cName;

                if ~any(idx)
                    continue;
                end

                X = collect_curve_matrix_from_table(Ts.Spectrum(idx));

                if isempty(X)
                    continue;
                end

                X = double(X);

                % enforce orientation
                if size(X,2) ~= nFreqRef
                    if size(X,1) == nFreqRef && size(X,2) ~= nFreqRef
                        X = X';
                    end
                end

                if size(X,2) ~= nFreqRef
                    warning('Skipping %s | %s because spectrum width is inconsistent.', string(s), string(cName));
                    continue;
                end

                % If somehow multiple rows exist for subject-condition,
                % average them so one row = subject x condition.
                xmean = mean(X, 1, 'omitnan');

                Y = [Y; xmean]; %#ok<AGROW>
                A = [A; ia]; %#ok<AGROW>
                B = [B; ic]; %#ok<AGROW>
                SUBJ = [SUBJ; subjCounter]; %#ok<AGROW>
            end
        end

        if isempty(Y)
            spmInfo.label = "Mixed SPM not run: empty Y";
            return;
        end

        % Remove subjects who did not successfully contribute all conditions
        subjIDs = unique(SUBJ);
        keepRows = false(size(SUBJ));

        for i = 1:numel(subjIDs)
            sid = subjIDs(i);
            rows = find(SUBJ == sid);

            if numel(unique(B(rows))) == numel(condLevels)
                keepRows(rows) = true;
            end
        end

        Y = Y(keepRows,:);
        A = A(keepRows);
        B = B(keepRows);
        SUBJ = SUBJ(keepRows);

        if isempty(Y) || numel(unique(A)) < 2 || numel(unique(B)) < 2
            spmInfo.label = "Mixed SPM not run: insufficient age or condition levels after filtering";
            return;
        end

        spmInfo.n_subjects = numel(unique(SUBJ));
        spmInfo.n_rows = size(Y,1);
        spmInfo.age_levels_used = unique(ageLevels(A), 'stable');
        spmInfo.condition_levels_used = unique(condLevels(B), 'stable');

        fprintf('\n=== MIXED AGE x CONDITION SPM INPUT ===\n');
        fprintf('Subjects used: %d\n', spmInfo.n_subjects);
        fprintf('Rows used:     %d\n', spmInfo.n_rows);
        fprintf('Age levels:    %s\n', strjoin(spmInfo.age_levels_used, ', '));
        fprintf('Conditions:    %s\n', strjoin(spmInfo.condition_levels_used, ', '));

        fprintf('which parametric anova2onerm: %s\n', which('spm1d.stats.anova2onerm'));
        fprintf('which nonparam anova2onerm:   %s\n', which('spm1d.stats.nonparam.anova2onerm'));

        P = make_spectrum_spm_params(HS);

        fprintf('Running %s mixed age x condition SPM...\n', get_spm_method_label_switch(P));

        [spmInfo.spmi_age, spmInfo.spmi_condition, spmInfo.spmi_interaction, testName] = run_spm_anova2onerm_switch(Y, A, B, SUBJ, P);

        spmInfo.testName = testName;
        spmInfo.methodLabel = get_spm_method_label_switch(P);
        spmInfo.ran = true;
        spmInfo.ok = true;
        spmInfo.label = sprintf('%s mixed age x condition p < %.3f', spmInfo.methodLabel, P.alpha);

    catch ME
        spmInfo.ran = true;
        spmInfo.ok = false;
        spmInfo.label = sprintf('Mixed SPM failed: %s', ME.message);
        warning('%s', spmInfo.label);
    end
end

function [spmi_age, spmi_condition, spmi_interaction, testName] = run_spm_anova2onerm_switch(Y, A, B, SUBJ, P)
% Mixed two-way ANOVA:
%   A = between-subject factor, usually age group
%   B = repeated factor, usually condition
%   SUBJ = subject labels

    if P.use_nonparametric
        assert(~isempty(which('spm1d.stats.nonparam.anova2onerm')), 'Non-parametric anova2onerm not found in this SPM1D installation.');

        spm_all = spm1d.stats.nonparam.anova2onerm(Y, A, B, SUBJ);
        testName = "SnPM anova2onerm";
    else
        spm_all = spm1d.stats.anova2onerm(Y, A, B, SUBJ);
        testName = "SPM anova2onerm";
    end

    spm_age         = unpack_spm_list_effect(spm_all, 1);
    spm_condition   = unpack_spm_list_effect(spm_all, 2);
    spm_interaction = unpack_spm_list_effect(spm_all, 3);

    spmi_age         = infer_spm_object_switch(spm_age, P, false);
    spmi_condition   = infer_spm_object_switch(spm_condition, P, false);
    spmi_interaction = infer_spm_object_switch(spm_interaction, P, false);
end

function spmEffect = unpack_spm_list_effect(spm_all, effectIdx)
%UNPACK_SPM_LIST_EFFECT
% Works with:
%   parametric SPMFList
%   nonparametric SnPM1D_FList
%
% effectIdx:
%   1 = Main A
%   2 = Main B
%   3 = Interaction AB

    spmEffect = [];

    if isempty(spm_all)
        error('SPM/SnPM output list is empty.');
    end

    % Best case: list supports round indexing
    try
        spmEffect = spm_all(effectIdx);
        return;
    catch
    end

    % Fallback: .SPMs property/field
    try
        S = spm_all.SPMs;

        if iscell(S)
            spmEffect = S{effectIdx};
        else
            spmEffect = S(effectIdx);
        end

        return;
    catch
    end

    error('Could not unpack SPM/SnPM list effect %d. class=%s, size=%s, numel=%d', effectIdx, class(spm_all), mat2str(size(spm_all)), numel(spm_all));
end
