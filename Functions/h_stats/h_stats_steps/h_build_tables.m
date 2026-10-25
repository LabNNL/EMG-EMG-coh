function [T_row, T_subj, COH_DEFAULT, allCoh, subjects, bandSource] = h_build_tables(C, HC, ANALYSIS_TAG)
% H_BUILD_TABLES  Stage-h input tables from the stage-g results.
% T_row: one row per subject x condition x leg x pair, with <Band>_<metric>,
% cycle counts and power. T_subj: legs averaged, plus age (AgeYears, and
% AgeYears_z standardized over participants). Both are written to HC.io.tables_dir.
% Also returns the FULL results (COH_DEFAULT), all result sets (allCoh), the
% union of their subjects, and which file each band was read from (bandSource).

    % One column per configured band (C.shared_wavelet.FreqBands) for each quantity
    bandNames = fieldnames(C.g_coherence.params.FreqBands)';
    perBand = @(suffix) strcat(bandNames, suffix);
    varNamesDebug = [{'subject','age_group','condition','leg','pair_name', 'n_cycles_used', 'n_cycles_available_ref'}, ...
        perBand('_n_cycles_used_for_metric'), perBand('_cycle_count_source'), {'metric_scope','coherence_source'}, ...
        bandNames, perBand('_AUC_norm'), perBand('_Peak'), perBand('_LogPower'), ...
        perBand('_AUC_norm__raw'), perBand('_AUC_norm__cycle_bias_corrected'), perBand('_n_cycles__raw')]; % last three: sensitivity columns (run_continuous_age_sensitivity)

    %% ===================== LOAD COHERENCE RESULTS =====================

    L0 = load(HC.io.coh_mat);
    assert(isfield(L0, 'COHERENCE_RESULTS'), 'COHERENCE_RESULTS not found in default input mat file.');
    COH_DEFAULT = L0.COHERENCE_RESULTS;

    % One results file per band (COHERENCE_RESULTS_<BAND>.mat); FULL is the fallback
    COH_BAND = struct();
    bandSource = struct();
    for ib = 1:numel(bandNames)
        band = bandNames{ib};
        COH_BAND.(band) = COH_DEFAULT;
        bandSource.(band) = "default";
        if isfield(HC.analysis, 'use_band_specific_datasets') && HC.analysis.use_band_specific_datasets && ...
                isfield(HC.io, 'coh_mat_band') && isfield(HC.io.coh_mat_band, band) && isfile(HC.io.coh_mat_band.(band))
            Lband = load(HC.io.coh_mat_band.(band));
            if isfield(Lband, 'COHERENCE_RESULTS')
                COH_BAND.(band) = Lband.COHERENCE_RESULTS;
                bandSource.(band) = "band-specific";
            end
            clear Lband
        end
    end

    fprintf('\n=== Coherence sources used ===\n');
    for ib = 1:numel(bandNames)
        fprintf('%s: %s\n', bandNames{ib}, bandSource.(bandNames{ib}));
    end

    fprintf('Metric scope: %s\n', HC.analysis.metric_scope);

    %% ===================== BUILD ROW-LEVEL TABLE =====================

    fprintf('\nBuilding row-level table from merged coherence sources...\n');

    ROW = {};
    ri = 0;

    % Union of the subjects of all sources
    allCoh = [{COH_DEFAULT}, struct2cell(COH_BAND)'];
    subjects = fieldnames(COH_DEFAULT);
    for ib = 1:numel(bandNames)
        subjects = [subjects; fieldnames(COH_BAND.(bandNames{ib}))]; %#ok<AGROW>
    end
    subjects = unique(subjects);

    for iS = 1:numel(subjects)
        subjID = subjects{iS};
        age_group = subject_to_group(subjID, C);

        conds = union_of_nested_fields(allCoh, {subjID});
        for ic = 1:numel(conds)
            cond = conds{ic};

            legs = union_of_nested_fields(allCoh, {subjID, cond});
            for il = 1:numel(legs)
                leg = legs{il};

                pairNames = union_of_nested_fields(allCoh, {subjID, cond, leg});
                fprintf('Subject %s | Condition %s | Leg %s | Pairs: %s\n', subjID, cond, leg, strjoin(pairNames, ', '));
                for ip = 1:numel(pairNames)
                    pairName = pairNames{ip};

                    % Use default result as structural reference when possible
                    R_ref = get_nested_result(COH_DEFAULT, subjID, cond, leg, pairName);
                    for ib = 1:numel(bandNames)
                        if isempty(R_ref)
                            R_ref = get_nested_result(COH_BAND.(bandNames{ib}), subjID, cond, leg, pairName);
                        end
                    end

                    if isempty(R_ref)
                        continue;
                    end

                    % Minimum cycle requirement based on reference/default availability
                    nCycles = get_field_or_nan(R_ref, 'n_cycles_used');
                    if isnan(nCycles) || nCycles < HC.analysis.min_cycles_required
                        continue;
                    end

                    if ~ismember(string(pairName), string(HC.analysis.pairs_to_analyze))
                        continue;
                    end

                    % Band-specific results and their cycle counts
                    nB = numel(bandNames);
                    Rb = cell(1, nB);
                    cyc = cell(1, nB);
                    for ib = 1:nB
                        Rb{ib} = get_nested_result(COH_BAND.(bandNames{ib}), subjID, cond, leg, pairName);
                        cyc{ib} = get_metric_cycle_count_info(Rb{ib}, HC.analysis.coherence_source);
                    end
                    cycleRef = get_metric_cycle_count_info(R_ref, HC.analysis.coherence_source);
                    nCyclesAvailableRef = cycleRef.n_available;

                    src = HC.analysis.coherence_source;
                    scope = HC.analysis.metric_scope;
                    metric = @(suffix, source) arrayfun(@(ib) get_scalar_from_result(Rb{ib}, [bandNames{ib} suffix], scope, source), 1:nB, 'UniformOutput', false);

                    ri = ri + 1;
                    ROW(ri,:) = [{string(subjID), string(age_group), string(cond), string(leg), string(pairName), nCycles, nCyclesAvailableRef}, ...
                        cellfun(@(x) x.n_used_for_metric, cyc, 'UniformOutput', false), cellfun(@(x) string(x.source), cyc, 'UniformOutput', false), ...
                        {string(scope), string(src)}, ...
                        metric('', src), metric('_AUC_norm', src), metric('_Peak', src), ...
                        cellfun(@(b) get_power_by_scope(R_ref, b, scope), bandNames, 'UniformOutput', false), ...
                        metric('_AUC_norm', "raw"), metric('_AUC_norm', "cycle_bias_corrected"), ...
                        cellfun(@(R) get_metric_cycle_count_info(R, "raw").n_used_for_metric, Rb, 'UniformOutput', false)];
                end
            end
        end
    end

    if isempty(ROW)
        error('No rows could be built from COHERENCE_RESULTS.');
    end

    T_row = cell2table(ROW, 'VariableNames', varNamesDebug);

    %% ===================== CLEAN CATEGORICALS =====================

    T_row.subject   = categorical(string(T_row.subject));
    T_row.age_group = categorical(string(T_row.age_group), C.plotting.age_order, C.plotting.age_order, 'Ordinal', true);
    T_row.condition = categorical(string(T_row.condition), C.plotting.condition_order, C.plotting.condition_order, 'Ordinal', true);
    T_row.leg       = categorical(string(T_row.leg), C.design.legs, C.design.legs, 'Ordinal', true);
    T_row.pair_name = categorical(string(T_row.pair_name), HC.analysis.pairs_to_analyze, HC.analysis.pairs_to_analyze, 'Ordinal', true);

    T_row = T_row(~isundefined(T_row.age_group) & ~isundefined(T_row.condition) & ~isundefined(T_row.pair_name), :);

    fprintf('Row-level table: %d rows\n', height(T_row));

    %% ===================== SAVE RAW CLEAN TABLE =====================

    writetable(T_row, fullfile(HC.io.tables_dir, 'T_row_before_leg_average.csv'));

    %% ===================== AVERAGE LEFT / RIGHT LEGS =====================

    fprintf('\nAveraging left and right legs within subject x age_group x condition x pair...\n');

    groupVars = {'subject','age_group','condition','pair_name'};

    analysisDvList = HC.analysis.dv_list;
    powerVars = perBand('_LogPower');

    sensitivityVars = [perBand('_AUC_norm__raw'), perBand('_AUC_norm__cycle_bias_corrected'), perBand('_n_cycles__raw')];

    avgVars = unique([analysisDvList, powerVars, sensitivityVars], 'stable');

    % keep only variables that exist AND are numeric
    avgVars = avgVars(ismember(avgVars, T_row.Properties.VariableNames));

    isNumericVar = false(size(avgVars));
    for i = 1:numel(avgVars)
        isNumericVar(i) = isnumeric(T_row.(avgVars{i})) || islogical(T_row.(avgVars{i}));
    end

    if any(~isNumericVar)
        fprintf('\nSkipping non-numeric avgVars:\n');
        disp(avgVars(~isNumericVar)');
    end

    avgVars = avgVars(isNumericVar);

    G = findgroups(T_row(:, groupVars));
    T_subj = unique(T_row(:, groupVars), 'rows');

    for idv = 1:numel(avgVars)
        dv = avgVars{idv};
        T_subj.(dv) = splitapply(@(x) mean(x, 'omitnan'), T_row.(dv), G);
    end

    %% ===================== ADD CONTINUOUS AGE =====================

    metaFile = fullfile(C.paths.metadata_dir, 'participants_metadata_EMG.csv');

    META = readtable(metaFile, 'Delimiter', ';', 'TreatAsEmpty', {'NA','NaN',''});

    META.Participant = string(META.Participant);
    T_subj.subject_str = string(T_subj.subject);

    META = META(:, {'Participant','AgeMonths','Sex','Height_cm','Weight_kg','IMC'});

    T_subj = outerjoin(T_subj, META, 'LeftKeys', 'subject_str', 'RightKeys', 'Participant', 'MergeKeys', true, 'Type', 'left');

    T_subj.AgeYears = T_subj.AgeMonths ./ 12;

    % ---------------------------------------------------------
    % Standardize age using ONE observation per participant
    % ---------------------------------------------------------
    T_age_unique = unique( ...
        T_subj(:, {'subject','AgeMonths','AgeYears'}), ...
        'rows');

    % Age in months
    validAgeMonthsUnique = isfinite(T_age_unique.AgeMonths);

    muAgeMonths = mean( ...
        T_age_unique.AgeMonths(validAgeMonthsUnique), ...
        'omitnan');

    sdAgeMonths = std( ...
        T_age_unique.AgeMonths(validAgeMonthsUnique), ...
        'omitnan');

    T_subj.AgeMonths_z = ...
        (T_subj.AgeMonths - muAgeMonths) ./ sdAgeMonths;

    % Age in years
    validAgeYearsUnique = isfinite(T_age_unique.AgeYears);

    muAgeYears = mean( ...
        T_age_unique.AgeYears(validAgeYearsUnique), ...
        'omitnan');

    sdAgeYears = std( ...
        T_age_unique.AgeYears(validAgeYearsUnique), ...
        'omitnan');

    T_subj.AgeYears_z = ...
        (T_subj.AgeYears - muAgeYears) ./ sdAgeYears;

    fprintf('\n=== Age standardization ===\n');
    fprintf('Unique participants used: %d\n', ...
        sum(validAgeYearsUnique));
    fprintf('Age mean: %.3f years\n', muAgeYears);
    fprintf('Age SD:   %.3f years\n', sdAgeYears);

    % Keep metadata as non-averaged constant columns
    T_subj.metric_scope = repmat(string(HC.analysis.metric_scope), height(T_subj), 1);
    T_subj.coherence_source = repmat(string(HC.analysis.coherence_source), height(T_subj), 1);


    T_subj.n_legs_collapsed = splitapply(@numel, T_row.leg, G);

    % ---------- Legacy/reference counts ----------
    T_subj.mean_cycles_used_across_legs = splitapply(@(x) mean(x, 'omitnan'), T_row.n_cycles_used, G);

    T_subj.min_cycles_used_across_legs = splitapply(@(x) min(x, [], 'omitnan'), T_row.n_cycles_used, G);

    T_subj.mean_cycles_available_ref_across_legs = splitapply(@(x) mean(x, 'omitnan'), T_row.n_cycles_available_ref, G);

    T_subj.min_cycles_available_ref_across_legs = splitapply(@(x) min(x, [], 'omitnan'), T_row.n_cycles_available_ref, G);

    % ---------- Band-specific actual cycles used for selected metric source ----------
    for ib = 1:numel(bandNames)
        band = bandNames{ib};
        T_subj.([band '_mean_cycles_used_for_metric_across_legs']) = splitapply(@(x) mean(x, 'omitnan'), T_row.([band '_n_cycles_used_for_metric']), G);
        T_subj.([band '_min_cycles_used_for_metric_across_legs']) = splitapply(@(x) min(x, [], 'omitnan'), T_row.([band '_n_cycles_used_for_metric']), G);
    end

    % ---------- Create band-specific log cycle variables ----------
    fprintf('\n=== Source-specific cycle-count variables created ===\n');
    fprintf('Coherence source: %s\n', string(HC.analysis.coherence_source));
    for ib = 1:numel(bandNames)
        band = bandNames{ib};
        T_subj.([band '_log_n_cycles']) = log_safe(T_subj.([band '_mean_cycles_used_for_metric_across_legs']));
        fprintf('Valid %s_log_n_cycles rows: %d / %d\n', band, sum(isfinite(T_subj.([band '_log_n_cycles']))), height(T_subj));
    end

    fprintf('Subject-level table after leg averaging: %d rows\n', height(T_subj));

    writetable(T_subj, fullfile(HC.io.tables_dir, sprintf('T_subject_after_leg_average__%s.csv', ANALYSIS_TAG)));

    % Optional latest-copy file
    writetable(T_subj, fullfile(HC.io.tables_dir, 'T_subject_after_leg_average.csv'));
end
