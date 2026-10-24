%% analyze_kinematics_for_coherence_cycles.m
% Analyze marker-derived gait metrics on the exact cycles retained for
% coherence analysis.
%
% This script intentionally avoids cycle-level plots/statistics as the main
% evidence, because retained cycle counts are imbalanced across participants,
% legs, conditions, pairs, and bands.
%
% Main analysis level:
%   1) cycles -> signal summary
%      subject x condition x leg x pair x band x selection
%   2) signal summaries -> leg-averaged summary
%      subject x condition x pair x band x selection
%   3) plots/stats use leg-averaged summaries.
function analyze_kinematics_for_coherence_cycles()
    

    C = config_emg();
    A = get_kinematics_analysis_config(C);

    if ~exist(A.io.out_dir, 'dir'), mkdir(A.io.out_dir); end
    if ~exist(A.io.tables_dir, 'dir'), mkdir(A.io.tables_dir); end
    if ~exist(A.io.plots_dir, 'dir'), mkdir(A.io.plots_dir); end

    assert(isfile(A.io.in_mat), 'Input mat not found: %s', A.io.in_mat);

    L = load(A.io.in_mat, 'KINEMATICS_COHERENCE_CYCLES_TABLE');
    assert(isfield(L, 'KINEMATICS_COHERENCE_CYCLES_TABLE'), 'KINEMATICS_COHERENCE_CYCLES_TABLE missing in %s', A.io.in_mat);

    Tcycle = L.KINEMATICS_COHERENCE_CYCLES_TABLE;

    fprintf('\nInput cycle rows: %d\n', height(Tcycle));

    Tcycle = standardize_kinematics_types(Tcycle, A);

    % Keep rows with a real stride metric for the main gait analysis.
    TvalidStride = Tcycle(~isnan(Tcycle.stride_length_m) & ~isnan(Tcycle.stride_speed_mps), :);
    fprintf('Rows with usable stride metrics: %d / %d\n', height(TvalidStride), height(Tcycle));

    SIGNAL_KINEMATICS_SUMMARY = summarize_cycles_to_signal(TvalidStride, A);
    LEG_AVERAGED_KINEMATICS_SUMMARY = average_legs_first(SIGNAL_KINEMATICS_SUMMARY, A);
    PAIR_AVERAGED_KINEMATICS_SUMMARY = average_pairs_after_legs(LEG_AVERAGED_KINEMATICS_SUMMARY, A);

    KINEMATICS_MODEL_RESULTS = run_condition_models(LEG_AVERAGED_KINEMATICS_SUMMARY, A);
    KINEMATICS_COMPLETE_CASE_RESULTS = run_complete_case_friedman(LEG_AVERAGED_KINEMATICS_SUMMARY, A);
    KINEMATICS_PAIRWISE_CONDITION_RESULTS = run_pairwise_condition_tests(LEG_AVERAGED_KINEMATICS_SUMMARY, A);
    KINEMATICS_PAIRWISE_CONDITION_RESULTS_ACROSS_PAIRS = run_pairwise_condition_tests(PAIR_AVERAGED_KINEMATICS_SUMMARY, A);

    writetable(SIGNAL_KINEMATICS_SUMMARY, A.io.signal_summary_xlsx);
    writetable(LEG_AVERAGED_KINEMATICS_SUMMARY, A.io.leg_averaged_summary_xlsx);
    writetable(PAIR_AVERAGED_KINEMATICS_SUMMARY, A.io.pair_averaged_summary_xlsx);
    writetable(KINEMATICS_MODEL_RESULTS, A.io.model_results_xlsx);
    writetable(KINEMATICS_COMPLETE_CASE_RESULTS, A.io.complete_case_results_xlsx);
    writetable(KINEMATICS_PAIRWISE_CONDITION_RESULTS, A.io.pairwise_results_xlsx);
    writetable(KINEMATICS_PAIRWISE_CONDITION_RESULTS_ACROSS_PAIRS, A.io.pairwise_across_pairs_results_xlsx);

    writetable(SIGNAL_KINEMATICS_SUMMARY, A.io.signal_summary_csv);
    writetable(LEG_AVERAGED_KINEMATICS_SUMMARY, A.io.leg_averaged_summary_csv);
    writetable(PAIR_AVERAGED_KINEMATICS_SUMMARY, A.io.pair_averaged_summary_csv);
    writetable(KINEMATICS_MODEL_RESULTS, A.io.model_results_csv);
    writetable(KINEMATICS_COMPLETE_CASE_RESULTS, A.io.complete_case_results_csv);
    writetable(KINEMATICS_PAIRWISE_CONDITION_RESULTS, A.io.pairwise_results_csv);
    writetable(KINEMATICS_PAIRWISE_CONDITION_RESULTS_ACROSS_PAIRS, A.io.pairwise_across_pairs_results_csv);

    save(A.io.out_mat, 'Tcycle', 'SIGNAL_KINEMATICS_SUMMARY', 'LEG_AVERAGED_KINEMATICS_SUMMARY', 'PAIR_AVERAGED_KINEMATICS_SUMMARY', 'KINEMATICS_MODEL_RESULTS', 'KINEMATICS_COMPLETE_CASE_RESULTS', 'KINEMATICS_PAIRWISE_CONDITION_RESULTS', 'KINEMATICS_PAIRWISE_CONDITION_RESULTS_ACROSS_PAIRS', 'A', '-v7.3');

    make_condition_plots(LEG_AVERAGED_KINEMATICS_SUMMARY, KINEMATICS_PAIRWISE_CONDITION_RESULTS, A);
    make_condition_plots(PAIR_AVERAGED_KINEMATICS_SUMMARY, KINEMATICS_PAIRWISE_CONDITION_RESULTS_ACROSS_PAIRS, A);

    print_analysis_recap(Tcycle, SIGNAL_KINEMATICS_SUMMARY, LEG_AVERAGED_KINEMATICS_SUMMARY, A);

    fprintf('\nSaved analysis outputs to:\n  %s\n', A.io.out_dir);
end

%% ===================== LOCAL FUNCTIONS =====================

function A = get_kinematics_analysis_config(C)
    A = struct();

    if isfield(C, 'g2_kinematics_analysis')
        A = C.g2_kinematics_analysis;
    end

    A.io = ensure_field(A, 'io', struct());
    A.params = ensure_field(A, 'params', struct());
    A.plot = ensure_field(A, 'plot', struct());

    kinRoot = fullfile(get_nested_or_default(C, {'paths','results_dir'}, pwd), 'kinematics_coherence_cycles');

    A.io.in_mat = get_nested_or_default(A, {'io','in_mat'}, fullfile(kinRoot, 'KINEMATICS_COHERENCE_CYCLES.mat'));

    A.io.out_dir = get_nested_or_default(A, {'io','out_dir'}, fullfile(get_nested_or_default(C, {'paths','results_dir'}, pwd), 'g2_kinematics_coherence_analysis'));

    A.io.tables_dir = fullfile(A.io.out_dir, 'tables');
    A.io.plots_dir = fullfile(A.io.out_dir, 'plots');
    A.io.out_mat = fullfile(A.io.out_dir, 'KINEMATICS_COHERENCE_ANALYSIS.mat');

    A.io.signal_summary_xlsx = fullfile(A.io.tables_dir, 'SIGNAL_KINEMATICS_SUMMARY.xlsx');
    A.io.leg_averaged_summary_xlsx = fullfile(A.io.tables_dir, 'LEG_AVERAGED_KINEMATICS_SUMMARY.xlsx');
    A.io.pair_averaged_summary_xlsx = fullfile(A.io.tables_dir, 'PAIR_AVERAGED_KINEMATICS_SUMMARY.xlsx');
    A.io.model_results_xlsx = fullfile(A.io.tables_dir, 'KINEMATICS_CONDITION_LME_RESULTS.xlsx');
    A.io.complete_case_results_xlsx = fullfile(A.io.tables_dir, 'KINEMATICS_COMPLETE_CASE_FRIEDMAN_RESULTS.xlsx');
    A.io.pairwise_results_xlsx = fullfile(A.io.tables_dir, 'KINEMATICS_PAIRWISE_CONDITION_TESTS.xlsx');
    A.io.pairwise_across_pairs_results_xlsx = fullfile(A.io.tables_dir, 'KINEMATICS_PAIRWISE_CONDITION_TESTS_ACROSS_PAIRS.xlsx');

    A.io.signal_summary_csv = fullfile(A.io.tables_dir, 'SIGNAL_KINEMATICS_SUMMARY.csv');
    A.io.leg_averaged_summary_csv = fullfile(A.io.tables_dir, 'LEG_AVERAGED_KINEMATICS_SUMMARY.csv');
    A.io.pair_averaged_summary_csv = fullfile(A.io.tables_dir, 'PAIR_AVERAGED_KINEMATICS_SUMMARY.csv');
    A.io.model_results_csv = fullfile(A.io.tables_dir, 'KINEMATICS_CONDITION_LME_RESULTS.csv');
    A.io.complete_case_results_csv = fullfile(A.io.tables_dir, 'KINEMATICS_COMPLETE_CASE_FRIEDMAN_RESULTS.csv');
    A.io.pairwise_results_csv = fullfile(A.io.tables_dir, 'KINEMATICS_PAIRWISE_CONDITION_TESTS.csv');
    A.io.pairwise_across_pairs_results_csv = fullfile(A.io.tables_dir, 'KINEMATICS_PAIRWISE_CONDITION_TESTS_ACROSS_PAIRS.csv');

    A.params.condition_order = string(get_nested_or_default(C, {'plotting','condition_order'}, ["Flat","Medium","High"]));
    A.params.band_order = ["OVERALL", string(get_nested_or_default(C, {'plotting','band_order'}, ["Alpha","Beta","Gamma"]))];
    A.params.pair_order = ["TAprox_TAdist", "SOL_GM"];

    A.params.min_cycles_per_signal = get_nested_or_default(A, {'params','min_cycles_per_signal'}, 5);
    A.params.min_subjects_for_model = get_nested_or_default(A, {'params','min_subjects_for_model'}, 6);
    A.params.min_complete_subjects_for_friedman = get_nested_or_default(A, {'params','min_complete_subjects_for_friedman'}, 5);

    A.params.metrics_to_analyze = string(get_nested_or_default(A, {'params','metrics_to_analyze'}, { 'mean_stride_length_m', 'cv_stride_length_pct', 'mean_stride_speed_mps', 'cv_stride_speed_pct', 'mean_cycle_duration_s', 'cv_cycle_duration_pct', 'mean_step_length_m', 'cv_mean_step_length_pct'}));

    A.plot.visible = char(string(get_nested_or_default(A, {'plot','visible'}, 'off')));
    A.plot.save_png = get_nested_or_default(A, {'plot','save_png'}, true);
    A.plot.save_pdf = get_nested_or_default(A, {'plot','save_pdf'}, false);
    A.plot.show_subject_lines = get_nested_or_default(A, {'plot','show_subject_lines'}, true);
    A.plot.show_pairwise_significance = get_nested_or_default(A, {'plot','show_pairwise_significance'}, true);
    A.plot.significance_alpha = get_nested_or_default(A, {'plot','significance_alpha'}, 0.05);
end

function T = standardize_kinematics_types(T, A)
    if isempty(T), return; end

    stringVars = {'subject','age_group','condition','leg','pair_name','band','selection_name','trial_id','step_metric_note'};
    for i = 1:numel(stringVars)
        v = stringVars{i};
        if ismember(v, T.Properties.VariableNames)
            T.(v) = string(T.(v));
        end
    end

    if ismember('condition', T.Properties.VariableNames)
        T.condition = categorical(T.condition, A.params.condition_order, 'Ordinal', true);
    end
end

function S = summarize_cycles_to_signal(T, A)
    groupVars = {'subject','age_group','condition','leg','pair_name','band','selection_name'};

    if isempty(T) || height(T) == 0
        S = empty_signal_summary(groupVars);
        return;
    end

    [G, keys] = findgroups(T(:, groupVars));
    S = keys;

    S.n_cycles = splitapply(@numel, T.cycle_number, G);
    S.n_unique_trials = splitapply(@(x) numel(unique(string(x))), T.trial_id, G);

    S.mean_cycle_duration_s = splitapply(@nanmean_local, T.cycle_duration_s, G);
    S.sd_cycle_duration_s = splitapply(@nanstd_local, T.cycle_duration_s, G);
    S.cv_cycle_duration_pct = splitapply(@cv_pct_local, T.cycle_duration_s, G);

    S.mean_stride_length_m = splitapply(@nanmean_local, T.stride_length_m, G);
    S.sd_stride_length_m = splitapply(@nanstd_local, T.stride_length_m, G);
    S.cv_stride_length_pct = splitapply(@cv_pct_local, T.stride_length_m, G);

    S.mean_stride_speed_mps = splitapply(@nanmean_local, T.stride_speed_mps, G);
    S.sd_stride_speed_mps = splitapply(@nanstd_local, T.stride_speed_mps, G);
    S.cv_stride_speed_pct = splitapply(@cv_pct_local, T.stride_speed_mps, G);

    S.mean_step_length_m = splitapply(@nanmean_local, T.mean_step_length_m, G);
    S.sd_mean_step_length_m = splitapply(@nanstd_local, T.mean_step_length_m, G);
    S.cv_mean_step_length_pct = splitapply(@cv_pct_local, T.mean_step_length_m, G);

    S = S(S.n_cycles >= A.params.min_cycles_per_signal, :);
end

function S = empty_signal_summary(groupVars)
    S = cell2table(cell(0, numel(groupVars)), 'VariableNames', groupVars);
    numericVars = {'n_cycles','n_unique_trials', 'mean_cycle_duration_s','sd_cycle_duration_s','cv_cycle_duration_pct', 'mean_stride_length_m','sd_stride_length_m','cv_stride_length_pct', 'mean_stride_speed_mps','sd_stride_speed_mps','cv_stride_speed_pct', 'mean_step_length_m','sd_mean_step_length_m','cv_mean_step_length_pct'};
    for i = 1:numel(numericVars)
        S.(numericVars{i}) = zeros(0,1);
    end
end

function L = average_legs_first(S, A)
    groupVars = {'subject','age_group','condition','pair_name','band','selection_name'};
    metricVars = metric_summary_vars();

    if isempty(S) || height(S) == 0
        L = cell2table(cell(0, numel(groupVars)), 'VariableNames', groupVars);
        L.n_legs = zeros(0,1);
        L.n_cycles_total = zeros(0,1);
        for i = 1:numel(metricVars), L.(metricVars{i}) = zeros(0,1); end
        return;
    end

    [G, keys] = findgroups(S(:, groupVars));
    L = keys;

    L.n_legs = splitapply(@(x) numel(unique(string(x))), S.leg, G);
    L.n_cycles_total = splitapply(@sum, S.n_cycles, G);

    for i = 1:numel(metricVars)
        v = metricVars{i};
        L.(v) = splitapply(@nanmean_local, S.(v), G);
    end

    L = sortrows(L, {'pair_name','band','subject','condition'});
end

function P = average_pairs_after_legs(L, A)
    groupVars = {'subject','age_group','condition','band','selection_name'};
    metricVars = metric_summary_vars();

    if isempty(L) || height(L) == 0
        P = table();
        return;
    end

    [G, keys] = findgroups(L(:, groupVars));
    P = keys;
    P.pair_name = repmat("ACROSS_PAIRS", height(P), 1);
    P.n_pairs = splitapply(@(x) numel(unique(string(x))), L.pair_name, G);
    P.n_cycles_total = splitapply(@sum, L.n_cycles_total, G);
    P.n_legs = splitapply(@sum, L.n_legs, G);

    for i = 1:numel(metricVars)
        v = metricVars{i};
        P.(v) = splitapply(@nanmean_local, L.(v), G);
    end

    P = movevars(P, 'pair_name', 'After', 'condition');
    P = sortrows(P, {'pair_name','band','subject','condition'});
end

function vars = metric_summary_vars()
    vars = { 'mean_cycle_duration_s','sd_cycle_duration_s','cv_cycle_duration_pct', 'mean_stride_length_m','sd_stride_length_m','cv_stride_length_pct', 'mean_stride_speed_mps','sd_stride_speed_mps','cv_stride_speed_pct', 'mean_step_length_m','sd_mean_step_length_m','cv_mean_step_length_pct'};
end

function R = run_condition_models(L, A)
    rows = {};
    ri = 0;

    if isempty(L) || height(L) == 0
        R = model_results_table(rows);
        return;
    end

    pairs = unique(string(L.pair_name), 'stable');
    bands = unique(string(L.band), 'stable');
    metrics = A.params.metrics_to_analyze;

    for ip = 1:numel(pairs)
        pairName = pairs(ip);
        for ib = 1:numel(bands)
            band = bands(ib);
            T0 = L(string(L.pair_name) == pairName & string(L.band) == band, :);

            for im = 1:numel(metrics)
                metric = metrics(im);
                if ~ismember(metric, string(T0.Properties.VariableNames)), continue; end

                T = T0(~isnan(T0.(metric)), :);
                nSubjects = numel(unique(string(T.subject)));
                nRows = height(T);
                nConditions = numel(unique(T.condition));

                if nSubjects < A.params.min_subjects_for_model || nConditions < 2
                    ri = ri + 1;
                    rows(ri,:) = {pairName, band, metric, nSubjects, nRows, "skipped_too_few_subjects_or_conditions", NaN, NaN, NaN}; %#ok<AGROW>
                    continue;
                end

                T.metric_value = T.(metric);
                T.subject = categorical(string(T.subject));
                T.condition = categorical(string(T.condition), A.params.condition_order, 'Ordinal', false);

                try
                    mdl0 = fitlme(T, 'metric_value ~ 1 + (1|subject)');
                    mdl1 = fitlme(T, 'metric_value ~ condition + (1|subject)');
                    cmp = compare(mdl0, mdl1);

                    pVal = cmp.pValue(2);
                    deltaAIC = mdl1.ModelCriterion.AIC - mdl0.ModelCriterion.AIC;
                    ri = ri + 1;
                    rows(ri,:) = {pairName, band, metric, nSubjects, nRows, "lme_condition_vs_null", pVal, deltaAIC, mdl1.ModelCriterion.AIC}; %#ok<AGROW>
                catch ME
                    ri = ri + 1;
                    rows(ri,:) = {pairName, band, metric, nSubjects, nRows, "model_failed_" + string(ME.identifier), NaN, NaN, NaN}; %#ok<AGROW>
                end
            end
        end
    end

    R = model_results_table(rows);
end

function R = model_results_table(rows)
    vars = {'pair_name','band','metric','n_subjects','n_rows','test','p_value','delta_aic_condition_minus_null','condition_model_aic'};
    if isempty(rows)
        R = cell2table(cell(0, numel(vars)), 'VariableNames', vars);
    else
        R = cell2table(rows, 'VariableNames', vars);
    end
end

function R = run_complete_case_friedman(L, A)
    rows = {};
    ri = 0;

    if isempty(L) || height(L) == 0
        R = complete_case_results_table(rows);
        return;
    end

    pairs = unique(string(L.pair_name), 'stable');
    bands = unique(string(L.band), 'stable');
    metrics = A.params.metrics_to_analyze;

    for ip = 1:numel(pairs)
        pairName = pairs(ip);
        for ib = 1:numel(bands)
            band = bands(ib);
            T0 = L(string(L.pair_name) == pairName & string(L.band) == band, :);

            for im = 1:numel(metrics)
                metric = metrics(im);
                if ~ismember(metric, string(T0.Properties.VariableNames)), continue; end

                T = T0(~isnan(T0.(metric)), {'subject','condition',char(metric)});
                if isempty(T), continue; end

                W = unstack(T, char(metric), 'condition');
                condVars = matlab.lang.makeValidName(cellstr(A.params.condition_order));
                if ~all(ismember(condVars, W.Properties.VariableNames)), continue; end

                X = table2array(W(:, condVars));
                keep = all(~isnan(X), 2);
                X = X(keep,:);
                nComplete = size(X,1);

                if nComplete < A.params.min_complete_subjects_for_friedman
                    ri = ri + 1;
                    rows(ri,:) = {pairName, band, metric, nComplete, "skipped_too_few_complete_subjects", NaN}; %#ok<AGROW>
                    continue;
                end

                try
                    pVal = friedman(X, 1, 'off');
                    ri = ri + 1;
                    rows(ri,:) = {pairName, band, metric, nComplete, "friedman_complete_case", pVal}; %#ok<AGROW>
                catch ME
                    ri = ri + 1;
                    rows(ri,:) = {pairName, band, metric, nComplete, "friedman_failed_" + string(ME.identifier), NaN}; %#ok<AGROW>
                end
            end
        end
    end

    R = complete_case_results_table(rows);
end

function R = complete_case_results_table(rows)
    vars = {'pair_name','band','metric','n_complete_subjects','test','p_value'};
    if isempty(rows)
        R = cell2table(cell(0, numel(vars)), 'VariableNames', vars);
    else
        R = cell2table(rows, 'VariableNames', vars);
    end
end

function R = run_pairwise_condition_tests(L, A)
    rows = {};
    ri = 0;

    if isempty(L) || height(L) == 0
        R = pairwise_results_table(rows);
        return;
    end

    pairs = unique(string(L.pair_name), 'stable');
    bands = unique(string(L.band), 'stable');
    metrics = A.params.metrics_to_analyze;
    comparisons = [
        "Flat",   "Medium"
        "Medium", "High"
        "Flat",   "High"
    ];

    for ip = 1:numel(pairs)
        pairName = pairs(ip);
        for ib = 1:numel(bands)
            band = bands(ib);
            for im = 1:numel(metrics)
                metric = metrics(im);
                if ~ismember(metric, string(L.Properties.VariableNames)), continue; end

                pRaw = NaN(size(comparisons,1), 1);
                nPaired = zeros(size(comparisons,1), 1);
                medDiff = NaN(size(comparisons,1), 1);
                status = strings(size(comparisons,1), 1);

                T0 = L(string(L.pair_name) == pairName & string(L.band) == band, :);

                for ic = 1:size(comparisons,1)
                    c1 = comparisons(ic,1);
                    c2 = comparisons(ic,2);

                    [x1, x2] = paired_condition_vectors(T0, metric, c1, c2);
                    nPaired(ic) = numel(x1);

                    if nPaired(ic) < 3
                        status(ic) = "skipped_too_few_pairs";
                        continue;
                    end

                    medDiff(ic) = median(x2 - x1, 'omitnan');

                    try
                        pRaw(ic) = signrank(x1, x2);
                        status(ic) = "signrank_paired";
                    catch ME
                        status(ic) = "signrank_failed_" + string(ME.identifier);
                    end
                end

                pHolm = holm_adjust(pRaw);

                for ic = 1:size(comparisons,1)
                    ri = ri + 1;
                    rows(ri,:) = { pairName, band, metric, comparisons(ic,1), comparisons(ic,2), nPaired(ic), status(ic), pRaw(ic), pHolm(ic), medDiff(ic) }; %#ok<AGROW>
                end
            end
        end
    end

    R = pairwise_results_table(rows);
end

function R = pairwise_results_table(rows)
    vars = {'pair_name','band','metric','condition_1','condition_2', 'n_paired_subjects','test','p_raw','p_holm','median_difference_condition2_minus_condition1'};
    if isempty(rows)
        R = cell2table(cell(0, numel(vars)), 'VariableNames', vars);
    else
        R = cell2table(rows, 'VariableNames', vars);
    end
end

function [x1, x2] = paired_condition_vectors(T, metric, c1, c2)
    T1 = T(string(T.condition) == string(c1) & ~isnan(T.(metric)), {'subject', char(metric)});
    T2 = T(string(T.condition) == string(c2) & ~isnan(T.(metric)), {'subject', char(metric)});

    T1.subject = string(T1.subject);
    T2.subject = string(T2.subject);
    T1.Properties.VariableNames{2} = 'value_1';
    T2.Properties.VariableNames{2} = 'value_2';

    J = innerjoin(T1, T2, 'Keys', 'subject');
    x1 = J.value_1;
    x2 = J.value_2;
end

function pAdj = holm_adjust(pRaw)
    pAdj = NaN(size(pRaw));
    valid = find(~isnan(pRaw));
    if isempty(valid), return; end

    [pSorted, ord] = sort(pRaw(valid), 'ascend');
    m = numel(pSorted);
    adjSorted = NaN(size(pSorted));

    for i = 1:m
        adjSorted(i) = (m - i + 1) * pSorted(i);
    end

    adjSorted = cummax(adjSorted);
    adjSorted = min(adjSorted, 1);
    pAdj(valid(ord)) = adjSorted;
end

function make_condition_plots(T, PairwiseResults, A)
    if isempty(T) || height(T) == 0, return; end

    pairs = unique(string(T.pair_name), 'stable');
    bands = unique(string(T.band), 'stable');
    metrics = A.params.metrics_to_analyze;

    for ip = 1:numel(pairs)
        pairName = pairs(ip);
        for ib = 1:numel(bands)
            band = bands(ib);

            for im = 1:numel(metrics)
                metric = metrics(im);
                if ~ismember(metric, string(T.Properties.VariableNames)), continue; end

                Tplot = T(string(T.pair_name) == pairName & string(T.band) == band & ~isnan(T.(metric)), :);
                if height(Tplot) < 3, continue; end

                Pplot = get_pairwise_rows_for_plot(PairwiseResults, pairName, band, metric);
                fig = plot_condition_metric(Tplot, Pplot, metric, pairName, band, A);

                fileBase = sprintf('%s_%s_%s', sanitize_file_part(pairName), sanitize_file_part(band), sanitize_file_part(metric));
                if pairName == "ACROSS_PAIRS"
                    outSubdir = fullfile(A.io.plots_dir, 'across_pairs');
                else
                    outSubdir = fullfile(A.io.plots_dir, 'by_pair');
                end
                if ~exist(outSubdir, 'dir'), mkdir(outSubdir); end

                if A.plot.save_png
                    exportgraphics(fig, fullfile(outSubdir, [fileBase '.png']), 'Resolution', 300);
                end
                if A.plot.save_pdf
                    exportgraphics(fig, fullfile(outSubdir, [fileBase '.pdf']), 'ContentType', 'vector');
                end
                close(fig);
            end
        end
    end
end

function Pplot = get_pairwise_rows_for_plot(PairwiseResults, pairName, band, metric)
    if isempty(PairwiseResults) || height(PairwiseResults) == 0
        Pplot = table();
        return;
    end

    Pplot = PairwiseResults( string(PairwiseResults.pair_name) == string(pairName) & string(PairwiseResults.band) == string(band) & string(PairwiseResults.metric) == string(metric), :);
end

function fig = plot_condition_metric(T, Pplot, metric, pairName, band, A)
    fig = figure('Color','w', 'Visible', A.plot.visible, 'Position', [100 100 900 620]);
    ax = axes(fig); hold(ax, 'on');

    T.condition = categorical(string(T.condition), A.params.condition_order, 'Ordinal', true);
    x = double(T.condition);
    y = T.(metric);

    boxchart(ax, x, y, 'BoxFaceColor', [0.75 0.75 0.75], 'MarkerStyle', 'none');

    rng(1);
    jitter = (rand(size(x)) - 0.5) * 0.12;
    scatter(ax, x + jitter, y, 34, 'filled', 'MarkerFaceColor', [0.15 0.35 0.70], 'MarkerFaceAlpha', 0.65, 'MarkerEdgeColor', 'none');

    if A.plot.show_subject_lines
        subjects = unique(string(T.subject), 'stable');
        for i = 1:numel(subjects)
            Ts = T(string(T.subject) == subjects(i), :);
            [~, ord] = sort(double(Ts.condition));
            Ts = Ts(ord,:);
            if height(Ts) >= 2
                plot(ax, double(Ts.condition), Ts.(metric), '-', 'Color', [0.70 0.70 0.70], 'LineWidth', 0.7);
            end
        end
    end

    if A.plot.show_pairwise_significance && ~isempty(Pplot) && height(Pplot) > 0
        add_pairwise_significance_annotations(ax, T, Pplot, A);
    end

    xlim(ax, [0.5 numel(A.params.condition_order)+0.5]);
    xticks(ax, 1:numel(A.params.condition_order));
    xticklabels(ax, cellstr(A.params.condition_order));
    grid(ax, 'on');
    box(ax, 'off');

    ylabel(ax, pretty_metric_label(metric), 'Interpreter', 'none');
    title(ax, sprintf('%s | %s | n subjects=%d', pairName, band, numel(unique(string(T.subject)))), 'Interpreter', 'none');
end

function add_pairwise_significance_annotations(ax, T, Pplot, A)
    metric = char(string(Pplot.metric(1)));
    y = T.(metric);
    y = y(~isnan(y));
    if isempty(y), return; end

    yMin = min(y);
    yMax = max(y);
    yRange = yMax - yMin;
    if yRange <= 0 || isnan(yRange)
        yRange = max(abs(yMax), 1);
    end

    sigRows = Pplot(~isnan(Pplot.p_holm) & Pplot.p_holm < A.plot.significance_alpha, :);
    if isempty(sigRows) || height(sigRows) == 0
        return;
    end

    % Draw shorter comparisons first so the widest bracket sits highest.
    x1 = condition_to_x(sigRows.condition_1, A);
    x2 = condition_to_x(sigRows.condition_2, A);
    [~, ord] = sort(abs(x2 - x1), 'ascend');
    sigRows = sigRows(ord,:);
    x1 = x1(ord);
    x2 = x2(ord);

    baseY = yMax + 0.08 * yRange;
    stepY = 0.10 * yRange;
    tickH = 0.025 * yRange;

    for i = 1:height(sigRows)
        yy = baseY + (i-1) * stepY;
        plot(ax, [x1(i) x1(i) x2(i) x2(i)], [yy yy+tickH yy+tickH yy], 'k-', 'LineWidth', 1.0);

        label = p_to_stars(sigRows.p_holm(i));
        text(ax, mean([x1(i), x2(i)]), yy + tickH + 0.01*yRange, label, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontWeight', 'bold', 'FontSize', 11);
    end

    ylim(ax, [yMin - 0.05*yRange, baseY + height(sigRows)*stepY + 0.10*yRange]);
end

function x = condition_to_x(cond, A)
    cond = string(cond);
    x = NaN(size(cond));
    for i = 1:numel(cond)
        idx = find(A.params.condition_order == cond(i), 1);
        if ~isempty(idx)
            x(i) = idx;
        end
    end
end

function label = p_to_stars(p)
    if isnan(p)
        label = "";
    elseif p < 0.001
        label = "***";
    elseif p < 0.01
        label = "**";
    elseif p < 0.05
        label = "*";
    else
        label = "n.s.";
    end
end

function print_analysis_recap(Tcycle, S, L, A)
    fprintf('\n=== Kinematics analysis recap ===\n');
    fprintf('Input cycle rows: %d\n', height(Tcycle));
    fprintf('Signal-level rows after stride metric filter/min cycles: %d\n', height(S));
    fprintf('Leg-averaged rows for main analysis: %d\n', height(L));

    if height(L) > 0
        disp(groupsummary(L, {'pair_name','band','condition'}));
    end
end

function label = pretty_metric_label(metric)
    switch string(metric)
        case "mean_stride_length_m"
            label = "Mean stride length (m)";
        case "cv_stride_length_pct"
            label = "Stride length variability (CV %)";
        case "mean_stride_speed_mps"
            label = "Mean stride speed (m/s)";
        case "cv_stride_speed_pct"
            label = "Stride speed variability (CV %)";
        case "mean_cycle_duration_s"
            label = "Mean cycle duration (s)";
        case "cv_cycle_duration_pct"
            label = "Cycle duration variability (CV %)";
        case "mean_step_length_m"
            label = "Mean step length (m)";
        case "cv_mean_step_length_pct"
            label = "Step length variability (CV %)";
        otherwise
            label = char(metric);
    end
end

function y = nanmean_local(x)
    y = mean(x, 'omitnan');
end

function y = nanstd_local(x)
    y = std(x, 'omitnan');
end

function y = cv_pct_local(x)
    m = mean(x, 'omitnan');
    s = std(x, 'omitnan');
    if isnan(m) || abs(m) < eps
        y = NaN;
    else
        y = 100 * s / abs(m);
    end
end

function out = sanitize_file_part(x)
    out = regexprep(char(string(x)), '[^a-zA-Z0-9_\\-]', '_');
end

function S = ensure_field(S, f, defaultVal)
    if ~isfield(S, f) || isempty(S.(f))
        S.(f) = defaultVal;
    end
end

function val = get_nested_or_default(S, path, defaultVal)
    val = defaultVal;
    cur = S;
    for i = 1:numel(path)
        f = path{i};
        if ~isstruct(cur) || ~isfield(cur, f)
            return;
        end
        cur = cur.(f);
    end
    if ~isempty(cur)
        val = cur;
    end
end
