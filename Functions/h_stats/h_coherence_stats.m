%% h_coherence_stats.m
% Statistical analysis of EMG-EMG coherence
%
% GOAL
% -------------------------------------------------------------------------
% Test developmental and surface-related differences in EMG-EMG coherence.
%
% Primary analysis:
%   - continuous age
%   - condition
%   - continuous age x condition
%
% CURRENT PRIMARY ANALYSIS
% -------------------------------------------------------------------------
% - pair-specific, wavelet-QC band-specific datasets
% - unthresholded coherence computed from equalized cycle subsets
% - bandwidth-normalized AUC within pair-specific phase of interest
% - TAprox-TAdist and SOL-GM analyzed separately
% - alpha, beta, and gamma analyzed separately
% - left/right legs averaged within participant and condition
% - primary LME:
%       AUC ~ AgeYears_z * condition + (1|subject)
%
% OUTPUT
% -------------------------------------------------------------------------
% - clean long table before leg averaging
% - clean subject-level table after leg averaging
% - descriptive tables
% - model text files
% - omnibus summary table
% - post hoc tables
% - boxplots
%
% NOTES
% -------------------------------------------------------------------------
% This script intentionally does NOT focus on:
% - full-band metrics
% - stance/swing analyses
% - band-long / phase-long pooled models
% - asymmetry analyses
%
% Those can be added later in separate blocks if needed.
function h_coherence_stats()
    clc; clear; close all;

    %% ===================== SETUP =====================

    C = config_emg();

    addpath(genpath(C.paths.helpers.general));
    addpath(genpath(C.paths.helpers.stats));

    HC = C.h_stats;

    ANALYSIS_TAG = make_h_stats_analysis_tag(HC);

    fprintf('\n=== H-STATS ANALYSIS TAG ===\n');
    fprintf('%s\n', ANALYSIS_TAG);

    if isfield(HC.analysis, 'scalar_metric_families')
        fprintf('Scalar metric families: %s\n', strjoin(string(HC.analysis.scalar_metric_families), ', '));
    end

    fprintf('Dependent variables analyzed:\n');
    disp(HC.analysis.dv_list(:));

    includeCycleCov = isfield(HC.analysis, 'include_cycle_count_covariate') && HC.analysis.include_cycle_count_covariate;

    if includeCycleCov && ~strcmpi(string(HC.analysis.coherence_source), "raw")
        warning(['Cycle-count covariate is enabled, but coherence_source is not raw. ' 'For the Bokil-inspired main comparison, use coherence_source = "raw".']);
    end

    if ~exist(HC.io.out_dir, 'dir'), mkdir(HC.io.out_dir); end
    if ~exist(HC.io.tables_dir, 'dir'), mkdir(HC.io.tables_dir); end
    if ~exist(HC.io.models_dir, 'dir'), mkdir(HC.io.models_dir); end
    if ~exist(HC.io.plots_dir, 'dir'), mkdir(HC.io.plots_dir); end
    if ~exist(HC.io.mat_dir, 'dir'), mkdir(HC.io.mat_dir); end
    if ~exist(HC.io.band_triplet_dir, 'dir'), mkdir(HC.io.band_triplet_dir); end

    fprintf('\n=== Running coherence stats: pair-specific main phase analysis ===\n');

    varNamesDebug = { 'subject','age_group','condition','leg','pair_name', 'n_cycles_used', 'n_cycles_available_ref', 'Alpha_n_cycles_used_for_metric', 'Beta_n_cycles_used_for_metric', 'Gamma_n_cycles_used_for_metric', 'Alpha_cycle_count_source', 'Beta_cycle_count_source', 'Gamma_cycle_count_source', 'metric_scope','coherence_source', 'Alpha','Beta','Gamma', 'Alpha_AUC_norm','Beta_AUC_norm','Gamma_AUC_norm', 'Alpha_Peak','Beta_Peak','Gamma_Peak', 'Alpha_LogPower','Beta_LogPower','Gamma_LogPower'};

    contAgeLmmPlotDir = fullfile(HC.io.plots_dir, 'continuous_age_lmm_by_condition');
    if ~exist(contAgeLmmPlotDir, 'dir')
        mkdir(contAgeLmmPlotDir);
    end

    %% ===================== LOAD COHERENCE RESULTS =====================

    L0 = load(HC.io.coh_mat);
    assert(isfield(L0, 'COHERENCE_RESULTS'), 'COHERENCE_RESULTS not found in default input mat file.');
    COH_DEFAULT = L0.COHERENCE_RESULTS;

    COH_ALPHA = COH_DEFAULT;
    COH_BETA  = COH_DEFAULT;
    COH_GAMMA = COH_DEFAULT;

    alpha_source = "default";
    beta_source  = "default";
    gamma_source = "default";

    if isfield(HC.analysis, 'use_band_specific_datasets') && HC.analysis.use_band_specific_datasets

        if isfield(HC.io, 'coh_mat_alpha') && isfile(HC.io.coh_mat_alpha)
            La = load(HC.io.coh_mat_alpha);
            if isfield(La, 'COHERENCE_RESULTS')
                COH_ALPHA = La.COHERENCE_RESULTS;
                alpha_source = "band-specific";
            end
        end

        if isfield(HC.io, 'coh_mat_beta') && isfile(HC.io.coh_mat_beta)
            Lb = load(HC.io.coh_mat_beta);
            if isfield(Lb, 'COHERENCE_RESULTS')
                COH_BETA = Lb.COHERENCE_RESULTS;
                beta_source = "band-specific";
            end
        end

        if isfield(HC.io, 'coh_mat_gamma') && isfile(HC.io.coh_mat_gamma)
            Lg = load(HC.io.coh_mat_gamma);
            if isfield(Lg, 'COHERENCE_RESULTS')
                COH_GAMMA = Lg.COHERENCE_RESULTS;
                gamma_source = "band-specific";
            end
        end
    end

    fprintf('\n=== Coherence sources used ===\n');
    fprintf('Alpha: %s\n', alpha_source);
    fprintf('Beta : %s\n', beta_source);
    fprintf('Gamma: %s\n', gamma_source);

    fprintf('Metric scope: %s\n', HC.analysis.metric_scope);

    %% ===================== BUILD ROW-LEVEL TABLE =====================

    fprintf('\nBuilding row-level table from merged coherence sources...\n');

    ROW = {};
    ri = 0;

    % Use union of all possible subjects from the 3 sources
    subjects = unique([ fieldnames(COH_DEFAULT); fieldnames(COH_ALPHA); fieldnames(COH_BETA); fieldnames(COH_GAMMA)]);

    for iS = 1:numel(subjects)
        subjID = subjects{iS};
        age_group = subject_to_group(subjID, C);

        conds = union_of_nested_fields({COH_DEFAULT, COH_ALPHA, COH_BETA, COH_GAMMA}, {subjID});
        for ic = 1:numel(conds)
            cond = conds{ic};

            legs = union_of_nested_fields({COH_DEFAULT, COH_ALPHA, COH_BETA, COH_GAMMA}, {subjID, cond});
            for il = 1:numel(legs)
                leg = legs{il};

                pairNames = union_of_nested_fields({COH_DEFAULT, COH_ALPHA, COH_BETA, COH_GAMMA}, {subjID, cond, leg});
                fprintf('Subject %s | Condition %s | Leg %s | Pairs: %s\n', subjID, cond, leg, strjoin(pairNames, ', '));
                for ip = 1:numel(pairNames)
                    pairName = pairNames{ip};

                    % Use default result as structural reference when possible
                    R_ref = get_nested_result(COH_DEFAULT, subjID, cond, leg, pairName);
                    if isempty(R_ref)
                        R_ref = get_nested_result(COH_ALPHA, subjID, cond, leg, pairName);
                    end
                    if isempty(R_ref)
                        R_ref = get_nested_result(COH_BETA, subjID, cond, leg, pairName);
                    end
                    if isempty(R_ref)
                        R_ref = get_nested_result(COH_GAMMA, subjID, cond, leg, pairName);
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

                    % Band-specific results
                    R_alpha = get_nested_result(COH_ALPHA, subjID, cond, leg, pairName);
                    R_beta  = get_nested_result(COH_BETA,  subjID, cond, leg, pairName);
                    R_gamma = get_nested_result(COH_GAMMA, subjID, cond, leg, pairName);

                    % ---------- Source-specific cycle counts for each band ----------
                    cycleRef   = get_metric_cycle_count_info(R_ref,   HC.analysis.coherence_source);
                    cycleAlpha = get_metric_cycle_count_info(R_alpha, HC.analysis.coherence_source);
                    cycleBeta  = get_metric_cycle_count_info(R_beta,  HC.analysis.coherence_source);
                    cycleGamma = get_metric_cycle_count_info(R_gamma, HC.analysis.coherence_source);

                    nCyclesAvailableRef = cycleRef.n_available;

                    ri = ri + 1;

                    ROW(ri,:) = { string(subjID), string(age_group), string(cond), string(leg), string(pairName), nCycles, nCyclesAvailableRef, cycleAlpha.n_used_for_metric, cycleBeta.n_used_for_metric, cycleGamma.n_used_for_metric, string(cycleAlpha.source), string(cycleBeta.source), string(cycleGamma.source), string(HC.analysis.metric_scope), string(HC.analysis.coherence_source), get_scalar_from_result(R_alpha, 'Alpha', HC.analysis.metric_scope, HC.analysis.coherence_source), get_scalar_from_result(R_beta,  'Beta',  HC.analysis.metric_scope, HC.analysis.coherence_source), get_scalar_from_result(R_gamma, 'Gamma', HC.analysis.metric_scope, HC.analysis.coherence_source), get_scalar_from_result(R_alpha, 'Alpha_AUC_norm', HC.analysis.metric_scope, HC.analysis.coherence_source), get_scalar_from_result(R_beta,  'Beta_AUC_norm',  HC.analysis.metric_scope, HC.analysis.coherence_source), get_scalar_from_result(R_gamma, 'Gamma_AUC_norm', HC.analysis.metric_scope, HC.analysis.coherence_source), get_scalar_from_result(R_alpha, 'Alpha_Peak', HC.analysis.metric_scope, HC.analysis.coherence_source), get_scalar_from_result(R_beta,  'Beta_Peak',  HC.analysis.metric_scope, HC.analysis.coherence_source), get_scalar_from_result(R_gamma, 'Gamma_Peak', HC.analysis.metric_scope, HC.analysis.coherence_source), get_power_by_scope(R_ref, 'Alpha', HC.analysis.metric_scope), get_power_by_scope(R_ref, 'Beta',  HC.analysis.metric_scope), get_power_by_scope(R_ref, 'Gamma', HC.analysis.metric_scope) };
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
    powerVars = {'Alpha_LogPower','Beta_LogPower','Gamma_LogPower'};

    avgVars = unique([analysisDvList, powerVars], 'stable');

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

    metaFile = fullfile(pwd, 'Metadata', 'participants_metadata_EMG.csv');

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

    dvList = HC.analysis.dv_list;

    T_subj.n_legs_collapsed = splitapply(@numel, T_row.leg, G);

    % ---------- Legacy/reference counts ----------
    T_subj.mean_cycles_used_across_legs = splitapply(@(x) mean(x, 'omitnan'), T_row.n_cycles_used, G);

    T_subj.min_cycles_used_across_legs = splitapply(@(x) min(x, [], 'omitnan'), T_row.n_cycles_used, G);

    T_subj.mean_cycles_available_ref_across_legs = splitapply(@(x) mean(x, 'omitnan'), T_row.n_cycles_available_ref, G);

    T_subj.min_cycles_available_ref_across_legs = splitapply(@(x) min(x, [], 'omitnan'), T_row.n_cycles_available_ref, G);

    % ---------- Band-specific actual cycles used for selected metric source ----------
    T_subj.Alpha_mean_cycles_used_for_metric_across_legs = splitapply(@(x) mean(x, 'omitnan'), T_row.Alpha_n_cycles_used_for_metric, G);

    T_subj.Beta_mean_cycles_used_for_metric_across_legs = splitapply(@(x) mean(x, 'omitnan'), T_row.Beta_n_cycles_used_for_metric, G);

    T_subj.Gamma_mean_cycles_used_for_metric_across_legs = splitapply(@(x) mean(x, 'omitnan'), T_row.Gamma_n_cycles_used_for_metric, G);

    T_subj.Alpha_min_cycles_used_for_metric_across_legs = splitapply(@(x) min(x, [], 'omitnan'), T_row.Alpha_n_cycles_used_for_metric, G);

    T_subj.Beta_min_cycles_used_for_metric_across_legs = splitapply(@(x) min(x, [], 'omitnan'), T_row.Beta_n_cycles_used_for_metric, G);

    T_subj.Gamma_min_cycles_used_for_metric_across_legs = splitapply(@(x) min(x, [], 'omitnan'), T_row.Gamma_n_cycles_used_for_metric, G);

    % ---------- Create band-specific log cycle variables ----------
    T_subj.Alpha_log_n_cycles = log_safe(T_subj.Alpha_mean_cycles_used_for_metric_across_legs);
    T_subj.Beta_log_n_cycles  = log_safe(T_subj.Beta_mean_cycles_used_for_metric_across_legs);
    T_subj.Gamma_log_n_cycles = log_safe(T_subj.Gamma_mean_cycles_used_for_metric_across_legs);

    fprintf('\n=== Source-specific cycle-count variables created ===\n');
    fprintf('Coherence source: %s\n', string(HC.analysis.coherence_source));
    fprintf('Valid Alpha_log_n_cycles rows: %d / %d\n', sum(isfinite(T_subj.Alpha_log_n_cycles)), height(T_subj));
    fprintf('Valid Beta_log_n_cycles rows:  %d / %d\n', sum(isfinite(T_subj.Beta_log_n_cycles)),  height(T_subj));
    fprintf('Valid Gamma_log_n_cycles rows: %d / %d\n', sum(isfinite(T_subj.Gamma_log_n_cycles)), height(T_subj));

    fprintf('Subject-level table after leg averaging: %d rows\n', height(T_subj));

    writetable(T_subj, fullfile(HC.io.tables_dir, sprintf('T_subject_after_leg_average__%s.csv', ANALYSIS_TAG)));

    % Optional latest-copy file
    writetable(T_subj, fullfile(HC.io.tables_dir, 'T_subject_after_leg_average.csv'));

    %% ===================== AGE CORRELATIONS =====================

    runAgeCorrelations = ...
        isfield(HC.analysis, 'run_age_correlations') && ...
        HC.analysis.run_age_correlations;

    % Initialize outputs for robustness
    AGE_METRIC_TABLE = table();
    AGE_COND_TABLE   = table();

    if runAgeCorrelations

        % Common settings for both age-correlation blocks
        ageCorrMetrics = HC.analysis.age_corr_metrics;

        useCycleCorr = ...
            isfield(HC.analysis, 'include_cycle_count_in_correlations') && ...
            HC.analysis.include_cycle_count_in_correlations;

        if useCycleCorr
            corrTag = "partialcyclecorr";
        else
            corrTag = "simplecorr";
        end


        %% ===================== AGE VS COHERENCE METRICS:
        %                       ONE POINT PER SUBJECT =====================

        fprintf('\nRunning age-vs-coherence correlations: one point per subject...\n');

        agePeakDir = fullfile( ...
            HC.io.plots_dir, ...
            'age_metric_correlations_one_point_per_subject');

        if ~exist(agePeakDir, 'dir')
            mkdir(agePeakDir);
        end

        AGE_METRIC_ROWS = {};
        riAP = 0;

        for ip = 1:numel(HC.analysis.pairs_to_analyze)

            pairName = string(HC.analysis.pairs_to_analyze{ip});

            Tp = T_subj(T_subj.pair_name == pairName, :);

            if isempty(Tp)
                continue;
            end

            for im = 1:numel(ageCorrMetrics)

                dv = ageCorrMetrics{im};

                if ~ismember(dv, Tp.Properties.VariableNames)
                    continue;
                end

                % Keep rows with valid age and metric
                Tm = Tp( ...
                    ~isnan(Tp.AgeMonths) & ...
                    ~isnan(Tp.(dv)), :);

                % Optional DV-specific cycle-count covariate
                [Tm, useCycleCorrThisMetric, ~] = ...
                    add_log_cycle_covariate_for_dv( ...
                        Tm, ...
                        dv, ...
                        useCycleCorr);

                if height(Tm) < 5
                    continue;
                end

                % ---------------------------------------------------------
                % Collapse to one point per subject
                % Conditions are averaged here
                % ---------------------------------------------------------
                groupVars = { ...
                    'subject', ...
                    'age_group', ...
                    'AgeMonths', ...
                    'AgeYears'};

                G = findgroups(Tm(:, groupVars));

                T_age = unique(Tm(:, groupVars), 'rows');

                T_age.metric_value = splitapply( ...
                    @(x) mean(x, 'omitnan'), ...
                    Tm.(dv), ...
                    G);

                T_age.n_observations_collapsed = splitapply( ...
                    @(x) sum(~isnan(x)), ...
                    Tm.(dv), ...
                    G);

                % Keep cycle-count covariate after collapse if available
                if ismember('log_n_cycles', Tm.Properties.VariableNames)

                    T_age.log_n_cycles = splitapply( ...
                        @(x) mean(x, 'omitnan'), ...
                        Tm.log_n_cycles, ...
                        G);
                end

                % Remove invalid observations
                T_age = T_age( ...
                    ~isnan(T_age.metric_value) & ...
                    ~isnan(T_age.AgeYears), :);

                if height(T_age) < 5
                    continue;
                end

                % ---------------------------------------------------------
                % Correlations
                % ---------------------------------------------------------
                ageYears = T_age.AgeYears;
                y = T_age.metric_value;

                [rPearson, pPearson] = corr( ...
                    ageYears, ...
                    y, ...
                    'Type', 'Pearson', ...
                    'Rows', 'complete');

                [rhoSpearman, pSpearman] = corr( ...
                    ageYears, ...
                    y, ...
                    'Type', 'Spearman', ...
                    'Rows', 'complete');

                % ---------------------------------------------------------
                % Optional partial correlation controlling for cycle count
                % ---------------------------------------------------------
                rPartialCycle = NaN;
                pPartialCycle = NaN;
                nPartialCycle = 0;

                if useCycleCorrThisMetric && ...
                        ismember('log_n_cycles', T_age.Properties.VariableNames)

                    zCycle = T_age.log_n_cycles;

                    validPartial = ...
                        isfinite(ageYears) & ...
                        isfinite(y) & ...
                        isfinite(zCycle);

                    nPartialCycle = sum(validPartial);

                    if nPartialCycle >= 5

                        [rPartialCycle, pPartialCycle] = partialcorr( ...
                            ageYears(validPartial), ...
                            y(validPartial), ...
                            zCycle(validPartial), ...
                            'Rows', 'complete');
                    end
                end

                % ---------------------------------------------------------
                % Save result row
                % ---------------------------------------------------------
                riAP = riAP + 1;

                AGE_METRIC_ROWS(riAP,:) = { ...
                    pairName, ...
                    string(dv), ...
                    height(T_age), ...
                    rPearson, ...
                    pPearson, ...
                    rhoSpearman, ...
                    pSpearman, ...
                    rPartialCycle, ...
                    pPartialCycle, ...
                    nPartialCycle, ...
                    useCycleCorrThisMetric ...
                    };

                % ---------------------------------------------------------
                % Plot
                % ---------------------------------------------------------
                fig = figure( ...
                    'Visible', HC.plot.visible, ...
                    'Color', 'w', ...
                    'Position', [100 100 650 520]);

                hold on;

                ageLevels = categories(removecats(T_age.age_group));

                for ia = 1:numel(ageLevels)

                    ag = ageLevels{ia};
                    idx = T_age.age_group == ag;

                    col = get_age_color(ag, C);

                    scatter( ...
                        ageYears(idx), ...
                        y(idx), ...
                        50, ...
                        'filled', ...
                        'MarkerFaceColor', col, ...
                        'MarkerEdgeColor', col, ...
                        'DisplayName', char(ag));
                end

                % Simple linear fit for visualization only
                mdl = fitlm(ageYears, y);

                xfit = linspace( ...
                    min(ageYears), ...
                    max(ageYears), ...
                    100)';

                yfit = predict(mdl, xfit);

                plot( ...
                    xfit, ...
                    yfit, ...
                    'k-', ...
                    'LineWidth', 1.5, ...
                    'HandleVisibility', 'off');

                xlabel('Age (years)');
                ylabel(strrep(dv, '_', ' '));

                title( ...
                    sprintf( ...
                        '%s | %s | %s %s | 1 point/subject', ...
                        pairName, ...
                        strrep(dv, '_', ' '), ...
                        string(HC.analysis.coherence_source), ...
                        get_metric_scope_label(HC.analysis.metric_scope)), ...
                    'Interpreter', 'none');

                if useCycleCorrThisMetric && isfinite(rPartialCycle)

                    txt = sprintf( ...
                        ['r = %.2f, p = %.3g, n = %d\n' ...
                        'partial r = %.2f, p = %.3g'], ...
                        rPearson, ...
                        pPearson, ...
                        height(T_age), ...
                        rPartialCycle, ...
                        pPartialCycle);

                else

                    txt = sprintf( ...
                        'r = %.2f, p = %.3g, n = %d', ...
                        rPearson, ...
                        pPearson, ...
                        height(T_age));
                end

                text( ...
                    0.05, ...
                    0.95, ...
                    txt, ...
                    'Units', 'normalized', ...
                    'Parent', gca, ...
                    'HorizontalAlignment', 'left', ...
                    'VerticalAlignment', 'top', ...
                    'FontSize', 11, ...
                    'FontWeight', 'bold', ...
                    'BackgroundColor', 'w', ...
                    'Margin', 3);

                lgd = legend( ...
                    'Location', 'southoutside', ...
                    'Orientation', 'horizontal', ...
                    'Interpreter', 'none');

                lgd.Box = 'off';

                grid on;

                apply_correlation_ylim(gca, HC, dv);

                if exist('ANALYSIS_TAG', 'var')

                    outName = sprintf( ...
                        'AGE_VS_%s__%s__%s__%s__ONE_POINT_PER_SUBJECT.png', ...
                        dv, ...
                        pairName, ...
                        ANALYSIS_TAG, ...
                        corrTag);

                else

                    outName = sprintf( ...
                        'AGE_VS_%s__%s__%s__%s__%s__ONE_POINT_PER_SUBJECT.png', ...
                        dv, ...
                        pairName, ...
                        lower(char(string(HC.analysis.metric_scope))), ...
                        lower(char(string(HC.analysis.coherence_source))), ...
                        corrTag);
                end

                saveas(fig, fullfile(agePeakDir, outName));
                close(fig);

            end
        end

        % ---------------------------------------------------------
        % Save one-point-per-subject correlation table
        % ---------------------------------------------------------
        if ~isempty(AGE_METRIC_ROWS)

            AGE_METRIC_TABLE = cell2table( ...
                AGE_METRIC_ROWS, ...
                'VariableNames', { ...
                    'pair_name', ...
                    'metric', ...
                    'n_subjects', ...
                    'r_pearson', ...
                    'p_pearson', ...
                    'rho_spearman', ...
                    'p_spearman', ...
                    'r_partial_log_n_cycles', ...
                    'p_partial_log_n_cycles', ...
                    'n_partial_log_n_cycles', ...
                    'cycle_count_control_requested' ...
                    });

            if exist('ANALYSIS_TAG', 'var')

                writetable( ...
                    AGE_METRIC_TABLE, ...
                    fullfile( ...
                        HC.io.tables_dir, ...
                        sprintf( ...
                            'AGE_METRIC_CORRELATIONS_ONE_POINT_PER_SUBJECT__%s__%s.csv', ...
                            ANALYSIS_TAG, ...
                            corrTag)));
            end

            % Optional latest-copy file
            writetable( ...
                AGE_METRIC_TABLE, ...
                fullfile( ...
                    HC.io.tables_dir, ...
                    'AGE_METRIC_CORRELATIONS_ONE_POINT_PER_SUBJECT.csv'));

            disp(AGE_METRIC_TABLE);

        else

            warning('No age-metric correlations were computed.');
        end


        %% ===================== AGE VS METRIC BY CONDITION TRIPLETS =====================

        fprintf('\nRunning age-vs-coherence by-condition triplets...\n');

        ageCondDir = fullfile( ...
            HC.io.plots_dir, ...
            'age_metric_correlations_by_condition_triplets');

        if ~exist(ageCondDir, 'dir')
            mkdir(ageCondDir);
        end

        AGE_COND_ROWS = {};
        riAC = 0;

        condOrder = cellstr(C.plotting.condition_order);

        for ip = 1:numel(HC.analysis.pairs_to_analyze)

            pairName = string(HC.analysis.pairs_to_analyze{ip});

            Tp_pair = T_subj(T_subj.pair_name == pairName, :);

            if isempty(Tp_pair)
                continue;
            end

            for im = 1:numel(ageCorrMetrics)

                dv = ageCorrMetrics{im};

                if ~ismember(dv, Tp_pair.Properties.VariableNames)
                    continue;
                end

                fig = figure( ...
                    'Visible', HC.plot.visible, ...
                    'Color', 'w', ...
                    'Position', [100 100 1650 600]);

                tl = tiledlayout( ...
                    fig, ...
                    1, ...
                    3, ...
                    'TileSpacing', 'compact', ...
                    'Padding', 'compact');

                tl.OuterPosition = [0.04 0.08 0.94 0.78];

                axAll = gobjects(1, numel(condOrder));

                for ic = 1:numel(condOrder)

                    condName = condOrder{ic};

                    ax = nexttile(tl, ic);
                    axAll(ic) = ax;

                    hold(ax, 'on');

                    Tp = Tp_pair(Tp_pair.condition == condName, :);

                    Tm = Tp( ...
                        ~isnan(Tp.AgeMonths) & ...
                        ~isnan(Tp.(dv)), :);

                    % Optional DV-specific cycle-count covariate
                    [Tm, useCycleCorrThisMetric, ~] = ...
                        add_log_cycle_covariate_for_dv( ...
                            Tm, ...
                            dv, ...
                            useCycleCorr);

                    if isempty(Tm)

                        title(ax, condName, 'Interpreter', 'none');
                        axis(ax, 'off');

                        continue;
                    end

                    % -----------------------------------------------------
                    % Collapse to one row per subject WITHIN condition
                    % -----------------------------------------------------
                    groupVars = { ...
                        'subject', ...
                        'age_group', ...
                        'AgeMonths', ...
                        'AgeYears'};

                    G = findgroups(Tm(:, groupVars));

                    T_age = unique(Tm(:, groupVars), 'rows');

                    T_age.metric_value = splitapply( ...
                        @(x) mean(x, 'omitnan'), ...
                        Tm.(dv), ...
                        G);

                    T_age.n_observations_collapsed = splitapply( ...
                        @(x) sum(~isnan(x)), ...
                        Tm.(dv), ...
                        G);

                    if ismember('log_n_cycles', Tm.Properties.VariableNames)

                        T_age.log_n_cycles = splitapply( ...
                            @(x) mean(x, 'omitnan'), ...
                            Tm.log_n_cycles, ...
                            G);
                    end

                    T_age = T_age( ...
                        ~isnan(T_age.metric_value) & ...
                        ~isnan(T_age.AgeYears), :);

                    if height(T_age) < 5

                        title( ...
                            ax, ...
                            sprintf('%s | n=%d', ...
                                condName, ...
                                height(T_age)), ...
                            'Interpreter', 'none');

                        axis(ax, 'off');

                        continue;
                    end

                    % -----------------------------------------------------
                    % Correlations
                    % -----------------------------------------------------
                    ageYears = T_age.AgeYears;
                    y = T_age.metric_value;

                    [rPearson, pPearson] = corr( ...
                        ageYears, ...
                        y, ...
                        'Type', 'Pearson', ...
                        'Rows', 'complete');

                    [rhoSpearman, pSpearman] = corr( ...
                        ageYears, ...
                        y, ...
                        'Type', 'Spearman', ...
                        'Rows', 'complete');

                    % -----------------------------------------------------
                    % Optional partial correlation controlling cycle count
                    % -----------------------------------------------------
                    rPartialCycle = NaN;
                    pPartialCycle = NaN;
                    nPartialCycle = 0;

                    if useCycleCorrThisMetric && ...
                            ismember('log_n_cycles', T_age.Properties.VariableNames)

                        zCycle = T_age.log_n_cycles;

                        validPartial = ...
                            isfinite(ageYears) & ...
                            isfinite(y) & ...
                            isfinite(zCycle);

                        nPartialCycle = sum(validPartial);

                        if nPartialCycle >= 5

                            [rPartialCycle, pPartialCycle] = partialcorr( ...
                                ageYears(validPartial), ...
                                y(validPartial), ...
                                zCycle(validPartial), ...
                                'Rows', 'complete');
                        end
                    end

                    % -----------------------------------------------------
                    % Save result row
                    % -----------------------------------------------------
                    riAC = riAC + 1;

                    AGE_COND_ROWS(riAC,:) = { ...
                        pairName, ...
                        string(dv), ...
                        string(condName), ...
                        height(T_age), ...
                        rPearson, ...
                        pPearson, ...
                        rhoSpearman, ...
                        pSpearman, ...
                        rPartialCycle, ...
                        pPartialCycle, ...
                        nPartialCycle, ...
                        useCycleCorrThisMetric ...
                        };

                    % -----------------------------------------------------
                    % Plot
                    % -----------------------------------------------------
                    ageLevels = categories(removecats(T_age.age_group));

                    for ia = 1:numel(ageLevels)

                        ag = ageLevels{ia};

                        idx = T_age.age_group == ag;

                        col = get_age_color(ag, C);

                        scatter( ...
                            ax, ...
                            ageYears(idx), ...
                            y(idx), ...
                            50, ...
                            'filled', ...
                            'MarkerFaceColor', col, ...
                            'MarkerEdgeColor', col, ...
                            'DisplayName', char(ag));
                    end

                    mdl = fitlm(ageYears, y);

                    xfit = linspace( ...
                        min(ageYears), ...
                        max(ageYears), ...
                        100)';

                    yfit = predict(mdl, xfit);

                    plot( ...
                        ax, ...
                        xfit, ...
                        yfit, ...
                        'k-', ...
                        'LineWidth', 1.5, ...
                        'HandleVisibility', 'off');

                    xlabel(ax, 'Age (years)');
                    ylabel(ax, strrep(dv, '_', ' '));

                    title( ...
                        ax, ...
                        condName, ...
                        'Interpreter', 'none');

                    if useCycleCorrThisMetric && isfinite(rPartialCycle)

                        txt = sprintf( ...
                            ['r = %.2f, p = %.3g, n = %d\n' ...
                            'partial r = %.2f, p = %.3g'], ...
                            rPearson, ...
                            pPearson, ...
                            height(T_age), ...
                            rPartialCycle, ...
                            pPartialCycle);

                    else

                        txt = sprintf( ...
                            'r = %.2f, p = %.3g, n = %d', ...
                            rPearson, ...
                            pPearson, ...
                            height(T_age));
                    end

                    text( ...
                        ax, ...
                        0.05, ...
                        0.95, ...
                        txt, ...
                        'Units', 'normalized', ...
                        'HorizontalAlignment', 'left', ...
                        'VerticalAlignment', 'top', ...
                        'FontSize', 10, ...
                        'FontWeight', 'bold', ...
                        'BackgroundColor', 'w', ...
                        'Margin', 3);

                    grid(ax, 'on');

                end

                % ---------------------------------------------------------
                % Shared y limits
                % ---------------------------------------------------------
                validAx = axAll(isgraphics(axAll));

                if isfield(HC, 'plot') && ...
                        isfield(HC.plot, 'correlation_use_fixed_ylim') && ...
                        HC.plot.correlation_use_fixed_ylim

                    for iax = 1:numel(validAx)

                        apply_correlation_ylim( ...
                            validAx(iax), ...
                            HC, ...
                            dv);
                    end

                else

                    allY = [];

                    for iax = 1:numel(validAx)

                        yl = ylim(validAx(iax));

                        allY = [allY yl]; %#ok<AGROW>
                    end

                    if ~isempty(allY)

                        yMin = min(allY);
                        yMax = max(allY);

                        yRange = yMax - yMin;

                        if yRange <= 0
                            yRange = 0.1;
                        end

                        sharedYLims = [ ...
                            yMin - 0.03*yRange, ...
                            yMax + 0.08*yRange];

                        for iax = 1:numel(validAx)

                            ylim( ...
                                validAx(iax), ...
                                sharedYLims);
                        end
                    end
                end

                sgtitle( ...
                    fig, ...
                    sprintf( ...
                        '%s | %s | %s %s | one point/subject/condition', ...
                        pairName, ...
                        strrep(dv, '_', ' '), ...
                        string(HC.analysis.coherence_source), ...
                        get_metric_scope_label(HC.analysis.metric_scope)), ...
                    'Interpreter', 'none');

                % ---------------------------------------------------------
                % Shared legend
                % ---------------------------------------------------------
                allAxes = findall(fig, 'Type', 'axes');

                hScat = findobj( ...
                    allAxes, ...
                    'Type', 'Scatter');

                if ~isempty(hScat)

                    labels = get(hScat, 'DisplayName');

                    if ischar(labels)
                        labels = {labels};
                    end

                    valid = ~cellfun(@isempty, labels);

                    hScat = hScat(valid);
                    labels = labels(valid);

                    [uniqueLabels, ia] = unique( ...
                        labels, ...
                        'stable');

                    hScat = hScat(ia);

                    legendAx = axes( ...
                        fig, ...
                        'Position', [0.70 0.91 0.27 0.06], ...
                        'Visible', 'off');

                    lgd = legend( ...
                        legendAx, ...
                        hScat, ...
                        uniqueLabels, ...
                        'Orientation', 'horizontal', ...
                        'Interpreter', 'none');

                    lgd.Box = 'off';
                    lgd.FontSize = 12;
                    lgd.ItemTokenSize = [18 12];
                    lgd.Units = 'normalized';
                    lgd.Position = [0.70 0.91 0.27 0.06];
                end

                % ---------------------------------------------------------
                % Save figure
                % ---------------------------------------------------------
                if exist('ANALYSIS_TAG', 'var')

                    outName = sprintf( ...
                        'AGE_VS_%s__%s__BY_CONDITION_TRIPLET__%s__%s.png', ...
                        dv, ...
                        pairName, ...
                        ANALYSIS_TAG, ...
                        corrTag);

                else

                    outName = sprintf( ...
                        'AGE_VS_%s__%s__BY_CONDITION_TRIPLET__%s__%s_%s.png', ...
                        dv, ...
                        pairName, ...
                        lower(char(string(HC.analysis.metric_scope))), ...
                        lower(char(string(HC.analysis.coherence_source))), ...
                        corrTag);
                end

                saveas( ...
                    fig, ...
                    fullfile(ageCondDir, outName));

                close(fig);

            end
        end

        % ---------------------------------------------------------
        % Save by-condition correlation table
        % ---------------------------------------------------------
        if ~isempty(AGE_COND_ROWS)

            AGE_COND_TABLE = cell2table( ...
                AGE_COND_ROWS, ...
                'VariableNames', { ...
                    'pair_name', ...
                    'metric', ...
                    'condition', ...
                    'n_subjects', ...
                    'r_pearson', ...
                    'p_pearson', ...
                    'rho_spearman', ...
                    'p_spearman', ...
                    'r_partial_log_n_cycles', ...
                    'p_partial_log_n_cycles', ...
                    'n_partial_log_n_cycles', ...
                    'cycle_count_control_requested' ...
                    });

            if exist('ANALYSIS_TAG', 'var')

                writetable( ...
                    AGE_COND_TABLE, ...
                    fullfile( ...
                        HC.io.tables_dir, ...
                        sprintf( ...
                            'AGE_METRIC_CORRELATIONS_BY_CONDITION__%s__%s.csv', ...
                            ANALYSIS_TAG, ...
                            corrTag)));
            end

            % Optional latest-copy file
            writetable( ...
                AGE_COND_TABLE, ...
                fullfile( ...
                    HC.io.tables_dir, ...
                    'AGE_METRIC_CORRELATIONS_BY_CONDITION.csv'));

            disp(AGE_COND_TABLE);

        else

            warning('No by-condition age-metric correlations were computed.');
        end

    else

        fprintf('\nAge correlations are disabled.\n');

    end
    %% ===================== CONTINUOUS AGE LME MODELS =====================
    C = config_emg();
    HC = C.h_stats;
    runContinuousAgeLME = isfield(HC.analysis, 'run_continuous_age_lme') && HC.analysis.run_continuous_age_lme;

    if runContinuousAgeLME

        contAgeLmm3BandPlotDir = fullfile(HC.io.plots_dir, 'continuous_age_lmm_3bands');
        if ~exist(contAgeLmm3BandPlotDir, 'dir')
            mkdir(contAgeLmm3BandPlotDir);
        end

        fprintf('\nRunning continuous-age LME models...\n');

        CONT_AGE_ROWS = {};
        riCA = 0;

        contAgeDir = fullfile(HC.io.models_dir, 'continuous_age_models');
        if ~exist(contAgeDir, 'dir')
            mkdir(contAgeDir);
        end

        useAgeConditionInteraction = isfield(HC.analysis, 'continuous_age_condition_interaction') && HC.analysis.continuous_age_condition_interaction;

        includePowerContAge = isfield(HC.analysis, 'continuous_age_include_power') && HC.analysis.continuous_age_include_power;

        includeCycleContAge = isfield(HC.analysis, 'continuous_age_include_cycle_count') && HC.analysis.continuous_age_include_cycle_count;

        includeQuadraticAge = isfield(HC.analysis, 'continuous_age_include_quadratic') && HC.analysis.continuous_age_include_quadratic;

        for ip = 1:numel(HC.analysis.pairs_to_analyze)

            pairName = string(HC.analysis.pairs_to_analyze{ip});
            Tp = T_subj(T_subj.pair_name == pairName, :);
            PLOT_3BANDS = struct();


            if isempty(Tp)
                continue;
            end

            Tp.condition = removecats(Tp.condition);
            Tp.subject   = removecats(Tp.subject);

            for idv = 1:numel(dvList)

                dv = dvList{idv};

                fprintf('\n--- 3-band plot storage debug ---\n');
                fprintf('dv = %s\n', string(dv));

                if isfield(HC.plot, 'continuous_age_lmm_3bands')
                    fprintf('3bands field exists: yes\n');
                    fprintf('3bands enable = %d\n', HC.plot.continuous_age_lmm_3bands.enable);

                    if isfield(HC.plot.continuous_age_lmm_3bands, 'metrics')
                        disp('metrics requested for 3-band plot:');
                        disp(string(HC.plot.continuous_age_lmm_3bands.metrics));
                        fprintf('is current dv requested? %d\n', ismember(string(dv), string(HC.plot.continuous_age_lmm_3bands.metrics)));
                    else
                        fprintf('No metrics field found for 3-band plot.\n');
                    end
                else
                    fprintf('3bands field exists: no\n');
                end

                if ~ismember(dv, Tp.Properties.VariableNames)
                    continue;
                end

                Tm = Tp(~isnan(Tp.(dv)) & ~isnan(Tp.AgeYears_z), :);

                if height(Tm) < 10
                    fprintf('Not enough data for continuous-age LME: %s | %s | n=%d\n', pairName, string(dv), height(Tm));
                    continue;
                end

                % ---------- age terms ----------
                Tm.AgeYears_z2 = Tm.AgeYears_z.^2;

                % ---------- optional power covariate ----------
                powerVar = "";
                usePowerInThisModel = false;

                if includePowerContAge
                    powerVar = get_power_var_for_metric(dv);

                    if strlength(powerVar) > 0 && ismember(powerVar, string(Tm.Properties.VariableNames))
                        Tm = Tm(~isnan(Tm.(char(powerVar))), :);

                        if height(Tm) >= 10
                            Tm.(char(powerVar)) = zscore(Tm.(char(powerVar)));
                            usePowerInThisModel = true;
                        end
                    end
                end

                % ---------- optional cycle-count covariate ----------
                [Tm, useCycleCovInThisModel, cycleCovSource] = add_log_cycle_covariate_for_dv(Tm, dv, includeCycleContAge);

                if useCycleCovInThisModel
                    Tm = Tm(isfinite(Tm.log_n_cycles), :);
                end

                if height(Tm) < 10
                    fprintf('Not enough data after covariate filtering: %s | %s | n=%d\n', pairName, string(dv), height(Tm));
                    continue;
                end

                % ---------- build formula ----------
                if useAgeConditionInteraction
                    ageConditionTerm = "AgeYears_z * condition";
                else
                    ageConditionTerm = "AgeYears_z + condition";
                end

                if includeQuadraticAge
                    if useAgeConditionInteraction
                        ageTerm = "AgeYears_z * condition + AgeYears_z2";
                    else
                        ageTerm = "AgeYears_z + AgeYears_z2 + condition";
                    end
                else
                    ageTerm = ageConditionTerm;
                end

                extraTerms = strings(0,1);

                if usePowerInThisModel
                    extraTerms(end+1) = powerVar; %#ok<SAGROW>
                end

                if useCycleCovInThisModel
                    extraTerms(end+1) = "log_n_cycles"; %#ok<SAGROW>
                end

                if isempty(extraTerms)
                    formula = sprintf('%s ~ %s + (1|subject)', dv, ageTerm);
                else
                    formula = sprintf('%s ~ %s + %s + (1|subject)', dv, ageTerm, strjoin(extraTerms, ' + '));
                end

                outTxt = fullfile(contAgeDir, sprintf('MODEL_CONTINUOUS_AGE__%s__%s__%s.txt', char(pairName), dv, ANALYSIS_TAG));

                fprintf('\nRunning continuous-age LME for %s | %s\n', pairName, string(dv));
                fprintf('Formula: %s\n', formula);

                lme = write_lme_report(Tm, dv, formula, outTxt);

                if isfield(HC.plot, 'continuous_age_lmm') && HC.plot.continuous_age_lmm.enable

                    outPng = fullfile(contAgeLmmPlotDir, sprintf('CONTINUOUS_AGE_LMM__%s__%s__%s__%s.png', char(pairName), dv, char(string(HC.analysis.coherence_source)), lower(char(string(HC.analysis.metric_scope)))));

                    plot_continuous_age_lmm_by_condition( Tm, lme, dv, pairName, C, HC, outPng, 'powerVar', powerVar, 'cycleVar', "", 'ageVarRaw', 'AgeYears', 'ageVarModel', 'AgeYears_z', 'conditionVar', 'condition', 'subjectVar', 'subject');
                end

                % ---------- Store model for 3-band continuous-age plot ----------
                if isfield(HC.plot, 'continuous_age_lmm_3bands') && HC.plot.continuous_age_lmm_3bands.enable

                    bandNameForPlot = infer_band_from_metric_name(dv);
                    bandField = char(bandNameForPlot);

                    PLOT_3BANDS.(bandField).Tm = Tm;
                    PLOT_3BANDS.(bandField).lme = lme;
                    PLOT_3BANDS.(bandField).dv = string(dv);
                    PLOT_3BANDS.(bandField).pairName = pairName;
                    PLOT_3BANDS.(bandField).formula = string(formula);

                    if exist('powerVar', 'var')
                        PLOT_3BANDS.(bandField).powerVar = string(powerVar);
                    else
                        PLOT_3BANDS.(bandField).powerVar = "";
                    end

                    if exist('useCycleCovInThisModel', 'var') && useCycleCovInThisModel
                        PLOT_3BANDS.(bandField).cycleVar = "log_n_cycles";
                    else
                        PLOT_3BANDS.(bandField).cycleVar = "";
                    end

                    PLOT_3BANDS.(bandField).p_age = get_term_pvalue_from_lme_formula(Tm, formula, 'AgeYears_z');
                    PLOT_3BANDS.(bandField).p_condition = get_term_pvalue_from_lme_formula(Tm, formula, 'condition');
                    PLOT_3BANDS.(bandField).p_interaction = get_term_pvalue_from_lme_formula(Tm, formula, 'condition:AgeYears_z');

                    if PLOT_3BANDS.(bandField).powerVar ~= ""
                        PLOT_3BANDS.(bandField).p_power = get_term_pvalue_from_lme_formula(Tm, formula, char(PLOT_3BANDS.(bandField).powerVar));
                    else
                        PLOT_3BANDS.(bandField).p_power = NaN;
                    end

                    if PLOT_3BANDS.(bandField).cycleVar ~= ""
                        PLOT_3BANDS.(bandField).p_cycle = get_term_pvalue_from_lme_formula(Tm, formula, 'log_n_cycles');
                    else
                        PLOT_3BANDS.(bandField).p_cycle = NaN;
                    end
                end

                % ---------- p-values ----------
                p_age_linear = get_term_pvalue_from_lme_formula(Tm, formula, 'AgeYears_z');
                p_condition  = get_term_pvalue_from_lme_formula(Tm, formula, 'condition');

                if useAgeConditionInteraction
                    p_age_condition = get_term_pvalue_from_lme_formula(Tm, formula, 'AgeYears_z:condition');
                else
                    p_age_condition = NaN;
                end

                if includeQuadraticAge
                    p_age_quadratic = get_term_pvalue_from_lme_formula(Tm, formula, 'AgeYears_z2');
                else
                    p_age_quadratic = NaN;
                end

                if usePowerInThisModel
                    p_power = get_term_pvalue_from_lme_formula(Tm, formula, char(powerVar));
                else
                    p_power = NaN;
                end

                if useCycleCovInThisModel
                    p_cycle = get_term_pvalue_from_lme_formula(Tm, formula, 'log_n_cycles');
                else
                    p_cycle = NaN;
                end

                riCA = riCA + 1;
                CONT_AGE_ROWS(riCA,:) = { pairName, string(dv), string(HC.analysis.coherence_source), string(HC.analysis.metric_scope), string(formula), height(Tm), numel(unique(Tm.subject)), useAgeConditionInteraction, includeQuadraticAge, usePowerInThisModel, string(powerVar), useCycleCovInThisModel, string(cycleCovSource), p_age_linear, p_age_quadratic, p_condition, p_age_condition, p_power, p_cycle };
            end

            disp('Fields stored in PLOT_3BANDS:');
            disp(fieldnames(PLOT_3BANDS));

            % ---------- Plot 3 bands together for this pair ----------
            if isfield(HC.plot, 'continuous_age_lmm_3bands') && HC.plot.continuous_age_lmm_3bands.enable && ~isempty(fieldnames(PLOT_3BANDS))

                fprintf('Plotting continuous-age LMM 3-band plot for pair: %s\n', pairName);

                outPng = fullfile(contAgeLmm3BandPlotDir, sprintf('CONTINUOUS_AGE_LMM_3BANDS__%s__%s__%s.png', char(pairName), char(string(HC.analysis.coherence_source)), lower(char(string(HC.analysis.metric_scope)))));

                plot_continuous_age_lmm_3bands_by_condition( PLOT_3BANDS, C, HC, outPng);
            end
        end

        if ~isempty(CONT_AGE_ROWS)

            CONTINUOUS_AGE_LME_TABLE = cell2table(CONT_AGE_ROWS, 'VariableNames', { 'pair_name','metric', 'coherence_source','metric_scope', 'model_formula', 'n_rows','n_subjects', 'age_condition_interaction_included', 'quadratic_age_included', 'power_covariate_included','power_covariate', 'cycle_count_covariate_included','cycle_count_source', 'p_age_linear','p_age_quadratic','p_condition','p_age_condition', 'p_power','p_cycle'});

            writetable(CONTINUOUS_AGE_LME_TABLE, fullfile(HC.io.tables_dir, sprintf('CONTINUOUS_AGE_LME_TABLE__%s.csv', ANALYSIS_TAG)));

            writetable(CONTINUOUS_AGE_LME_TABLE, fullfile(HC.io.tables_dir, 'CONTINUOUS_AGE_LME_TABLE.csv'));

            disp(CONTINUOUS_AGE_LME_TABLE);
        else
            warning('No continuous-age LME models were computed.');
        end
    end

    %% ===================== COHERENCE-POWER CORRELATIONS =====================

    runPowerCorrelations = ...
        isfield(HC.analysis, 'run_power_correlations') && ...
        HC.analysis.run_power_correlations;

    % Initialize for robustness
    CORR_TABLE = table();

    if runPowerCorrelations

        fprintf('\nRunning coherence-power correlations...\n');

        corrOutDir = fullfile(HC.io.tables_dir, 'power_correlations');
        if ~exist(corrOutDir, 'dir')
            mkdir(corrOutDir);
        end

        corrPairs = HC.analysis.correlation_pairs;

        CORR_ROWS = {};
        riC = 0;

        for ip = 1:numel(HC.analysis.pairs_to_analyze)

            pairName = string(HC.analysis.pairs_to_analyze{ip});
            Tp = T_subj(T_subj.pair_name == pairName, :);

            if isempty(Tp)
                continue;
            end

            for im = 1:size(corrPairs,1)

                dv = corrPairs{im,1};
                powVar = corrPairs{im,2};

                if ~ismember(dv, Tp.Properties.VariableNames) || ...
                        ~ismember(powVar, Tp.Properties.VariableNames)
                    continue;
                end

                Tm = Tp(~isnan(Tp.(dv)) & ~isnan(Tp.(powVar)), :);

                if height(Tm) < 5
                    continue;
                end

                x = Tm.(powVar);
                y = Tm.(dv);

                [rPearson, pPearson] = corr( ...
                    x, y, ...
                    'Type', 'Pearson', ...
                    'Rows', 'complete');

                [rSpearman, pSpearman] = corr( ...
                    x, y, ...
                    'Type', 'Spearman', ...
                    'Rows', 'complete');

                riC = riC + 1;

                CORR_ROWS(riC,:) = { ...
                    pairName, ...
                    string(dv), ...
                    string(powVar), ...
                    height(Tm), ...
                    rPearson, ...
                    pPearson, ...
                    rSpearman, ...
                    pSpearman ...
                    };
            end
        end

        if isempty(CORR_ROWS)

            warning( ...
                'No coherence-power correlations computed. Power variables may be unavailable for metric_scope = %s.', ...
                string(HC.analysis.metric_scope));

        else

            CORR_TABLE = cell2table( ...
                CORR_ROWS, ...
                'VariableNames', { ...
                    'pair_name', ...
                    'coherence_metric', ...
                    'power_metric', ...
                    'n', ...
                    'r_pearson', ...
                    'p_pearson', ...
                    'rho_spearman', ...
                    'p_spearman' ...
                    });

            writetable( ...
                CORR_TABLE, ...
                fullfile( ...
                    corrOutDir, ...
                    'COHERENCE_POWER_CORRELATIONS.csv'));

            disp(CORR_TABLE);
        end

    else

        fprintf('\nCoherence-power correlations are disabled.\n');

    end

    %% ===================== SAMPLE RECAP =====================

    fprintf('\nBuilding sample recap...\n');

    sample_txt = fullfile(HC.io.tables_dir, 'SAMPLE_RECAP.txt');
    fid = fopen(sample_txt, 'w');

    fprintf(fid, '=== SAMPLE RECAP ===\n\n');
    fprintf(fid, 'Rows before leg averaging: %d\n', height(T_row));
    fprintf(fid, 'Rows after leg averaging:  %d\n\n', height(T_subj));

    fprintf(fid, 'Unique subjects overall: %d\n\n', numel(unique(T_subj.subject)));

    fprintf(fid, '--- Subjects by age group ---\n');
    disp_to_file(fid, groupcounts_table(T_subj, {'age_group'}));

    fprintf(fid, '\n--- Rows by pair ---\n');
    disp_to_file(fid, groupcounts_table(T_subj, {'pair_name'}));

    fprintf(fid, '\n--- Rows by pair x age_group ---\n');
    disp_to_file(fid, groupcounts_table(T_subj, {'pair_name','age_group'}));

    fprintf(fid, '\n--- Rows by pair x condition ---\n');
    disp_to_file(fid, groupcounts_table(T_subj, {'pair_name','condition'}));

    fprintf(fid, '\n--- Rows by pair x age_group x condition ---\n');
    disp_to_file(fid, groupcounts_table(T_subj, {'pair_name','age_group','condition'}));

    fprintf(fid, 'Alpha source: %s\n', alpha_source);
    fprintf(fid, 'Beta source:  %s\n', beta_source);
    fprintf(fid, 'Gamma source: %s\n\n', gamma_source);

    fprintf(fid, 'Coherence source: %s\n', string(HC.analysis.coherence_source));
    fprintf(fid, 'Metric scope: %s\n', string(HC.analysis.metric_scope));
    fprintf(fid, 'Include cycle-count covariate: %d\n', includeCycleCov);

    if isfield(HC.analysis, 'scalar_metric_families')
        fprintf(fid, 'Scalar metric families: %s\n', strjoin(string(HC.analysis.scalar_metric_families), ', '));
    end

    fprintf(fid, 'Dependent variables analyzed:\n');
    for iDV = 1:numel(HC.analysis.dv_list)
        fprintf(fid, '  - %s\n', string(HC.analysis.dv_list{iDV}));
    end

    fprintf(fid, 'Cycle-count covariate requested: %d\n', includeCycleCov);

    fprintf(fid, 'Band-specific cycle-count variables:\n');
    fprintf(fid, '  - Alpha_log_n_cycles from Alpha_mean_cycles_used_for_metric_across_legs\n');
    fprintf(fid, '  - Beta_log_n_cycles from Beta_mean_cycles_used_for_metric_across_legs\n');
    fprintf(fid, '  - Gamma_log_n_cycles from Gamma_mean_cycles_used_for_metric_across_legs\n');

    fprintf(fid, '\nCycle-count source examples in T_row:\n');

    if ismember('Alpha_cycle_count_source', T_row.Properties.VariableNames)
        fprintf(fid, '  Alpha sources: %s\n', strjoin(unique(string(T_row.Alpha_cycle_count_source)), ', '));
    end
    if ismember('Beta_cycle_count_source', T_row.Properties.VariableNames)
        fprintf(fid, '  Beta sources: %s\n', strjoin(unique(string(T_row.Beta_cycle_count_source)), ', '));
    end
    if ismember('Gamma_cycle_count_source', T_row.Properties.VariableNames)
        fprintf(fid, '  Gamma sources: %s\n', strjoin(unique(string(T_row.Gamma_cycle_count_source)), ', '));
    end

    fprintf(fid, 'Analysis tag: %s\n\n', ANALYSIS_TAG);

    fclose(fid);

    %% ===================== DESCRIPTIVE TABLES =====================

    fprintf('\n=== DEBUG descriptive variables ===\n');

    fprintf('\nT_row variables:\n');
    disp(T_row.Properties.VariableNames(:));

    fprintf('\nT_subj variables:\n');
    disp(T_subj.Properties.VariableNames(:));

    fprintf('\nHC.analysis.dv_list:\n');
    disp(HC.analysis.dv_list(:));

    missingFromTsubj = setdiff(HC.analysis.dv_list, T_subj.Properties.VariableNames);
    fprintf('\nVariables in HC.analysis.dv_list but missing from T_subj:\n');
    disp(missingFromTsubj(:));

    missingFromTrow = setdiff(HC.analysis.dv_list, T_row.Properties.VariableNames);
    fprintf('\nVariables in HC.analysis.dv_list but missing from T_row:\n');
    disp(missingFromTrow(:));

    powerVars = {'Alpha_LogPower','Beta_LogPower','Gamma_LogPower'};

    fprintf('\nPower vars in T_row?\n');
    disp(ismember(powerVars, T_row.Properties.VariableNames));

    fprintf('\nPower vars in T_subj?\n');
    disp(ismember(powerVars, T_subj.Properties.VariableNames));

    fprintf('\nBuilding descriptive tables...\n');

    DESCRIPTIVE_ALL = table();

    for idv = 1:numel(dvList)
        dv = dvList{idv};
        Td = descriptive_table(T_subj, dv, {'pair_name','age_group','condition'});
        Td.metric = repmat(string(dv), height(Td), 1);

        if isempty(DESCRIPTIVE_ALL)
            DESCRIPTIVE_ALL = Td;
        else
            DESCRIPTIVE_ALL = [DESCRIPTIVE_ALL; Td]; %#ok<AGROW>
        end
    end

    writetable(DESCRIPTIVE_ALL, fullfile(HC.io.tables_dir, 'DESCRIPTIVE_TABLE_ALL.csv'));

    % %% ===================== MODELING =====================

    % fprintf('\nRunning pair-specific models...\n');

    % OMNIBUS_ROWS = {};
    % riO = 0;

    % POSTHOC_ROWS = {};
    % riP = 0;

    % for ip = 1:numel(HC.analysis.pairs_to_analyze)
    %     pairName = string(HC.analysis.pairs_to_analyze{ip});
    %     Tp = T_subj(T_subj.pair_name == pairName, :);

    %     if isempty(Tp)
    %         continue;
    %     end

    %     Tp.age_group = removecats(Tp.age_group);
    %     Tp.condition = removecats(Tp.condition);
    %     Tp.subject   = removecats(Tp.subject);

    %     for idv = 1:numel(dvList)
    %         dv = dvList{idv};

    %         if ~ismember(dv, Tp.Properties.VariableNames)
    %             continue;
    %         end

    %         Tm = Tp(~isnan(Tp.(dv)), :);
    %         if isempty(Tm)
    %             continue;
    %         end

    %         outTxt = fullfile(HC.io.models_dir, sprintf('MODEL__%s__%s__%s.txt', char(pairName), dv, ANALYSIS_TAG));

    %         includeCycleCovRequested = isfield(HC.analysis, 'include_cycle_count_covariate') && HC.analysis.include_cycle_count_covariate;

    %         [Tm, useCycleCovInThisModel, cycleCovSource] = add_log_cycle_covariate_for_dv(Tm, dv, includeCycleCovRequested);

    %         if useCycleCovInThisModel
    %             formula = sprintf('%s ~ age_group * condition + log_n_cycles + (1|subject)', dv);
    %         else
    %             formula = sprintf('%s ~ age_group * condition + (1|subject)', dv);
    %         end

    %         fprintf('\nRunning LME for %s | %s\n', string(pairName), string(dv));
    %         fprintf('Formula: %s\n', formula);

    %         if useCycleCovInThisModel
    %             fprintf('Cycle-count control: ENABLED using %s\n', cycleCovSource);
    %         else
    %             fprintf('Cycle-count control: DISABLED or skipped for this model\n');
    %         end

    %         Tm = Tm(~isnan(Tm.(dv)), :);

    %         if useCycleCovInThisModel
    %             Tm = Tm(isfinite(Tm.log_n_cycles), :);
    %         end

    %         lme = write_lme_report(Tm, dv, formula, outTxt);

    %         % ---------- omnibus p-values ----------
    %         p_age = get_term_pvalue_from_lme_formula(Tm, formula, 'age_group');
    %         p_condition = get_term_pvalue_from_lme_formula(Tm, formula, 'condition');
    %         p_interaction = get_term_pvalue_from_lme_formula(Tm, formula, 'age_group:condition');

    %         if useCycleCovInThisModel
    %             cycleCovariate = "log_n_cycles";
    %         else
    %             cycleCovariate = "";
    %         end

    %         riO = riO + 1;
    %         OMNIBUS_ROWS(riO,:) = { pairName, string(dv), string(HC.analysis.coherence_source), string(HC.analysis.metric_scope), useCycleCovInThisModel, cycleCovariate, string(cycleCovSource), string(formula), height(Tm), numel(unique(Tm.subject)), p_age, p_condition, p_interaction };
    %         % ---------- post hoc: condition within age ----------
    %         stats_cond_within_age = get_condition_pairwise_stats_within_age_simple(Tm, dv, HC.posthoc);

    %         if ~isempty(stats_cond_within_age)
    %             stats_cond_within_age = apply_pairwise_p_correction(stats_cond_within_age, HC.posthoc.correction);

    %             for k = 1:numel(stats_cond_within_age)
    %                 riP = riP + 1;
    %                 POSTHOC_ROWS(riP,:) = { pairName, string(dv), "condition_within_age", string(stats_cond_within_age(k).group), string(stats_cond_within_age(k).g1), string(stats_cond_within_age(k).g2), stats_cond_within_age(k).p_raw, stats_cond_within_age(k).p, string(stats_cond_within_age(k).test_used), mat2str(stats_cond_within_age(k).n) };
    %             end
    %         end

    %         % ---------- post hoc: age within condition ----------
    %         stats_age_within_condition = get_age_pairwise_stats_within_condition_simple(Tm, dv, HC.posthoc);

    %         if ~isempty(stats_age_within_condition)
    %             stats_age_within_condition = apply_pairwise_p_correction(stats_age_within_condition, HC.posthoc.correction);

    %             for k = 1:numel(stats_age_within_condition)
    %                 riP = riP + 1;
    %                 POSTHOC_ROWS(riP,:) = { pairName, string(dv), "age_within_condition", string(stats_age_within_condition(k).group), string(stats_age_within_condition(k).g1), string(stats_age_within_condition(k).g2), stats_age_within_condition(k).p_raw, stats_age_within_condition(k).p, string(stats_age_within_condition(k).test_used), mat2str(stats_age_within_condition(k).n) };
    %             end
    %         end
    %     end
    % end

    % OMNIBUS_TABLE = cell2table(OMNIBUS_ROWS, 'VariableNames', { 'pair_name','metric', 'coherence_source','metric_scope', 'include_cycle_count_covariate','cycle_count_covariate', 'cycle_count_source', 'model_formula', 'n_rows','n_subjects', 'p_age_group','p_condition','p_age_condition'});

    % writetable(OMNIBUS_TABLE, fullfile(HC.io.tables_dir, sprintf('OMNIBUS_TABLE__%s.csv', ANALYSIS_TAG)));

    % % Optional latest-copy file
    % writetable(OMNIBUS_TABLE, fullfile(HC.io.tables_dir, 'OMNIBUS_TABLE.csv'));

    % if ~isempty(POSTHOC_ROWS)
    %     POSTHOC_TABLE = cell2table(POSTHOC_ROWS, 'VariableNames', { 'pair_name','metric','comparison_family','stratification_group', 'level_1','level_2','p_raw','p_adj','test_used','n_used'});
    % else
    %     POSTHOC_TABLE = table();
    % end

    % if ~isempty(POSTHOC_TABLE)
    %     POSTHOC_TABLE.coherence_source = repmat(string(HC.analysis.coherence_source), height(POSTHOC_TABLE), 1);
    %     POSTHOC_TABLE.metric_scope = repmat(string(HC.analysis.metric_scope), height(POSTHOC_TABLE), 1);
    %     POSTHOC_TABLE.include_cycle_count_covariate = repmat(includeCycleCov, height(POSTHOC_TABLE), 1);

    %     if includeCycleCov
    %         POSTHOC_TABLE.cycle_count_covariate = repmat("log_n_cycles", height(POSTHOC_TABLE), 1);
    %     else
    %         POSTHOC_TABLE.cycle_count_covariate = repmat("", height(POSTHOC_TABLE), 1);
    %     end
    % end

    % writetable(POSTHOC_TABLE, fullfile(HC.io.tables_dir, sprintf('POSTHOC_TABLE__%s.csv', ANALYSIS_TAG)));

    % % Optional latest-copy file
    % writetable(POSTHOC_TABLE, fullfile(HC.io.tables_dir, 'POSTHOC_TABLE.csv'));

    %% ===================== CATEGORICAL AGE MODELING =====================

    runCategoricalAgeLME = ...
        isfield(HC.analysis, 'run_categorical_age_lme') && ...
        HC.analysis.run_categorical_age_lme;

    % Initialize so later workspace saving still works
    OMNIBUS_TABLE = table();
    POSTHOC_TABLE = table();

    if runCategoricalAgeLME

        fprintf('\nRunning categorical-age pair-specific models...\n');

        OMNIBUS_ROWS = {};
        riO = 0;

        POSTHOC_ROWS = {};
        riP = 0;

        for ip = 1:numel(HC.analysis.pairs_to_analyze)

            pairName = string(HC.analysis.pairs_to_analyze{ip});
            Tp = T_subj(T_subj.pair_name == pairName, :);

            if isempty(Tp)
                continue;
            end

            Tp.age_group = removecats(Tp.age_group);
            Tp.condition = removecats(Tp.condition);
            Tp.subject   = removecats(Tp.subject);

            for idv = 1:numel(dvList)

                dv = dvList{idv};

                if ~ismember(dv, Tp.Properties.VariableNames)
                    continue;
                end

                Tm = Tp(~isnan(Tp.(dv)), :);

                if isempty(Tm)
                    continue;
                end

                outTxt = fullfile( ...
                    HC.io.models_dir, ...
                    sprintf('MODEL__%s__%s__%s.txt', ...
                    char(pairName), dv, ANALYSIS_TAG));

                includeCycleCovRequested = ...
                    isfield(HC.analysis, 'include_cycle_count_covariate') && ...
                    HC.analysis.include_cycle_count_covariate;

                [Tm, useCycleCovInThisModel, cycleCovSource] = ...
                    add_log_cycle_covariate_for_dv( ...
                    Tm, dv, includeCycleCovRequested);

                if useCycleCovInThisModel
                    formula = sprintf( ...
                        '%s ~ age_group * condition + log_n_cycles + (1|subject)', ...
                        dv);
                else
                    formula = sprintf( ...
                        '%s ~ age_group * condition + (1|subject)', ...
                        dv);
                end

                fprintf('\nRunning categorical-age LME for %s | %s\n', ...
                    pairName, string(dv));
                fprintf('Formula: %s\n', formula);

                if useCycleCovInThisModel
                    Tm = Tm(isfinite(Tm.log_n_cycles), :);
                end

                lme = write_lme_report(Tm, dv, formula, outTxt);

                % ---------- omnibus ----------
                p_age = get_term_pvalue_from_lme_formula( ...
                    Tm, formula, 'age_group');

                p_condition = get_term_pvalue_from_lme_formula( ...
                    Tm, formula, 'condition');

                p_interaction = get_term_pvalue_from_lme_formula( ...
                    Tm, formula, 'age_group:condition');

                if useCycleCovInThisModel
                    cycleCovariate = "log_n_cycles";
                else
                    cycleCovariate = "";
                end

                riO = riO + 1;

                OMNIBUS_ROWS(riO,:) = { ...
                    pairName, string(dv), ...
                    string(HC.analysis.coherence_source), ...
                    string(HC.analysis.metric_scope), ...
                    useCycleCovInThisModel, ...
                    cycleCovariate, ...
                    string(cycleCovSource), ...
                    string(formula), ...
                    height(Tm), ...
                    numel(unique(Tm.subject)), ...
                    p_age, ...
                    p_condition, ...
                    p_interaction };

                % ---------- post hoc: condition within age ----------
                stats_cond_within_age = ...
                    get_condition_pairwise_stats_within_age_simple( ...
                    Tm, dv, HC.posthoc);

                if ~isempty(stats_cond_within_age)

                    stats_cond_within_age = ...
                        apply_pairwise_p_correction( ...
                        stats_cond_within_age, ...
                        HC.posthoc.correction);

                    for k = 1:numel(stats_cond_within_age)

                        riP = riP + 1;

                        POSTHOC_ROWS(riP,:) = { ...
                            pairName, ...
                            string(dv), ...
                            "condition_within_age", ...
                            string(stats_cond_within_age(k).group), ...
                            string(stats_cond_within_age(k).g1), ...
                            string(stats_cond_within_age(k).g2), ...
                            stats_cond_within_age(k).p_raw, ...
                            stats_cond_within_age(k).p, ...
                            string(stats_cond_within_age(k).test_used), ...
                            mat2str(stats_cond_within_age(k).n) };
                    end
                end

                % ---------- post hoc: age within condition ----------
                stats_age_within_condition = ...
                    get_age_pairwise_stats_within_condition_simple( ...
                    Tm, dv, HC.posthoc);

                if ~isempty(stats_age_within_condition)

                    stats_age_within_condition = ...
                        apply_pairwise_p_correction( ...
                        stats_age_within_condition, ...
                        HC.posthoc.correction);

                    for k = 1:numel(stats_age_within_condition)

                        riP = riP + 1;

                        POSTHOC_ROWS(riP,:) = { ...
                            pairName, ...
                            string(dv), ...
                            "age_within_condition", ...
                            string(stats_age_within_condition(k).group), ...
                            string(stats_age_within_condition(k).g1), ...
                            string(stats_age_within_condition(k).g2), ...
                            stats_age_within_condition(k).p_raw, ...
                            stats_age_within_condition(k).p, ...
                            string(stats_age_within_condition(k).test_used), ...
                            mat2str(stats_age_within_condition(k).n) };
                    end
                end
            end
        end

        if ~isempty(OMNIBUS_ROWS)
            OMNIBUS_TABLE = cell2table( ...
                OMNIBUS_ROWS, ...
                'VariableNames', { ...
                'pair_name','metric', ...
                'coherence_source','metric_scope', ...
                'include_cycle_count_covariate', ...
                'cycle_count_covariate', ...
                'cycle_count_source', ...
                'model_formula', ...
                'n_rows','n_subjects', ...
                'p_age_group','p_condition','p_age_condition'});
        end

        writetable(OMNIBUS_TABLE, ...
            fullfile(HC.io.tables_dir, ...
            sprintf('OMNIBUS_TABLE__%s.csv', ANALYSIS_TAG)));

        writetable(OMNIBUS_TABLE, ...
            fullfile(HC.io.tables_dir, 'OMNIBUS_TABLE.csv'));

        if ~isempty(POSTHOC_ROWS)

            POSTHOC_TABLE = cell2table( ...
                POSTHOC_ROWS, ...
                'VariableNames', { ...
                'pair_name','metric','comparison_family', ...
                'stratification_group', ...
                'level_1','level_2', ...
                'p_raw','p_adj','test_used','n_used'});

            POSTHOC_TABLE.coherence_source = ...
                repmat(string(HC.analysis.coherence_source), ...
                height(POSTHOC_TABLE), 1);

            POSTHOC_TABLE.metric_scope = ...
                repmat(string(HC.analysis.metric_scope), ...
                height(POSTHOC_TABLE), 1);

            POSTHOC_TABLE.include_cycle_count_covariate = ...
                repmat(includeCycleCov, height(POSTHOC_TABLE), 1);

        end

        writetable(POSTHOC_TABLE, ...
            fullfile(HC.io.tables_dir, ...
            sprintf('POSTHOC_TABLE__%s.csv', ANALYSIS_TAG)));

        writetable(POSTHOC_TABLE, ...
            fullfile(HC.io.tables_dir, 'POSTHOC_TABLE.csv'));

    else

        fprintf('\nCategorical-age LME disabled.\n');

    end

%% ===================== POWER-CONTROL MODELS =====================

    runPowerControlModels = ...
        isfield(HC.analysis, 'run_power_control_models') && ...
        HC.analysis.run_power_control_models;

    if runPowerControlModels

        fprintf('\nRunning power-control models...\n');

        powerPairs = HC.analysis.power_pairs;

        includeCycleCov = ...
            isfield(HC.analysis, 'include_cycle_count_covariate') && ...
            HC.analysis.include_cycle_count_covariate;

        for ip = 1:numel(HC.analysis.pairs_to_analyze)

            fprintf('\nPair: %s\n', HC.analysis.pairs_to_analyze{ip});

            pairName = string(HC.analysis.pairs_to_analyze{ip});
            Tp = T_subj(T_subj.pair_name == pairName, :);

            if isempty(Tp)
                continue;
            end

            Tp.age_group = removecats(Tp.age_group);
            Tp.condition = removecats(Tp.condition);
            Tp.subject   = removecats(Tp.subject);

            for im = 1:size(powerPairs,1)
                dv = powerPairs{im,1};
                powVar = powerPairs{im,2};

                if ~ismember(dv, Tp.Properties.VariableNames) || ~ismember(powVar, Tp.Properties.VariableNames)

                    fprintf('Missing variable(s) for power control model, skipping: %s or %s\n', dv, powVar);
                    continue;
                end

                Tm = Tp(~isnan(Tp.(dv)) & ~isnan(Tp.(powVar)), :);

                includeCycleCovRequested = isfield(HC.analysis, 'include_cycle_count_covariate') && HC.analysis.include_cycle_count_covariate;

                [Tm, useCycleCovInThisModel, cycleCovSource] = add_log_cycle_covariate_for_dv(Tm, dv, includeCycleCovRequested);

                if useCycleCovInThisModel
                    Tm = Tm(isfinite(Tm.log_n_cycles), :);
                end

                if height(Tm) < 10
                    fprintf('Not enough data for modeling (n = %d), skipping power-control model for this pair and DV.\n', height(Tm));
                    continue;
                end

                % z-score power so coefficient is interpretable
                Tm.(powVar) = zscore(Tm.(powVar));

                if useCycleCovInThisModel
                    formula = sprintf('%s ~ age_group * condition + %s + log_n_cycles + (1|subject)', dv, powVar);

                    fprintf('Power-control model WITH cycle-count covariate:\n');
                    fprintf('Formula: %s\n', formula);
                    fprintf('Cycle-count source: %s\n', cycleCovSource);

                    cycleTag = "cyclecov";
                else
                    formula = sprintf('%s ~ age_group * condition + %s + (1|subject)', dv, powVar);

                    fprintf('Power-control model WITHOUT cycle-count covariate:\n');
                    fprintf('Formula: %s\n', formula);

                    cycleTag = "nocyclecov";
                end

                if exist('ANALYSIS_TAG', 'var')
                    outTxt = fullfile(HC.io.models_dir, sprintf('MODEL_POWER_CONTROL__%s__%s__%s.txt', char(pairName), dv, ANALYSIS_TAG));
                else
                    outTxt = fullfile(HC.io.models_dir, sprintf('MODEL_POWER_CONTROL__%s__%s__%s_%s.txt', char(pairName), dv, string(HC.analysis.coherence_source), cycleTag));
                end

                lme = write_lme_report(Tm, dv, formula, outTxt);
            end
        end
    else
        fprintf('Power-control models are disabled.\n');
    end

    %% ===================== PLOTS =====================

    if HC.plot.enable
        fprintf('\nGenerating plots...\n');

        scopeLabelFile = char(lower(string(HC.analysis.metric_scope)));

        if isfield(HC.analysis, 'metric_type_for_plots') && ~isempty(HC.analysis.metric_type_for_plots)
            metricTypes = HC.analysis.metric_type_for_plots;
        else
            metricTypes = {'mean','auc','peak'};
        end
        plotTypes = { 'condition',     'BY_CONDITION'; 'age',           'BY_AGE'; 'age_condition', 'BY_AGE_AND_CONDITION'; 'condition_age', 'BY_CONDITION_AND_AGE' };

        for ip = 1:numel(HC.analysis.pairs_to_analyze)
            pairName = string(HC.analysis.pairs_to_analyze{ip});
            Tp = T_subj(T_subj.pair_name == pairName, :);

            if isempty(Tp)
                continue;
            end

            for im = 1:numel(metricTypes)
                metricType = metricTypes{im};
                metricLabel = upper(metricType);

                for it = 1:size(plotTypes, 1)
                    plotType = plotTypes{it, 1};
                    plotLabel = plotTypes{it, 2};

                    make_band_triplet_figure( Tp, pairName, metricType, plotType, fullfile(HC.io.band_triplet_dir, sprintf('TRIPLET_%s__%s__%s__%s_%s.png', metricLabel, pairName, scopeLabelFile, plotLabel, HC.analysis.cycle_triplet_source)), HC.plot.visible, C, HC);
                end
            end
        end
    end

    %% ===================== SPECTRUM CURVE PLOTS + OPTIONAL SPM =====================

    HS = HC.spectrum;

    if HS.enable

        fprintf('\nGenerating coherence spectrum plots...\n');

        if ~exist(HS.out_dir, 'dir'), mkdir(HS.out_dir); end
        if ~exist(HS.tables_dir, 'dir'), mkdir(HS.tables_dir); end

        % add spm1d if available and requested
        if (HS.run_spm_age || HS.run_spm_condition) && isfield(C.paths, 'toolboxes') && isfield(C.paths.toolboxes, 'spm1d')
            if exist(C.paths.toolboxes.spm1d, 'dir')
                addpath(genpath(C.paths.toolboxes.spm1d));
            else
                warning('SPM1D folder not found: %s', C.paths.toolboxes.spm1d);
            end
        end

        % ===================== BUILD SPECTRUM TABLE DIRECTLY FROM FULL DATASET =====================

        SPEC_ROWS = {};
        riS = 0;
        nSkippedFreq = 0;

        subjects_spec = unique([ fieldnames(COH_DEFAULT); fieldnames(COH_ALPHA); fieldnames(COH_BETA); fieldnames(COH_GAMMA)]);

        for iS = 1:numel(subjects_spec)
            subjID = subjects_spec{iS};
            age_group = subject_to_group(subjID, C);

            conds_spec = union_of_nested_fields({COH_DEFAULT, COH_ALPHA, COH_BETA, COH_GAMMA}, {subjID});
            for ic = 1:numel(conds_spec)
                cond = conds_spec{ic};

                legs_spec = union_of_nested_fields({COH_DEFAULT, COH_ALPHA, COH_BETA, COH_GAMMA}, {subjID, cond});
                for il = 1:numel(legs_spec)
                    leg = legs_spec{il};

                    pairNames_spec = union_of_nested_fields({COH_DEFAULT, COH_ALPHA, COH_BETA, COH_GAMMA}, {subjID, cond, leg});
                    fprintf('Processing subject %s | condition %s | leg %s | pairs: %s\n', subjID, cond, leg, strjoin(pairNames_spec, ', '));
                    for ip = 1:numel(pairNames_spec)
                        pairName = pairNames_spec{ip};

                        if ~ismember(string(pairName), string(HC.analysis.pairs_to_analyze))
                            continue;
                        end

                        R = get_nested_result(COH_DEFAULT, subjID, cond, leg, pairName);

                        if isempty(R)
                            continue;
                        end

                        CohMap = get_coherence_map_for_source(R, HS.spectrum_source);
                        if isempty(CohMap) || ~isfield(R, 'Freq') || isempty(R.Freq)
                            continue;
                        end

                        % minimum cycle requirement
                        nCycles = get_field_or_nan(R, 'n_cycles_used');
                        if isnan(nCycles) || nCycles < HC.analysis.min_cycles_required
                            continue;
                        end

                        % choose time window
                        usePOI = isfield(HC.analysis, 'metric_scope') && strcmpi(string(HC.analysis.metric_scope), "POI");

                        if usePOI
                            if ~result_has_poi(R)
                                continue;
                            end
                            timeIdx = get_poi_indices(R);
                        else
                            timeIdx = 1:size(CohMap, 2);
                        end

                        if isempty(timeIdx)
                            continue;
                        end
                        spec = mean(CohMap(:, timeIdx), 2, 'omitnan');

                        freq = R.Freq(:);

                        % remove NaNs consistently
                        keep = isfinite(freq) & isfinite(spec);
                        freq = freq(keep);
                        spec = spec(keep);

                        if isempty(freq) || isempty(spec)
                            continue;
                        end

                        fkeep = freq >= HC.analysis.spectrum_freq_range(1) & freq <= HC.analysis.spectrum_freq_range(2);
                        freq = freq(fkeep);
                        spec = spec(fkeep);

                        if isempty(freq) || isempty(spec)
                            continue;
                        end

                        % force ascending frequency axis
                        [freq, sortIdx] = sort(freq, 'ascend');
                        spec = spec(sortIdx);

                        riS = riS + 1;
                        SPEC_ROWS(riS,:) = { categorical(string(subjID)), categorical(string(age_group), C.plotting.age_order, C.plotting.age_order, 'Ordinal', true), categorical(string(cond), C.plotting.condition_order, C.plotting.condition_order, 'Ordinal', true), categorical(string(leg), C.design.legs, C.design.legs, 'Ordinal', true), categorical(string(pairName), HC.analysis.pairs_to_analyze, HC.analysis.pairs_to_analyze, 'Ordinal', true), nCycles, {freq(:)'}, {spec(:)'} };
                    end
                end
            end
        end

        if isempty(SPEC_ROWS)
            warning('No spectrum rows could be built from COH_DEFAULT. Skipping spectrum plots.');
        else

            T_spec_row = cell2table(SPEC_ROWS, 'VariableNames', { 'subject','age_group','condition','leg','pair_name','n_cycles_used','Freq','Spectrum'});
            fprintf('Row-level spectrum table: %d rows\n', height(T_spec_row));
            fprintf('\n=== Spectrum width diagnostics ===\n');

            specWidths = cellfun(@numel, T_spec_row.Spectrum);
            freqWidths = cellfun(@numel, T_spec_row.Freq);

            fprintf('Unique spectrum widths:\n');
            disp(unique(specWidths));

            fprintf('Unique frequency widths:\n');
            disp(unique(freqWidths));

            Tdiag = table( string(T_spec_row.subject), string(T_spec_row.condition), string(T_spec_row.leg), string(T_spec_row.pair_name), specWidths, freqWidths, 'VariableNames', { 'subject','condition','leg','pair','specWidth','freqWidth'});

            disp(head(Tdiag,30))

            T_spec_row.subject   = categorical(string(T_spec_row.subject));
            T_spec_row.age_group = categorical(string(T_spec_row.age_group), C.plotting.age_order, C.plotting.age_order, 'Ordinal', true);
            T_spec_row.condition = categorical(string(T_spec_row.condition), C.plotting.condition_order, C.plotting.condition_order, 'Ordinal', true);
            T_spec_row.leg       = categorical(string(T_spec_row.leg), C.design.legs, C.design.legs, 'Ordinal', true);
            T_spec_row.pair_name = categorical(string(T_spec_row.pair_name), HC.analysis.pairs_to_analyze, HC.analysis.pairs_to_analyze, 'Ordinal', true);

            T_spec_row = T_spec_row(~isundefined(T_spec_row.age_group) & ~isundefined(T_spec_row.condition) & ~isundefined(T_spec_row.pair_name), :);

            writetable(spectrum_table_to_flat_table(T_spec_row), fullfile(HS.tables_dir, 'T_spec_row_flat.csv'));

            % ---------------------------------------------------------
            % Average left/right legs within subject x age_group x condition x pair
            % ---------------------------------------------------------
            [T_spec_subj, freqRef] = average_spectrum_legs(T_spec_row);
            fprintf('\n=== CHECK SUBJECT-LEVEL SPECTRUM TABLE ===\n');

            disp(head(T_spec_subj(:, {'subject','condition','pair_name'})));

            fprintf('Rows in T_spec_subj: %d\n', height(T_spec_subj));

            nUnique = height(unique(T_spec_subj(:, {'subject','condition','pair_name'})));

            fprintf('Unique subject-condition-pair combinations: %d\n', nUnique);

            keyVars = {'subject','condition','pair_name'};
            nUnique = height(unique(T_spec_subj(:, keyVars)));

            if height(T_spec_subj) ~= nUnique
                warning('T_spec_subj has duplicate subject-condition-pair rows: %d rows vs %d unique keys.', height(T_spec_subj), nUnique);
            end
            %T_spec_subj = standardize_spectrum_table(T_spec_subj);

            writetable(spectrum_table_to_flat_table(T_spec_subj), fullfile(HS.tables_dir, 'T_spec_subject_flat.csv'));

            pairList = categories(removecats(T_spec_subj.pair_name));

            specWidths = nan(height(T_spec_subj),1);
            for i = 1:height(T_spec_subj)
                specWidths(i) = numel(T_spec_subj.Spectrum{i});
            end

            for ip = 1:numel(pairList)
                pairName = pairList{ip};
                Tp = T_spec_subj(T_spec_subj.pair_name == pairName, :);

                if isempty(Tp)
                    continue;
                end

                % complete-case subset for repeated-measures condition SPM
                Tp_cond_spm = keep_only_complete_subjects_for_conditions(Tp, C.plotting.condition_order);

                % ---------- CONDITION FIGURE ----------
                condLevels = keep_present_in_order(cellstr(C.plotting.condition_order), categories(removecats(Tp.condition)));

                showSPMsubplot = isfield(HS, 'show_spm_subplot') && HS.show_spm_subplot;

                if showSPMsubplot
                    fig1 = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [100 100 1000 850]);
                    ax1 = subplot(2,1,1);
                else
                    fig1 = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [100 100 1000 520]);
                    ax1 = axes(fig1);
                end

                pos = ax1.Position;
                pos(2) = pos(2) - 0.02;
                pos(4) = pos(4) - 0.03;
                ax1.Position = pos;

                hold(ax1, 'on');

                %[hCond, lCond] = plot_mean_spectrum_by_group(ax1, Tp, 'condition', condLevels, @(x)get_condition_color(x,C), freqRef);
                [hCond, lCond] = plot_mean_spectrum_by_group(ax1, Tp, 'condition', condLevels, @(x)get_condition_color(x,C), freqRef, HS);

                if isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "sig")
                    yLabelTxt = 'Significant coherence';
                    spectrumTxt = 'significant coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "equalized")
                    yLabelTxt = 'Equalized unthresholded coherence';
                    spectrumTxt = 'equalized unthresholded coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "sig_equalized")
                    yLabelTxt = 'Equalized significant coherence';
                    spectrumTxt = 'equalized significant coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "sig_common_threshold")
                    yLabelTxt = 'Significant coherence (common threshold subtracted)';
                    spectrumTxt = 'significant coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "zcoh_bokil")
                    yLabelTxt = 'Z-scored coherence (Bokil method)';
                    spectrumTxt = 'Z-scored coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "surrogate_delta")
                    yLabelTxt = 'Delta surrogate coherence';
                    spectrumTxt = 'Delta surrogate coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "cycle_bias_corrected")
                    yLabelTxt = 'Cycle-bias-corrected coherence';
                    spectrumTxt = 'Cycle-bias-corrected coherence spectrum';
                else
                    yLabelTxt = 'Raw coherence';
                    spectrumTxt = 'raw coherence spectrum';
                end
                xlabel(ax1, 'Frequency (Hz)');

                ylabel(ax1, yLabelTxt);
                % title(ax1, sprintf('%s | condition effect | %s %s', ...
                %     string(pairName), spectrumTxt, get_metric_scope_label(HS.scope)), ...
                %     'Interpreter','none');
                grid(ax1, 'on');
                xlim(ax1, [HS.freq_min HS.freq_max]);
                apply_shared_coherence_ylim(ax1, HC);

                if ~isempty(hCond)
                    legend(ax1, hCond, lCond, 'Location', 'best', 'Interpreter', 'none');
                end

                spmCondInfo = struct([]);
                topAxCond = ax1;

                if showSPMsubplot
                    ax2 = subplot(2,1,2);
                    hold(ax2, 'on');
                else
                    ax2 = [];
                end

                fprintf('\n=== CONDITION SPECTRUM COUNTS | %s ===\n', pairName);

                for ic = 1:numel(condLevels)
                    condName = condLevels{ic};
                    Ttmp = Tp(Tp.condition == condName, :);
                    fprintf('%s plot n = %d unique subjects\n', condName, numel(unique(Ttmp.subject)));
                end

                fprintf('Condition SPM complete-case n = %d unique subjects\n', numel(unique(Tp_cond_spm.subject)));

                if HS.run_spm_condition && ~isempty(Tp_cond_spm)

                    condLevels_spm = keep_present_in_order( cellstr(C.plotting.condition_order), categories(removecats(Tp_cond_spm.condition)));

                    if numel(condLevels_spm) >= 2

                        spmCondInfo = run_spm_condition_on_spectrum(Tp_cond_spm, condLevels_spm, freqRef, HS);

                        if isfield(spmCondInfo, 'spmi') && ~isempty(spmCondInfo.spmi)

                            if showSPMsubplot && isgraphics(ax2, 'axes')
                                axes(ax2); %#ok<LAXES>
                                spmCondInfo.spmi.plot();
                                spmCondInfo.spmi.plot_threshold_label();
                                spmCondInfo.spmi.plot_p_values();

                                xlabel(ax2, 'Frequency (Hz)');
                                ylabel(ax2, 'SPM{t} / SPM{F}');
                                title(ax2, 'SPM condition effect', 'Interpreter','none');
                                xlim(ax2, [HS.freq_min HS.freq_max]);

                            end

                            if HS.show_cluster_stars && isgraphics(topAxCond, 'axes')
                                axes(topAxCond); %#ok<LAXES>
                                add_spm_significance_bars_frequency(topAxCond, spmCondInfo.spmi, freqRef, 'y_frac', 0.85, 'line_width', 1.5, 'color', [0 0 0], 'show_stars', true);
                            end

                        elseif showSPMsubplot && isgraphics(ax2, 'axes')
                            cla(ax2);
                            axis(ax2, 'off');
                            text(0.5, 0.5, 'No SPM result available', 'Parent', ax2, 'HorizontalAlignment', 'center');
                        end
                    end

                elseif showSPMsubplot && isgraphics(ax2, 'axes')
                    cla(ax2);
                    axis(ax2, 'off');
                    text(0.5, 0.5, 'Condition SPM disabled or no complete-case data', 'Parent', ax2, 'HorizontalAlignment', 'center');
                end

                sgtitle(sprintf('%s | condition spectrum analysis | %s', string(pairName), get_pair_phase_text(pairName, C)), 'Interpreter','none');

                saveas(fig1, fullfile(HS.out_dir, sprintf('SPECTRUM_CONDITION_SPM__%s__%s__%s.png', char(string(pairName)), lower(char(string(HS.scope))), HS.spectrum_source)));
                close(fig1);

                % ---------- AGE FIGURE ----------
                % Collapse conditions first so each participant contributes only one curve.
                Tp_age = average_spectrum_conditions(Tp);

                fprintf('\n=== AGE SPECTRUM PARTICIPANT COUNTS | %s ===\n', pairName);
                disp(groupcounts_table(Tp_age, {'age_group'}));

                ageLevels = keep_present_in_order( cellstr(C.plotting.age_order), categories(removecats(Tp_age.age_group)));

                if showSPMsubplot
                    fig2 = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [100 100 1000 850]);
                    ax3 = subplot(2,1,1);
                else
                    fig2 = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [100 100 1000 520]);
                    ax3 = axes(fig2);
                end

                pos = ax3.Position;
                pos(2) = pos(2) - 0.02;   % move plot down
                pos(4) = pos(4) - 0.03;   % slightly reduce height
                ax3.Position = pos;

                hold(ax3, 'on');

                %[hAge, lAge] = plot_mean_spectrum_by_group(ax3, Tp, 'age_group', ageLevels, @(x)get_age_color(x,C), freqRef);
                [hAge, lAge] = plot_mean_spectrum_by_group(ax3, Tp_age, 'age_group', ageLevels, @(x)get_age_color(x,C), freqRef, HS);

                xlabel(ax3, 'Frequency (Hz)');
                ylabel(ax3, yLabelTxt);
                % title(ax3, sprintf('%s | age effect | %s %s', ...
                %     string(pairName), spectrumTxt, get_metric_scope_label(HS.scope)), ...
                %     'Interpreter','none');
                grid(ax3, 'on');
                xlim(ax3, [HS.freq_min HS.freq_max]);
                apply_shared_coherence_ylim(ax3, HC);

                if ~isempty(hAge)
                    legend(ax3, hAge, lAge, 'Location', 'best', 'Interpreter', 'none');
                end

                spmAgeInfo = struct([]);
                topAxAge = ax3;

                if showSPMsubplot
                    ax4 = subplot(2,1,2);
                    hold(ax4, 'on');
                else
                    ax4 = [];
                end

                if HS.run_spm_age

                    spmAgeInfo = run_spm_age_on_spectrum(Tp_age, ageLevels, freqRef, HS);

                    if isfield(spmAgeInfo, 'spmi') && ~isempty(spmAgeInfo.spmi)

                        if showSPMsubplot && isgraphics(ax4, 'axes')
                            axes(ax4); %#ok<LAXES>
                            spmAgeInfo.spmi.plot();
                            spmAgeInfo.spmi.plot_threshold_label();
                            spmAgeInfo.spmi.plot_p_values();

                            xlabel(ax4, 'Frequency (Hz)');
                            ylabel(ax4, 'SPM{t} / SPM{F}');
                            title(ax4, 'SPM age effect', 'Interpreter','none');
                            xlim(ax4, [HS.freq_min HS.freq_max]);
                        end

                        if HS.show_cluster_stars && isgraphics(topAxAge, 'axes')
                            axes(topAxAge); %#ok<LAXES>
                            add_spm_significance_bars_frequency(topAxAge, spmAgeInfo.spmi, freqRef, 'y_frac', 0.85, 'line_width', 1.5, 'color', [0 0 0], 'show_stars', true);
                        end

                    elseif showSPMsubplot && isgraphics(ax4, 'axes')
                        cla(ax4);
                        axis(ax4, 'off');
                        text(0.5, 0.5, 'No SPM result available', 'Parent', ax4, 'HorizontalAlignment', 'center');
                    end

                elseif showSPMsubplot && isgraphics(ax4, 'axes')
                    cla(ax4);
                    axis(ax4, 'off');
                    text(0.5, 0.5, 'Age SPM disabled', 'Parent', ax4, 'HorizontalAlignment', 'center');
                end

                sgtitle(sprintf('%s | age spectrum analysis | %s', string(pairName), get_pair_phase_text(pairName, C)), 'Interpreter','none');

                saveas(fig2, fullfile(HS.out_dir, sprintf('SPECTRUM_AGE_SPM__%s__%s__%s.png', char(string(pairName)), lower(char(string(HS.scope))), HS.spectrum_source)));
                close(fig2);

                % ---------- EXTRA SPECTRUM FOLLOW-UP FIGURES ----------
                % 1) Condition effect within each age group: 4 subplots
                % 2) Age effect within each condition: 3 subplots

                if isfield(HS, 'make_followup_subplot_spm') && HS.make_followup_subplot_spm

                    fprintf('\nMaking follow-up spectrum figure (condition within age) for significant SPM effects | %s\n', pairName);

                    make_spectrum_condition_within_age_figure( Tp, pairName, freqRef, C, HC, HS);

                    fprintf('\nMaking follow-up spectrum figure (age within condition) for significant SPM effects | %s\n', pairName);

                    make_spectrum_age_within_condition_figure( Tp, pairName, freqRef, C, HC, HS);
                end


                % ---------- OPTIONAL: MIXED AGE-CONDITION SPM ----------
                if isfield(HS, 'run_spm_mixed_age_condition') && HS.run_spm_mixed_age_condition

                    ageLevels_mixed = keep_present_in_order( cellstr(C.plotting.age_order), categories(removecats(Tp.age_group)));

                    condLevels_mixed = keep_present_in_order( cellstr(C.plotting.condition_order), categories(removecats(Tp.condition)));

                    if numel(ageLevels_mixed) >= 2 && numel(condLevels_mixed) >= 2

                        spmMixedInfo = run_spm_mixed_age_condition_on_spectrum( Tp, ageLevels_mixed, condLevels_mixed, freqRef, HS);

                        if spmMixedInfo.ok
                            fprintf('\nMIXED SPM OK | %s\n', string(pairName));
                            fprintf('  n subjects = %d\n', spmMixedInfo.n_subjects);
                            fprintf('  n rows     = %d\n', spmMixedInfo.n_rows);

                            print_mixed_spm_result_summary(spmMixedInfo, pairName);
                        else
                            fprintf('\nMIXED SPM NOT OK | %s | %s\n', string(pairName), string(spmMixedInfo.label));
                        end
                    end
                end
            end
        end
    end

    %% ===================== CYCLE-PERCENTAGE TRIPLETS =====================

    if HC.analysis.make_cycle_triplets

        fprintf('\nGenerating cycle-percentage coherence triplets...\n');

        cycleTripletDir = fullfile(HC.io.plots_dir, 'cycle_triplets');
        if ~exist(cycleTripletDir, 'dir')
            mkdir(cycleTripletDir);
        end

        T_cycle_row = build_cycle_triplet_table_from_results( COH_DEFAULT, C, HC);

        if ~isempty(T_cycle_row)

            t0 = unwrap_table_vector_entry(T_cycle_row.Time_percent, 1);
            a0 = unwrap_table_vector_entry(T_cycle_row.Alpha_curve, 1);
            b0 = unwrap_table_vector_entry(T_cycle_row.Beta_curve, 1);
            g0 = unwrap_table_vector_entry(T_cycle_row.Gamma_curve, 1);

        end

        if isempty(T_cycle_row)
            warning('No cycle-triplet rows could be built. Skipping cycle triplets.');
        else
            writetable(flatten_cycle_triplet_table(T_cycle_row), fullfile(cycleTripletDir, 'T_cycle_row_flat.csv'));

            if HC.analysis.cycle_triplet_average_legs
                T_cycle_subj = average_cycle_triplet_legs(T_cycle_row);
            else
                T_cycle_subj = T_cycle_row;
            end

            if ~isempty(T_cycle_subj)
                t0 = unwrap_table_vector_entry(T_cycle_subj.Time_percent, 1);
                a0 = unwrap_table_vector_entry(T_cycle_subj.Alpha_curve, 1);
                b0 = unwrap_table_vector_entry(T_cycle_subj.Beta_curve, 1);
                g0 = unwrap_table_vector_entry(T_cycle_subj.Gamma_curve, 1);
            end

            writetable(flatten_cycle_triplet_table(T_cycle_subj), fullfile(cycleTripletDir, 'T_cycle_subject_flat.csv'));

            pairList = categories(removecats(T_cycle_subj.pair_name));

            for ip = 1:numel(pairList)
                pairName = pairList{ip};
                Tp = T_cycle_subj(T_cycle_subj.pair_name == pairName, :);

                if isempty(Tp)
                    continue;
                end

                % ---------- by age ----------
                fig1 = figure('Visible', HC.plot.cycle_triplets.visible, 'Color', 'w', 'Position', [100 100 1650 520]);

                make_cycle_triplet_figure( fig1, Tp, pairName, 'age_group', cellstr(C.plotting.age_order), @(x)get_age_color(x,C), C, HC, 'Age group');

                saveas(fig1, fullfile(cycleTripletDir, sprintf('CYCLE_TRIPLET__%s__BY_AGE__%s.png', char(string(pairName)), HC.analysis.cycle_triplet_source)));
                close(fig1);

                % ---------- by condition ----------
                fig2 = figure('Visible', HC.plot.cycle_triplets.visible, 'Color', 'w', 'Position', [100 100 1650 520]);

                make_cycle_triplet_figure( fig2, Tp, pairName, 'condition', cellstr(C.plotting.condition_order), @(x)get_condition_color(x,C), C, HC, 'Condition');

                saveas(fig2, fullfile(cycleTripletDir, sprintf('CYCLE_TRIPLET__%s__BY_CONDITION__%s.png', char(string(pairName)), HC.analysis.cycle_triplet_source)));
                close(fig2);
            end
        end
    end

    %% ===================== SAVE WORKSPACE =====================

    save(fullfile(HC.io.mat_dir, sprintf('workspace__%s.mat', ANALYSIS_TAG)), 'T_row', 'T_subj', 'DESCRIPTIVE_ALL', 'OMNIBUS_TABLE', 'POSTHOC_TABLE', 'HC', 'ANALYSIS_TAG', '-v7.3');

    % Optional latest-copy workspace
    save(HC.io.workspace_mat, 'T_row', 'T_subj', 'DESCRIPTIVE_ALL', 'OMNIBUS_TABLE', 'POSTHOC_TABLE', 'HC', 'ANALYSIS_TAG', '-v7.3');

    fprintf('\nDone.\n');
    fprintf('Results saved in:\n%s\n', HC.io.out_dir);

end

%% ===================== LOCAL FUNCTIONS =====================

% function [x_for_wav, idx_orig] = build_padded_signal_for_wavelet_simple(x, Tseg, paddingCfg, whichSignal)

%     [x_for_wav, idx_orig, ~] = build_padded_signal_for_wavelet(x, Tseg, paddingCfg, whichSignal);
% end

% function [specCurve, freqVec, timeIdx, hasScope] = extract_spectrum_from_result(R, HS)

%     specCurve = [];
%     freqVec = [];
%     timeIdx = [];
%     hasScope = false;

%     try
%         if HS.spectrum_source == "sig"
%             M = R.Coherence_sig;
%         elseif HS.spectrum_source == "sig_equalized"
%             M = R.Coherence_sig_equalized;
%         elseif HS.spectrum_source == "sig_common_threshold"
%             M = R.Coherence_sig_common_threshold;
%         elseif HS.spectrum_source == "zcoh_bokil"
%             M = R.Coherence_zcoh_bokil;
%         elseif HS.spectrum_source == "surrogate_delta"
%             M = R.Coherence_surrogate_delta;
%         elseif HS.spectrum_source == "cycle_bias_corrected"
%             M = R.Coherence_cycle_bias_corrected;
%         else
%             M = R.Coherence;
%         end

%         freqVec = R.Freq(:);

%         switch lower(string(HS.scope))
%             case "poi"
%                 if result_has_poi(R)
%                     timeIdx = get_poi_indices(R);
%                     hasScope = true;
%                 end

%             case "full"
%                 if isfield(R, 'Time_percent') && ~isempty(R.Time_percent)
%                     timeIdx = 1:numel(R.Time_percent);
%                     hasScope = true;
%                 end

%             case "stance"
%                 if isfield(R, 'StanceIndices') && ~isempty(R.StanceIndices)
%                     timeIdx = R.StanceIndices;
%                     hasScope = true;
%                 end

%             case "swing"
%                 if isfield(R, 'SwingIndices') && ~isempty(R.SwingIndices)
%                     timeIdx = R.SwingIndices;
%                     hasScope = true;
%                 end
%         end

%         if ~hasScope || isempty(timeIdx) || isempty(M)
%             return;
%         end

%         idxF = freqVec >= HS.freq_min & freqVec <= HS.freq_max;
%         freqVec = freqVec(idxF);
%         specCurve = mean(M(idxF, timeIdx), 2, 'omitnan');

%     catch
%         specCurve = [];
%         freqVec = [];
%         timeIdx = [];
%         hasScope = false;
%     end
% end

% function add_spm_cluster_shading(ax, spmInfo, HS)

%     if isempty(spmInfo) || ~isfield(spmInfo, 'clusters') || isempty(spmInfo.clusters)
%         return;
%     end

%     yl = ylim(ax);

%     for i = 1:numel(spmInfo.clusters)
%         f1 = spmInfo.clusters(i).f1;
%         f2 = spmInfo.clusters(i).f2;

%         patch(ax, [f1 f2 f2 f1], [yl(1) yl(1) yl(2) yl(2)], [0.7 0.7 0.7], 'FaceAlpha', HS.sig_patch_facealpha, 'EdgeColor', 'none');
%     end

%     uistack(findobj(ax, 'Type', 'line'), 'top');
% end

% function add_spm_cluster_stars(ax, spmInfo)

%     if isempty(spmInfo) || ~isfield(spmInfo, 'clusters') || isempty(spmInfo.clusters)
%         return;
%     end

%     yl = ylim(ax);
%     y = yl(2) * 0.95;

%     for i = 1:numel(spmInfo.clusters)
%         f1 = spmInfo.clusters(i).f1;
%         f2 = spmInfo.clusters(i).f2;
%         p = spmInfo.clusters(i).p;

%         xc = mean([f1 f2]);
%         txt = p_to_stars(p);

%         plot(ax, [f1 f1 f2 f2], [y-0.01*(yl(2)-yl(1)) y y y-0.01*(yl(2)-yl(1))], 'k-', 'LineWidth', 1.0);
%         text(ax, xc, y, txt, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontWeight', 'bold');
%         y = y - 0.04*(yl(2)-yl(1));
%     end
% end

% function txtLines = make_spm_summary_text(spmInfo, labelTxt)

%     txtLines = {};

%     if isempty(spmInfo)
%         return;
%     end

%     if isfield(spmInfo, 'label') && ~isempty(spmInfo.label)
%         txtLines{end+1} = spmInfo.label; %#ok<AGROW>
%     else
%         txtLines{end+1} = sprintf('%s SPM', labelTxt); %#ok<AGROW>
%     end

%     if isfield(spmInfo, 'clusters') && ~isempty(spmInfo.clusters)
%         txtLines{end+1} = sprintf('sig clusters: %d', numel(spmInfo.clusters)); %#ok<AGROW>
%     else
%         txtLines{end+1} = 'sig clusters: 0'; %#ok<AGROW>
%     end
% end
% function T = standardize_spectrum_table(T)

%     if isempty(T) || ~ismember('Spectrum', T.Properties.VariableNames)
%         return;
%     end

%     specIsCell = iscell(T.Spectrum);
%     hasFreq = ismember('Freq', T.Properties.VariableNames);
%     if hasFreq
%         freqIsCell = iscell(T.Freq);
%     else
%         freqIsCell = false;
%     end

%     for i = 1:height(T)

%         % ----- Spectrum -----
%         if specIsCell
%             s = T.Spectrum{i};
%         else
%             s = T.Spectrum(i,:);
%         end

%         s = squeeze(s);

%         if isempty(s)
%             s_out = [];
%         elseif isvector(s)
%             s_out = s(:)';   % force row
%         else
%             s_out = mean(s, 1, 'omitnan');
%             s_out = s_out(:)';
%         end

%         if specIsCell
%             T.Spectrum{i} = s_out;
%         else
%             T.Spectrum(i,1:numel(s_out)) = s_out;
%         end

%         % ----- Freq -----
%         if hasFreq
%             if freqIsCell
%                 f = T.Freq{i};
%             else
%                 f = T.Freq(i,:);
%             end

%             f = squeeze(f);

%             if isempty(f)
%                 f_out = [];
%             else
%                 f_out = f(:)';
%             end

%             if freqIsCell
%                 T.Freq{i} = f_out;
%             else
%                 T.Freq(i,1:numel(f_out)) = f_out;
%             end
%         end
%     end
% end

% function clusters = get_spmi_clusters_safe(spmi)
% % Safely return SPM clusters as a struct/object array

%     clusters = [];

%     if isempty(spmi)
%         return;
%     end

%     try
%         if isprop(spmi, 'clusters')
%             clusters = spmi.clusters;
%             return;
%         end
%     catch
%     end

%     try
%         if isfield(spmi, 'clusters')
%             clusters = spmi.clusters;
%             return;
%         end
%     catch
%     end

%     clusters = [];
% end

function P = make_spectrum_spm_params(HS)
%MAKE_SPECTRUM_SPM_PARAMS
% Centralized SPM/SnPM settings for all spectrum profile analyses.

    P = struct();

    if isfield(HS, 'use_nonparametric')
        P.use_nonparametric = HS.use_nonparametric;
    elseif isfield(HS, 'mixed_use_nonparametric')
        % Backward compatibility
        P.use_nonparametric = HS.mixed_use_nonparametric;
    else
        P.use_nonparametric = false;
    end

    if isfield(HS, 'spm_alpha') && ~isempty(HS.spm_alpha)
        P.alpha = HS.spm_alpha;
    else
        P.alpha = 0.05;
    end

    if isfield(HS, 'two_tailed') && ~isempty(HS.two_tailed)
        P.two_tailed = HS.two_tailed;
    else
        P.two_tailed = true;
    end

    if isfield(HS, 'nonparam_iterations') && ~isempty(HS.nonparam_iterations)
        P.nonparam_iterations = HS.nonparam_iterations;
    elseif isfield(HS, 'mixed_nonparam_iterations') && ~isempty(HS.mixed_nonparam_iterations)
        P.nonparam_iterations = HS.mixed_nonparam_iterations;
    else
        P.nonparam_iterations = 5000;
    end
end



% % function add_poi_patch(ax, startPct, endPct, faceAlpha)

% %     if isnan(startPct) || isnan(endPct)
% %         return;
% %     end

% %     yl = ylim(ax);

% %     if startPct <= endPct
% %         patch(ax, [startPct endPct endPct startPct], [yl(1) yl(1) yl(2) yl(2)], [0.5 0.5 0.5], 'FaceAlpha', faceAlpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
% %     else
% %         % wrap-around window, e.g. 60 -> 20
% %         patch(ax, [startPct 100 100 startPct], [yl(1) yl(1) yl(2) yl(2)], [0.5 0.5 0.5], 'FaceAlpha', faceAlpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
% %         patch(ax, [0 endPct endPct 0], [yl(1) yl(1) yl(2) yl(2)], [0.5 0.5 0.5], 'FaceAlpha', faceAlpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
% %     end
% % end

% function [spm_age, spm_condition, spm_interaction] = unpack_anova2onerm_outputs(spm_all)
% %UNPACK_ANOVA2ONERM_OUTPUTS
% % Handles both:
% %   parametric:    spm1d.stats.spm.SPMFList
% %   nonparametric: spm1d.stats.nonparam.snpm.SnPM1D_FList
% %
% % Expected effects:
% %   1 = Main A           age
% %   2 = Main B           condition
% %   3 = Interaction AB   age x condition

%     spm_age = [];
%     spm_condition = [];
%     spm_interaction = [];

%     if isempty(spm_all)
%         error('anova2onerm output is empty.');
%     end

%     % ---------- Best case: list supports round indexing ----------
%     try
%         spm_age         = spm_all(1);
%         spm_condition   = spm_all(2);
%         spm_interaction = spm_all(3);
%         return;
%     catch
%         % continue to fallback options
%     end

%     % ---------- Fallback: object has .SPMs property/field ----------
%     try
%         if isprop(spm_all, 'SPMs') || isfield(spm_all, 'SPMs')

%             S = spm_all.SPMs;

%             if iscell(S)
%                 if numel(S) >= 3
%                     spm_age         = S{1};
%                     spm_condition   = S{2};
%                     spm_interaction = S{3};
%                     return;
%                 end
%             else
%                 if numel(S) >= 3
%                     spm_age         = S(1);
%                     spm_condition   = S(2);
%                     spm_interaction = S(3);
%                     return;
%                 end
%             end
%         end
%     catch
%         % continue to final error
%     end

%     error('Could not unpack anova2onerm output. class=%s, size=%s, numel=%d', class(spm_all), mat2str(size(spm_all)), numel(spm_all));
% end

% function out = get_first_existing_field(S, names)

%     out = [];

%     for i = 1:numel(names)
%         if isfield(S, names{i})
%             out = S.(names{i});
%             return;
%         end
%     end
% end

% function spmi = run_spm_inference_safe(spmObj, alpha, nIter)
% %RUN_SPM_INFERENCE_SAFE
% % Works for parametric SPM and nonparametric SnPM objects.

%     spmi = [];

%     if isempty(spmObj)
%         return;
%     end

%     if nargin < 2 || isempty(alpha)
%         alpha = 0.05;
%     end

%     try
%         if nargin >= 3 && ~isempty(nIter)
%             % Nonparametric inference usually accepts iterations
%             try
%                 spmi = spmObj.inference(alpha, 'iterations', nIter);
%             catch
%                 try
%                     spmi = spmObj.inference(alpha, nIter);
%                 catch
%                     spmi = spmObj.inference(alpha);
%                 end
%             end
%         else
%             spmi = spmObj.inference(alpha);
%         end
%     catch ME
%         warning('SPM inference failed: %s', ME.message);
%         spmi = [];
%     end
% end

% function apply_spectrum_ylim(ax, HC, HS)
% %APPLY_SPECTRUM_YLIM Force clean y-limits for spectrum figures.
% % Priority:
% %   1) HS.fixed_ylim if enabled
% %   2) HC.plot.coherence_ylim if enabled
% %   3) auto upper limit, but lower bound forced to 0

%     if nargin < 3
%         HS = struct();
%     end

%     % ----- spectrum-specific fixed ylim -----
%     if isfield(HS, 'use_fixed_ylim') && HS.use_fixed_ylim && isfield(HS, 'fixed_ylim') && numel(HS.fixed_ylim) == 2

%         ylim(ax, HS.fixed_ylim);
%         return;
%     end

%     % ----- general coherence fixed ylim -----
%     if isfield(HC, 'plot') && isfield(HC.plot, 'use_fixed_coherence_ylim') && HC.plot.use_fixed_coherence_ylim && isfield(HC.plot, 'coherence_ylim') && numel(HC.plot.coherence_ylim) == 2

%         ylim(ax, HC.plot.coherence_ylim);
%         return;
%     end

%     % ----- otherwise: keep autoscaled top, force bottom to 0 -----
%     yl = ylim(ax);
%     yTop = yl(2);

%     if ~isfinite(yTop) || yTop <= 0
%         yTop = 0.1;
%     end

%     ylim(ax, [0 yTop]);
% end

% function cycleInfo = get_cycle_count_info_for_metric(R, coherenceSource)
% %GET_CYCLE_COUNT_INFO_FOR_METRIC
% % Returns the cycle-count information relevant for the selected coherence source.
% %
% % n_cycles_available:
% %   number of cycles available after QC / retained for normal coherence
% %
% % n_cycles_used_for_metric:
% %   number of cycles actually used to compute the selected coherence metric
% %
% % For raw/sig/sig_common_threshold/zcoh_bokil/surrogate_delta:
% %   the coherence estimate is based on R.n_cycles_used.
% %
% % For sig_equalized, equalized:
% %   the coherence estimate is based on the equalized cycle mask/count.

%     coherenceSource = lower(string(coherenceSource));

%     cycleInfo = struct();
%     cycleInfo.n_cycles_available = NaN;
%     cycleInfo.n_cycles_used_for_metric = NaN;
%     cycleInfo.cycle_count_source_for_metric = "";

%     % ---------- available retained cycles ----------
%     if isfield(R, 'n_cycles_used') && ~isempty(R.n_cycles_used)
%         cycleInfo.n_cycles_available = double(R.n_cycles_used);

%     elseif isfield(R, 'cycle_equalization') && isfield(R.cycle_equalization, 'N_available_before_equalization') && ~isempty(R.cycle_equalization.N_available_before_equalization)

%         cycleInfo.n_cycles_available = double(R.cycle_equalization.N_available_before_equalization);
%     end

%     % ---------- actual cycles used for selected metric ----------
%     switch coherenceSource

%         case {"raw", "sig", "sig_common_threshold", "zcoh_bokil", "surrogate_delta", "cycle_bias_corrected"}

%             cycleInfo.n_cycles_used_for_metric = cycleInfo.n_cycles_available;
%             cycleInfo.cycle_count_source_for_metric = "R.n_cycles_used";

%         case {"sig_equalized", "equalized"}

%             if isfield(R, 'n_cycles_equalized_used') && ~isempty(R.n_cycles_equalized_used) && isfinite(double(R.n_cycles_equalized_used))

%                 cycleInfo.n_cycles_used_for_metric = double(R.n_cycles_equalized_used);
%                 cycleInfo.cycle_count_source_for_metric = "R.n_cycles_equalized_used";

%             elseif isfield(R, 'Metrics') && isfield(R.Metrics, 'info') && isfield(R.Metrics.info, 'N_equalized_used') && ~isempty(R.Metrics.info.N_equalized_used) && isfinite(double(R.Metrics.info.N_equalized_used))

%                 cycleInfo.n_cycles_used_for_metric = double(R.Metrics.info.N_equalized_used);
%                 cycleInfo.cycle_count_source_for_metric = "R.Metrics.info.N_equalized_used";

%             elseif isfield(R, 'cycle_equalization') && isfield(R.cycle_equalization, 'N_used_after_equalization') && ~isempty(R.cycle_equalization.N_used_after_equalization) && isfinite(double(R.cycle_equalization.N_used_after_equalization))

%                 cycleInfo.n_cycles_used_for_metric = double(R.cycle_equalization.N_used_after_equalization);
%                 cycleInfo.cycle_count_source_for_metric = "R.cycle_equalization.N_used_after_equalization";

%             else
%                 warning(['sig_equalized or equalized selected but no equalized cycle-count field found. ' 'Falling back to available retained cycles.']);

%                 cycleInfo.n_cycles_used_for_metric = cycleInfo.n_cycles_available;
%                 cycleInfo.cycle_count_source_for_metric = "fallback_R.n_cycles_used";
%             end

%         otherwise

%             warning('Unknown coherence_source "%s". Falling back to R.n_cycles_used.', coherenceSource);
%             cycleInfo.n_cycles_used_for_metric = cycleInfo.n_cycles_available;
%             cycleInfo.cycle_count_source_for_metric = "fallback_R.n_cycles_used";
%     end
% end


% function T_subj = add_leg_averaged_cycle_count_variables(T_subj, T_row, G)
% %ADD_LEG_AVERAGED_CYCLE_COUNT_VARIABLES
% % Adds leg-averaged cycle-count variables to subject-level table.

%     % Backward-compatible original variable if present
%     if ismember('n_cycles_used', T_row.Properties.VariableNames)
%         T_subj.mean_cycles_used_across_legs = splitapply(@(x) mean(x, 'omitnan'), T_row.n_cycles_used, G);
%         T_subj.min_cycles_used_across_legs  = splitapply(@(x) min(x, [], 'omitnan'), T_row.n_cycles_used, G);
%     end

%     % New explicit variables
%     if ismember('n_cycles_available', T_row.Properties.VariableNames)
%         T_subj.mean_cycles_available_across_legs = splitapply(@(x) mean(x, 'omitnan'), T_row.n_cycles_available, G);

%         T_subj.min_cycles_available_across_legs = splitapply(@(x) min(x, [], 'omitnan'), T_row.n_cycles_available, G);
%     end

%     if ismember('n_cycles_used_for_metric', T_row.Properties.VariableNames)
%         T_subj.mean_cycles_used_for_metric_across_legs = splitapply(@(x) mean(x, 'omitnan'), T_row.n_cycles_used_for_metric, G);

%         T_subj.min_cycles_used_for_metric_across_legs = splitapply(@(x) min(x, [], 'omitnan'), T_row.n_cycles_used_for_metric, G);
%     end

%     if ismember('cycle_count_source_for_metric', T_row.Properties.VariableNames)
%         T_subj.cycle_count_source_for_metric = splitapply(@get_unique_string_or_mixed, string(T_row.cycle_count_source_for_metric), G);
%     end
% end


% function out = get_unique_string_or_mixed(x)
% %GET_UNIQUE_STRING_OR_MIXED
% % Helper for splitapply on string arrays.

%     x = string(x);
%     x = x(x ~= "" & ~ismissing(x));

%     if isempty(x)
%         out = "";
%         return;
%     end

%     u = unique(x, 'stable');

%     if numel(u) == 1
%         out = u(1);
%     else
%         out = "mixed";
%     end
% end


% function [T_subj, cycleSourceUsed] = create_log_n_cycles_if_needed(T_subj, HC)
% %CREATE_LOG_N_CYCLES_IF_NEEDED
% % Creates log_n_cycles if either the LME covariate or partial correlations need it.
% %
% % The preferred source is mean_cycles_used_for_metric_across_legs, because this
% % represents the actual number of cycles used to compute the selected metric.

%     includeCycleCov = isfield(HC.analysis, 'include_cycle_count_covariate') && HC.analysis.include_cycle_count_covariate;

%     includeCycleCorr = isfield(HC.analysis, 'include_cycle_count_in_correlations') && HC.analysis.include_cycle_count_in_correlations;

%     needLogNCycles = includeCycleCov || includeCycleCorr;

%     cycleSourceUsed = "";

%     if ~needLogNCycles
%         fprintf('\n=== log_n_cycles not created ===\n');
%         fprintf('Reason: no cycle covariate in LME and no partial cycle correlations requested.\n');
%         return;
%     end

%     preferredSource = "mean_cycles_used_for_metric_across_legs";

%     if isfield(HC.analysis, 'cycle_count_covariate_source') && ~isempty(HC.analysis.cycle_count_covariate_source)
%         preferredSource = string(HC.analysis.cycle_count_covariate_source);
%     end

%     candidateSources = [ preferredSource, "mean_cycles_used_for_metric_across_legs", "min_cycles_used_for_metric_across_legs", "mean_cycles_available_across_legs", "mean_cycles_used_across_legs", "min_cycles_used_across_legs" ];

%     candidateSources = unique(candidateSources, 'stable');

%     cycleVar = [];

%     for i = 1:numel(candidateSources)
%         src = candidateSources(i);

%         if ismember(src, string(T_subj.Properties.VariableNames))
%             cycleVar = T_subj.(char(src));
%             cycleSourceUsed = src;
%             break;
%         end
%     end

%     if isempty(cycleVar)
%         error(['log_n_cycles requested, but no cycle-count variable found in T_subj. ' 'Expected mean_cycles_used_for_metric_across_legs or similar.']);
%     end

%     cycleVar = double(cycleVar);
%     cycleVar(cycleVar <= 0) = NaN;

%     T_subj.log_n_cycles = log(cycleVar);

%     fprintf('\n=== log_n_cycles created ===\n');
%     fprintf('Reason: includeCycleCov=%d | includeCycleCorr=%d\n', includeCycleCov, includeCycleCorr);
%     fprintf('Using log_n_cycles = log(%s)\n', cycleSourceUsed);
%     fprintf('Valid log_n_cycles rows: %d / %d\n', sum(isfinite(T_subj.log_n_cycles)), height(T_subj));
% end


% function useCycleCovInThisModel = should_use_cycle_covariate_in_model(Tm, HC)
% %SHOULD_USE_CYCLE_COVARIATE_IN_MODEL
% % Returns true only if cycle covariate is requested and usable.
% %
% % It skips log_n_cycles if:
% %   - option is disabled
% %   - variable is missing
% %   - too few valid rows
% %   - log_n_cycles is constant
% %
% % This prevents invalid models for sig_equalized if all entries use the same N.

%     includeCycleCov = isfield(HC.analysis, 'include_cycle_count_covariate') && HC.analysis.include_cycle_count_covariate;

%     useCycleCovInThisModel = includeCycleCov;

%     if ~includeCycleCov
%         return;
%     end

%     if ~ismember('log_n_cycles', Tm.Properties.VariableNames)
%         warning('Cycle-count covariate requested but log_n_cycles is missing. Skipping covariate for this model.');
%         useCycleCovInThisModel = false;
%         return;
%     end

%     validCycle = isfinite(Tm.log_n_cycles);

%     if sum(validCycle) < 5
%         warning('Cycle-count covariate requested but fewer than 5 valid log_n_cycles values. Skipping covariate.');
%         useCycleCovInThisModel = false;
%         return;
%     end

%     if std(Tm.log_n_cycles(validCycle), 'omitnan') < 1e-10
%         fprintf(['Cycle-count covariate requested but skipped: ' 'log_n_cycles is constant for this model.\n']);
%         useCycleCovInThisModel = false;
%         return;
%     end
% end


% function formula = make_lme_formula_with_optional_cycle_covariate(dv, HC, Tm)
% %MAKE_LME_FORMULA_WITH_OPTIONAL_CYCLE_COVARIATE
% % Builds the main LME formula.

%     useCycleCovInThisModel = should_use_cycle_covariate_in_model(Tm, HC);

%     if useCycleCovInThisModel
%         formula = sprintf('%s ~ age_group * condition + log_n_cycles + (1|subject)', dv);
%     else
%         formula = sprintf('%s ~ age_group * condition + (1|subject)', dv);
%     end
% end


% function formula = make_power_control_formula_with_optional_cycle_covariate(dv, powVar, HC, Tm)
% %MAKE_POWER_CONTROL_FORMULA_WITH_OPTIONAL_CYCLE_COVARIATE
% % Builds the power-control LME formula.

%     useCycleCovInThisModel = should_use_cycle_covariate_in_model(Tm, HC);

%     if useCycleCovInThisModel
%         formula = sprintf('%s ~ age_group * condition + %s + log_n_cycles + (1|subject)', dv, powVar);
%     else
%         formula = sprintf('%s ~ age_group * condition + %s + (1|subject)', dv, powVar);
%     end
% end



% function col = local_get_condition_color_for_lmm_plot(condName, C)

%     if exist('get_condition_color', 'file') == 2
%         try
%             col = get_condition_color(condName, C);
%             return;
%         catch
%         end
%     end

%     switch char(string(condName))
%         case 'Flat'
%             col = [0.25 0.25 0.25];
%         case 'Medium'
%             col = [0.35 0.35 0.35];
%         case 'High'
%             col = [0.05 0.05 0.05];
%         otherwise
%             col = [0.45 0.45 0.45];
%     end
% end