%% i_temporal_coherence_link.m
% Link time-domain EMG coordination to EMG-EMG coherence.
%
% Core rule:
% Temporal metrics are computed from the EXACT SAME:
%   subject x condition x leg x pair x band x cycle mask x phase window
% as the coherence metric.
%
% This avoids the common mistake:
%   coherence from selected cycles, temporal metrics from all/final cycles.
%
% Outputs:
%   - long row-level table, before leg averaging
%   - subject-level table, after left/right averaging
%   - correlation table
%   - optional LME model reports
%   - scatter plots in same general style as h_coherence_stats
function i_temporal_coherence_link()

    %% ===================== SETUP =====================

    C = config_emg();
    TC = C.temporal_coherence_link;

    make_dir(TC.out_dir);
    make_dir(TC.tables_dir);
    make_dir(TC.models_dir);
    make_dir(TC.plots_dir);

    fprintf('\n=== Running temporal x coherence analysis ===\n');
    fprintf('Metric scope     : %s\n', string(TC.metric_scope));
    fprintf('Coherence source : %s\n', string(TC.coherence_source));

    %% ===================== LOAD COHERENCE RESULTS =====================

    COH = load_coherence_sources(TC);

    %% ===================== BUILD LONG ROW-LEVEL TABLE =====================

    fprintf('\nBuilding long temporal-coherence table...\n');

    ROW = {};
    ri = 0;

    subjects = get_union_subjects(COH);

    for iS = 1:numel(subjects)

        subjID = subjects{iS};
        age_group = subject_to_group(subjID, C);

        conds = union_of_nested_fields(struct_values(COH), {subjID});

        for ic = 1:numel(conds)

            cond = conds{ic};
            legs = union_of_nested_fields(struct_values(COH), {subjID, cond});

            for il = 1:numel(legs)

                leg = legs{il};
                pairNames = union_of_nested_fields(struct_values(COH), {subjID, cond, leg});

                for ip = 1:numel(pairNames)

                    pairName = pairNames{ip};

                    if ~ismember(string(pairName), string(TC.pairs_to_analyze))
                        continue;
                    end

                    for ib = 1:numel(TC.bands_to_analyze)

                        bandName = string(TC.bands_to_analyze{ib});
                        R = get_result_for_band(COH, bandName, subjID, cond, leg, pairName);

                        if isempty(R)
                            continue;
                        end

                        % ---------- Validate cycle count ----------
                        [cycleMask, cycleMaskName] = get_cycle_mask_for_source(R, TC.coherence_source);

                        if isempty(cycleMask) || sum(cycleMask) < TC.min_cycles_required
                            continue;
                        end

                        nCyclesUsedForThisRow = sum(cycleMask);

                        % ---------- Coherence metrics ----------
                        coh_mean = get_scalar_from_result( R, char(bandName), TC.metric_scope, TC.coherence_source, 'mean');

                        coh_auc_norm = get_scalar_from_result( R, char(bandName), TC.metric_scope, TC.coherence_source, 'auc_norm');

                        coh_peak = get_scalar_from_result( R, char(bandName), TC.metric_scope, TC.coherence_source, 'peak');

                        if isnan(coh_mean) && isnan(coh_auc_norm) && isnan(coh_peak)
                            continue;
                        end

                        % ---------- Temporal metrics from exact same cycles ----------
                        TM = compute_temporal_metrics_from_same_cycles(R, cycleMask, TC);

                        if ~TM.ok
                            continue;
                        end

                        ri = ri + 1;

                        ROW(ri,:) = { string(subjID), string(age_group), string(cond), string(leg), string(pairName), string(bandName), string(TC.metric_scope), string(TC.coherence_source), string(cycleMaskName), nCyclesUsedForThisRow, coh_mean, coh_auc_norm, coh_peak, TM.temporal_corr, TM.coactivation_iou, TM.coactivation_minmax, TM.peak_lag_pct, abs(TM.peak_lag_pct), TM.peak1_pct, TM.peak2_pct, TM.mean_amp_1, TM.mean_amp_2, TM.mean_amp_pair, TM.n_cycles_temporal };
                    end
                end
            end
        end
    end

    if isempty(ROW)
        error(['No rows could be built. Most likely causes:\n' '1) final_concatenated_signal_1/2 were not stored in COHERENCE_RESULTS,\n' '2) analysis_cycle_mask is missing,\n' '3) metric_scope / coherence_source mismatch,\n' '4) the selected coherence files are not the expected ones.']);
    end

    T_row = cell2table(ROW, 'VariableNames', { 'subject','age_group','condition','leg','pair_name','band', 'metric_scope','coherence_source','cycle_mask_source', 'n_cycles_used', 'coherence_mean','coherence_auc_norm','coherence_peak', 'temporal_corr','coactivation_iou','coactivation_minmax', 'peak_lag_pct','abs_peak_lag_pct','peak1_pct','peak2_pct', 'mean_amp_1','mean_amp_2','mean_amp_pair', 'n_cycles_temporal'});

    %% ===================== CLEAN CATEGORICALS =====================

    T_row.subject   = categorical(string(T_row.subject));
    T_row.age_group = categorical(string(T_row.age_group), C.plotting.age_order, C.plotting.age_order, 'Ordinal', true);
    T_row.condition = categorical(string(T_row.condition), C.plotting.condition_order, C.plotting.condition_order, 'Ordinal', true);
    T_row.leg       = categorical(string(T_row.leg), C.design.legs, C.design.legs, 'Ordinal', true);
    T_row.pair_name = categorical(string(T_row.pair_name), TC.pairs_to_analyze, TC.pairs_to_analyze, 'Ordinal', true);
    T_row.band      = categorical(string(T_row.band), TC.bands_to_analyze, TC.bands_to_analyze, 'Ordinal', true);

    T_row = T_row(~isundefined(T_row.age_group) & ~isundefined(T_row.condition) & ~isundefined(T_row.pair_name) & ~isundefined(T_row.band), :);

    fprintf('Row-level table: %d rows\n', height(T_row));

    writetable(T_row, fullfile(TC.tables_dir, 'T_temporal_coherence_row_LONG.csv'));

    %% ===================== SANITY CHECK TABLE =====================

    fprintf('\nBuilding alignment sanity-check table...\n');

    T_alignment = groupcounts_table(T_row, {'pair_name','band','age_group','condition'});
    writetable(T_alignment, fullfile(TC.tables_dir, 'TEMPORAL_COHERENCE_ALIGNMENT_RECAP.csv'));

    disp(T_alignment);

    %% ===================== AVERAGE LEFT / RIGHT LEGS =====================

    fprintf('\nAveraging left/right legs within subject x age_group x condition x pair x band...\n');

    groupVars = {'subject','age_group','condition','pair_name','band'};

    numericVars = { 'n_cycles_used', 'coherence_mean','coherence_auc_norm','coherence_peak', 'temporal_corr','coactivation_iou','coactivation_minmax', 'peak_lag_pct','abs_peak_lag_pct','peak1_pct','peak2_pct', 'mean_amp_1','mean_amp_2','mean_amp_pair', 'n_cycles_temporal'};

    G = findgroups(T_row(:, groupVars));
    T_subj = unique(T_row(:, groupVars), 'rows');

    for i = 1:numel(numericVars)
        v = numericVars{i};
        T_subj.(v) = splitapply(@(x) mean(x, 'omitnan'), T_row.(v), G);
    end

    T_subj.n_legs_collapsed = splitapply(@numel, T_row.leg, G);
    T_subj.metric_scope = repmat(string(TC.metric_scope), height(T_subj), 1);
    T_subj.coherence_source = repmat(string(TC.coherence_source), height(T_subj), 1);

    fprintf('Subject-level table: %d rows\n', height(T_subj));

    writetable(T_subj, fullfile(TC.tables_dir, 'T_temporal_coherence_subject_LONG.csv'));

    %% ===================== CORRELATIONS =====================

    if TC.run_correlations

        fprintf('\nRunning temporal-coherence correlations...\n');

        CORR_ROWS = {};
        riC = 0;

        for ip = 1:numel(TC.pairs_to_analyze)

            pairName = string(TC.pairs_to_analyze{ip});

            for ib = 1:numel(TC.bands_to_analyze)

                bandName = string(TC.bands_to_analyze{ib});

                Tp = T_subj(T_subj.pair_name == pairName & T_subj.band == bandName, :);

                if isempty(Tp)
                    continue;
                end

                for idv = 1:numel(TC.coherence_metrics)

                    dv = TC.coherence_metrics{idv};

                    if ~ismember(dv, Tp.Properties.VariableNames)
                        continue;
                    end

                    for ipred = 1:numel(TC.temporal_predictors)

                        pred = TC.temporal_predictors{ipred};

                        if ~ismember(pred, Tp.Properties.VariableNames)
                            continue;
                        end

                        Tm = Tp(isfinite(Tp.(dv)) & isfinite(Tp.(pred)), :);

                        if height(Tm) < 8
                            continue;
                        end

                        [rP, pP] = corr(Tm.(pred), Tm.(dv), 'Type', 'Pearson', 'Rows', 'complete');

                        [rS, pS] = corr(Tm.(pred), Tm.(dv), 'Type', 'Spearman', 'Rows', 'complete');

                        riC = riC + 1;
                        CORR_ROWS(riC,:) = { pairName, bandName, string(dv), string(pred), height(Tm), numel(unique(Tm.subject)), rP, pP, rS, pS };
                    end
                end
            end
        end

        if ~isempty(CORR_ROWS)
            T_corr = cell2table(CORR_ROWS, 'VariableNames', { 'pair_name','band','coherence_metric','temporal_predictor', 'n_rows','n_subjects', 'r_pearson','p_pearson','rho_spearman','p_spearman'});

            writetable(T_corr, fullfile(TC.tables_dir, 'TEMPORAL_COHERENCE_CORRELATIONS.csv'));
            disp(T_corr);
        else
            T_corr = table();
            warning('No temporal-coherence correlations computed.');
        end
    end

    %% ===================== LME MODELS =====================

    if TC.run_lme

        fprintf('\nRunning temporal-control LME models...\n');

        MODEL_ROWS = {};
        riM = 0;

        for ip = 1:numel(TC.pairs_to_analyze)

            pairName = string(TC.pairs_to_analyze{ip});

            for ib = 1:numel(TC.bands_to_analyze)

                bandName = string(TC.bands_to_analyze{ib});

                Tp = T_subj(T_subj.pair_name == pairName & T_subj.band == bandName, :);

                if isempty(Tp)
                    continue;
                end

                Tp.subject   = removecats(Tp.subject);
                Tp.age_group = removecats(Tp.age_group);
                Tp.condition = removecats(Tp.condition);

                % Professor choice:
                % Do not throw all temporal metrics together at first.
                % Run one temporal predictor at a time, always controlling for amplitude.
                mainTemporalPredictors = {'temporal_corr','coactivation_iou','abs_peak_lag_pct'};

                for idv = 1:numel(TC.coherence_metrics)

                    dv = TC.coherence_metrics{idv};

                    if ~ismember(dv, Tp.Properties.VariableNames)
                        continue;
                    end

                    for ipred = 1:numel(mainTemporalPredictors)

                        pred = mainTemporalPredictors{ipred};
                        ampVar = 'mean_amp_pair';

                        needed = {dv, pred, ampVar};

                        if ~all(ismember(needed, Tp.Properties.VariableNames))
                            continue;
                        end

                        Tm = Tp(isfinite(Tp.(dv)) & isfinite(Tp.(pred)) & isfinite(Tp.(ampVar)), :);

                        if height(Tm) < 15 || numel(unique(Tm.subject)) < 8
                            continue;
                        end

                        predZ = sprintf('%s_z', pred);
                        ampZ  = sprintf('%s_z', ampVar);

                        Tm.(predZ) = zscore_safe(Tm.(pred));
                        Tm.(ampZ)  = zscore_safe(Tm.(ampVar));

                        formula = sprintf('%s ~ age_group * condition + %s + %s + (1|subject)', dv, predZ, ampZ);

                        outTxt = fullfile(TC.models_dir, sprintf('MODEL_TEMPORAL_LINK__%s__%s__%s__%s.txt', char(pairName), char(bandName), dv, pred));

                        write_lme_report(Tm, dv, formula, outTxt);


                        riM = riM + 1;
                        MODEL_ROWS(riM,:) = { pairName, bandName, string(dv), string(pred), height(Tm), numel(unique(Tm.subject)), string(formula), string(outTxt) };
                    end
                end
            end
        end

        if ~isempty(MODEL_ROWS)

            T_models = cell2table(MODEL_ROWS, 'VariableNames', { 'pair_name','band','coherence_metric','temporal_predictor', 'n_rows','n_subjects','formula','model_file'});

            writetable(T_models, fullfile(TC.tables_dir, 'TEMPORAL_LME_MODEL_INDEX.csv'));
            disp(T_models);
        else
            warning('No LME temporal-link models were run.');
        end
    end

    %% ===================== BASE VS TEMPORAL-CONTROL OMNIBUS COMPARISON =====================

    if isfield(TC, 'run_omnibus_control_comparison') && TC.run_omnibus_control_comparison

        fprintf('\nRunning base vs temporal-control omnibus comparison...\n');

        if isfield(TC, 'omnibus_coherence_metrics')
            omnibusDVs = TC.omnibus_coherence_metrics;
        else
            omnibusDVs = {'coherence_mean','coherence_auc_norm'};
        end

        if isfield(TC, 'omnibus_temporal_predictors')
            omnibusPreds = TC.omnibus_temporal_predictors;
        else
            omnibusPreds = {'temporal_corr','coactivation_iou','abs_peak_lag_pct'};
        end

        OMNI_CTRL_ROWS = {};
        riOC = 0;

        for ip = 1:numel(TC.pairs_to_analyze)

            pairName = string(TC.pairs_to_analyze{ip});

            for ib = 1:numel(TC.bands_to_analyze)

                bandName = string(TC.bands_to_analyze{ib});

                Tp = T_subj(T_subj.pair_name == pairName & T_subj.band == bandName, :);

                if isempty(Tp)
                    continue;
                end

                Tp.subject   = removecats(Tp.subject);
                Tp.age_group = removecats(Tp.age_group);
                Tp.condition = removecats(Tp.condition);

                for idv = 1:numel(omnibusDVs)

                    dv = omnibusDVs{idv};

                    if ~ismember(dv, Tp.Properties.VariableNames)
                        continue;
                    end

                    for ipred = 1:numel(omnibusPreds)

                        pred = omnibusPreds{ipred};
                        ampVar = 'mean_amp_pair';

                        neededVars = {dv, pred, ampVar};

                        if ~all(ismember(neededVars, Tp.Properties.VariableNames))
                            continue;
                        end

                        Tm = Tp(isfinite(Tp.(dv)) & isfinite(Tp.(pred)) & isfinite(Tp.(ampVar)), :);

                        if height(Tm) < 15 || numel(unique(Tm.subject)) < 8
                            continue;
                        end

                        predZ = sprintf('%s_z', pred);
                        ampZ  = sprintf('%s_z', ampVar);

                        Tm.(predZ) = zscore_safe(Tm.(pred));
                        Tm.(ampZ)  = zscore_safe(Tm.(ampVar));

                        % ---------- Base model ----------
                        baseFormula = sprintf('%s ~ age_group * condition + (1|subject)', dv);

                        % ---------- Controlled model ----------
                        ctrlFormula = sprintf('%s ~ age_group * condition + %s + %s + (1|subject)', dv, predZ, ampZ);

                        base = fit_lme_extract_terms(Tm, baseFormula, {'age_group','condition','age_group:condition'});

                        ctrl = fit_lme_extract_terms(Tm, ctrlFormula, {'age_group','condition','age_group:condition', predZ, ampZ});

                        riOC = riOC + 1;

                        OMNI_CTRL_ROWS(riOC,:) = { pairName, bandName, string(dv), string(pred), height(Tm), numel(unique(Tm.subject)), string(baseFormula), string(ctrlFormula), base.model_ok, ctrl.model_ok, base.p_age_group, base.p_condition, base.p_interaction, ctrl.p_age_group, ctrl.p_condition, ctrl.p_interaction, ctrl.p_temporal, ctrl.p_amplitude, p_to_sig_label(base.p_age_group), p_to_sig_label(base.p_condition), p_to_sig_label(base.p_interaction), p_to_sig_label(ctrl.p_age_group), p_to_sig_label(ctrl.p_condition), p_to_sig_label(ctrl.p_interaction), p_to_sig_label(ctrl.p_temporal), p_to_sig_label(ctrl.p_amplitude) };
                    end
                end
            end
        end

        if ~isempty(OMNI_CTRL_ROWS)

            TEMPORAL_CONTROL_OMNIBUS_TABLE = cell2table(OMNI_CTRL_ROWS, 'VariableNames', { 'pair_name','band','coherence_metric','temporal_predictor', 'n_rows','n_subjects', 'base_formula','controlled_formula', 'base_model_ok','controlled_model_ok', 'p_age_base','p_condition_base','p_interaction_base', 'p_age_controlled','p_condition_controlled','p_interaction_controlled', 'p_temporal_predictor','p_amplitude', 'sig_age_base','sig_condition_base','sig_interaction_base', 'sig_age_controlled','sig_condition_controlled','sig_interaction_controlled', 'sig_temporal_predictor','sig_amplitude'});

            outCsv = fullfile(TC.tables_dir, 'TEMPORAL_CONTROL_OMNIBUS_COMPARISON.csv');
            writetable(TEMPORAL_CONTROL_OMNIBUS_TABLE, outCsv);

            fprintf('\nSaved temporal-control omnibus comparison:\n%s\n', outCsv);
            disp(TEMPORAL_CONTROL_OMNIBUS_TABLE);

        else
            warning('No temporal-control omnibus comparison rows were produced.');
        end
    end

    %% ===================== PLOTS =====================

    if TC.make_plots && exist('T_corr', 'var') && ~isempty(T_corr)

        fprintf('\nGenerating temporal-coherence scatter plots...\n');

        nPlots = min(height(T_corr), TC.max_scatter_plots);

        for i = 1:nPlots

            pairName = string(T_corr.pair_name(i));
            bandName = string(T_corr.band(i));
            dv       = string(T_corr.coherence_metric(i));
            pred     = string(T_corr.temporal_predictor(i));

            Tp = T_subj(T_subj.pair_name == pairName & T_subj.band == bandName, :);

            if ~ismember(char(dv), Tp.Properties.VariableNames) || ~ismember(char(pred), Tp.Properties.VariableNames)
                continue;
            end

            Tm = Tp(isfinite(Tp.(char(dv))) & isfinite(Tp.(char(pred))), :);

            if height(Tm) < 8
                continue;
            end

            fig = figure('Visible', TC.visible, 'Color', 'w', 'Position', [100 100 680 540]);

            hold on;

            switch lower(string(TC.plot_by))

                case "age_group"
                    groupVar = 'age_group';
                    groupLevels = cellstr(C.plotting.age_order);
                    colorFcn = @(x) get_age_color(x, C);
                    legendTitle = 'Age group';

                otherwise
                    groupVar = 'condition';
                    groupLevels = cellstr(C.plotting.condition_order);
                    colorFcn = @(x) get_condition_color(x, C);
                    legendTitle = 'Condition';
            end

            for ig = 1:numel(groupLevels)

                gname = groupLevels{ig};
                idx = Tm.(groupVar) == gname;

                if ~any(idx)
                    continue;
                end

                col = colorFcn(gname);

                scatter(Tm.(char(pred))(idx), Tm.(char(dv))(idx), 52, 'filled', 'MarkerFaceColor', col, 'MarkerEdgeColor', col, 'DisplayName', gname);
            end

            mdl = fitlm(Tm.(char(pred)), Tm.(char(dv)));

            xfit = linspace(min(Tm.(char(pred))), max(Tm.(char(pred))), 100)';
            yfit = predict(mdl, xfit);

            plot(xfit, yfit, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');

            xlabel(label_from_var(pred));
            ylabel(label_from_var(dv));

            title(sprintf('%s | %s | %s vs %s', pairName, bandName, dv, pred), 'Interpreter', 'none');

            txt = sprintf('r = %.2f, p = %.3g, n = %d', T_corr.r_pearson(i), T_corr.p_pearson(i), T_corr.n_rows(i));

            text(0.05, 0.95, txt, 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 11, 'FontWeight', 'bold', 'BackgroundColor', 'w', 'Margin', 3);

            if isfield(TC, 'use_fixed_coherence_ylim') && TC.use_fixed_coherence_ylim && isfield(TC, 'coherence_ylim') && numel(TC.coherence_ylim) == 2
                ylim(TC.coherence_ylim);
            end

            grid on;
            box on;

            lgd = legend('Location', 'southoutside', 'Orientation', 'horizontal', 'Interpreter', 'none');

            lgd.Box = 'off';
            title(lgd, legendTitle);

            outName = sprintf('TEMPORAL_LINK__%s__%s__%s__%s.png', char(pairName), char(bandName), char(dv), char(pred));

            outName = regexprep(outName, '[^\w\.-]', '_');

            saveas(fig, fullfile(TC.plots_dir, outName));
            close(fig);
        end
    end

    %% ===================== SAVE WORKSPACE =====================

    save(fullfile(TC.out_dir, 'TEMPORAL_COHERENCE_LINK_WORKSPACE.mat'), 'T_row', 'T_subj', 'TC', '-v7.3');

    fprintf('\nDone.\nResults saved in:\n%s\n', TC.out_dir);
end

%% ========================================================================
%% LOCAL FUNCTIONS
%% ========================================================================

function make_dir(d)
    if ~exist(d, 'dir')
        mkdir(d);
    end
end

function COH = load_coherence_sources(TC)

    COH = struct();

    assert(isfile(TC.coh_mat_default), 'Default coherence file not found:\n%s', TC.coh_mat_default);

    L = load(TC.coh_mat_default);
    assert(isfield(L, 'COHERENCE_RESULTS'), 'COHERENCE_RESULTS missing from:\n%s', TC.coh_mat_default);

    COH.default = L.COHERENCE_RESULTS;
    % One results file per analysed band (TC.coh_mat_band.<Band>); FULL is the fallback
    for bandName = string(TC.bands_to_analyze)
        COH.(bandName) = COH.default;
        if TC.use_band_specific_datasets && isfield(TC, 'coh_mat_band') && isfield(TC.coh_mat_band, bandName) && isfile(TC.coh_mat_band.(bandName))
            Lband = load(TC.coh_mat_band.(bandName));
            if isfield(Lband, 'COHERENCE_RESULTS')
                COH.(bandName) = Lband.COHERENCE_RESULTS;
            end
        end
    end
end

function vals = struct_values(S)
    fn = fieldnames(S);
    vals = cell(numel(fn),1);
    for i = 1:numel(fn)
        vals{i} = S.(fn{i});
    end
end

function subjects = get_union_subjects(COH)
    vals = struct_values(COH);
    subjects = {};
    for i = 1:numel(vals)
        if isstruct(vals{i})
            subjects = union(subjects, fieldnames(vals{i}));
        end
    end
end

function R = get_result_for_band(COH, bandName, subjID, cond, leg, pairName)

    R = [];

    bandName = char(string(bandName));

    if isfield(COH, bandName)
        R = get_nested_result(COH.(bandName), subjID, cond, leg, pairName);
    end

    if isempty(R)
        R = get_nested_result(COH.default, subjID, cond, leg, pairName);
    end
end

function [cycleMask, maskName] = get_cycle_mask_for_source(R, coherenceSource)

    cycleMask = [];
    maskName = "";

    src = lower(string(coherenceSource));

    switch src

        case "sig_equalized"
            if isfield(R, 'analysis_cycle_mask_equalized') && ~isempty(R.analysis_cycle_mask_equalized)
                cycleMask = logical(R.analysis_cycle_mask_equalized(:));
                maskName = "analysis_cycle_mask_equalized";
            end

        otherwise
            if isfield(R, 'analysis_cycle_mask') && ~isempty(R.analysis_cycle_mask)
                cycleMask = logical(R.analysis_cycle_mask(:));
                maskName = "analysis_cycle_mask";
            end
    end
end

function TM = compute_temporal_metrics_from_same_cycles(R, cycleMask, TC)

    TM = empty_temporal_metrics();

    if isempty(R) || isempty(cycleMask)
        return;
    end

    requiredFields = { 'final_concatenated_signal_1', 'final_concatenated_signal_2', 'final_cycle_segments_table', 'fs'};

    for i = 1:numel(requiredFields)
        f = requiredFields{i};
        if ~isfield(R, f) || isempty(R.(f))
            warning('Missing %s for %s | %s | %s | %s. Re-run coherence with signal storage enabled.', f, string(R.subject), string(R.condition), string(R.leg), string(R.pair_name));
            return;
        end
    end

    x1 = R.final_concatenated_signal_1(:);
    x2 = R.final_concatenated_signal_2(:);
    fs = R.fs;
    Tseg = R.final_cycle_segments_table;

    if height(Tseg) ~= numel(cycleMask)
        warning('Cycle mask length does not match Tseg height for %s | %s | %s | %s.', string(R.subject), string(R.condition), string(R.leg), string(R.pair_name));
        return;
    end

    % ---------- Extract selected cycles and interpolate to same 0-100% grid ----------
    [X1raw, ok1] = extract_interpolated_cycles_from_signal(x1, Tseg, cycleMask, 1, TC.n_interp_time);
    [X2raw, ok2] = extract_interpolated_cycles_from_signal(x2, Tseg, cycleMask, 2, TC.n_interp_time);

    if ~ok1 || ~ok2 || isempty(X1raw) || isempty(X2raw)
        return;
    end

    if size(X1raw,1) ~= size(X2raw,1)
        return;
    end

    % ---------- Convert to temporal envelope ----------
    X1env = make_envelope_matrix(X1raw, fs, TC);
    X2env = make_envelope_matrix(X2raw, fs, TC);

    % ---------- Restrict to same phase/scope used for coherence scalar ----------
    timeIdx = get_time_indices_for_scope(R, TC.metric_scope, size(X1env,2));

    timeIdx = timeIdx(timeIdx >= 1 & timeIdx <= size(X1env,2));

    if isempty(timeIdx)
        return;
    end

    X1p = X1env(:, timeIdx);
    X2p = X2env(:, timeIdx);

    timePct = linspace(0, 100, size(X1env,2));
    timePctP = timePct(timeIdx);

    nCycles = size(X1p,1);

    temporalCorrVals = nan(nCycles,1);
    iouVals          = nan(nCycles,1);
    minmaxVals       = nan(nCycles,1);
    peakLagVals      = nan(nCycles,1);
    peak1Vals        = nan(nCycles,1);
    peak2Vals        = nan(nCycles,1);
    amp1Vals         = nan(nCycles,1);
    amp2Vals         = nan(nCycles,1);

    for i = 1:nCycles

        x = X1p(i,:);
        y = X2p(i,:);

        valid = isfinite(x) & isfinite(y);

        if sum(valid) < 5
            continue;
        end

        x = x(valid);
        y = y(valid);
        tp = timePctP(valid);

        amp1Vals(i) = mean(x, 'omitnan');
        amp2Vals(i) = mean(y, 'omitnan');

        % Shape-normalized versions for correlation, overlap, peak timing.
        [xs, ys] = normalize_pair_cycle_for_shape(x, y, TC);

        if std(xs) > 0 && std(ys) > 0
            temporalCorrVals(i) = corr(xs(:), ys(:), 'Rows', 'complete');
        end

        denom = sum(max(xs, ys), 'omitnan');
        if denom > 0
            minmaxVals(i) = sum(min(xs, ys), 'omitnan') / denom;
        end

        thr = TC.active_threshold_frac;
        bx = xs >= thr;
        by = ys >= thr;

        unionN = sum(bx | by);
        if unionN > 0
            iouVals(i) = sum(bx & by) / unionN;
        end

        [~, ix] = max(xs);
        [~, iy] = max(ys);

        peak1Vals(i) = tp(ix);
        peak2Vals(i) = tp(iy);
        peakLagVals(i) = tp(iy) - tp(ix);
    end

    TM.ok = true;
    TM.n_cycles_temporal = nCycles;

    TM.temporal_corr = mean(temporalCorrVals, 'omitnan');
    TM.coactivation_iou = mean(iouVals, 'omitnan');
    TM.coactivation_minmax = mean(minmaxVals, 'omitnan');

    TM.peak_lag_pct = circular_mean_lag_pct(peakLagVals);
    TM.peak1_pct = mean(peak1Vals, 'omitnan');
    TM.peak2_pct = mean(peak2Vals, 'omitnan');

    TM.mean_amp_1 = mean(amp1Vals, 'omitnan');
    TM.mean_amp_2 = mean(amp2Vals, 'omitnan');
    TM.mean_amp_pair = mean([TM.mean_amp_1, TM.mean_amp_2], 'omitnan');
end

function TM = empty_temporal_metrics()
    TM = struct();
    TM.ok = false;
    TM.n_cycles_temporal = NaN;
    TM.temporal_corr = NaN;
    TM.coactivation_iou = NaN;
    TM.coactivation_minmax = NaN;
    TM.peak_lag_pct = NaN;
    TM.peak1_pct = NaN;
    TM.peak2_pct = NaN;
    TM.mean_amp_1 = NaN;
    TM.mean_amp_2 = NaN;
    TM.mean_amp_pair = NaN;
end

function [X, ok] = extract_interpolated_cycles_from_signal(x, Tseg, cycleMask, whichSignal, nInterp)

    X = [];
    ok = false;

    x = x(:);

    if whichSignal == 1
        startField = 'final_concat_start_idx_signal1';
        endField   = 'final_concat_end_idx_signal1';
    else
        startField = 'final_concat_start_idx_signal2';
        endField   = 'final_concat_end_idx_signal2';
    end

    if ~ismember(startField, Tseg.Properties.VariableNames) || ~ismember(endField, Tseg.Properties.VariableNames)
        warning('Tseg missing %s / %s.', startField, endField);
        return;
    end

    idxCycles = find(cycleMask(:));

    if isempty(idxCycles)
        return;
    end

    X = nan(numel(idxCycles), nInterp);

    for ii = 1:numel(idxCycles)

        c = idxCycles(ii);

        s = Tseg.(startField)(c);
        e = Tseg.(endField)(c);

        if ~isfinite(s) || ~isfinite(e) || s < 1 || e > numel(x) || e <= s
            continue;
        end

        seg = double(x(s:e));

        if numel(seg) < 5
            continue;
        end

        oldGrid = linspace(0, 1, numel(seg));
        newGrid = linspace(0, 1, nInterp);

        X(ii,:) = interp1(oldGrid, seg(:)', newGrid, 'linear', NaN);
    end

    keep = ~all(isnan(X), 2);
    X = X(keep,:);

    ok = ~isempty(X);
end

function Xenv = make_envelope_matrix(Xraw, fs, TC)

    Xenv = abs(double(Xraw));

    fc = TC.envelope_lowpass_hz;

    if isempty(fc) || isnan(fc) || fc <= 0
        return;
    end

    try
        [b, a] = butter(TC.envelope_lowpass_order, fc/(fs/2), 'low');

        for i = 1:size(Xenv,1)
            x = Xenv(i,:);

            if sum(isfinite(x)) < 10
                continue;
            end

            x = fillmissing(x, 'linear', 'EndValues', 'nearest');

            if numel(x) > 3 * max(numel(a), numel(b))
                Xenv(i,:) = filtfilt(b, a, x);
            else
                Xenv(i,:) = smoothdata(x, 'movmean', 25);
            end
        end

    catch ME
        warning('Envelope low-pass failed, using smoothdata fallback: %s', ME.message);

        for i = 1:size(Xenv,1)
            Xenv(i,:) = smoothdata(Xenv(i,:), 'movmean', 25);
        end
    end

    Xenv(Xenv < 0) = 0;
end

function [xs, ys] = normalize_pair_cycle_for_shape(x, y, TC)

    xs = double(x(:)');
    ys = double(y(:)');

    if isfield(TC, 'normalize_each_cycle_for_shape') && TC.normalize_each_cycle_for_shape

        denom = max([xs(:); ys(:)], [], 'omitnan');

        if isfinite(denom) && denom > 0
            xs = xs ./ denom;
            ys = ys ./ denom;
        end
    end
end

function lag = circular_mean_lag_pct(lagVals)

    lagVals = lagVals(:);
    lagVals = lagVals(isfinite(lagVals));

    if isempty(lagVals)
        lag = NaN;
        return;
    end

    % Keep simple because POI windows are not full circular phase estimates.
    % Wrap only extreme lags to avoid artificial +/-100% jumps.
    lagVals(lagVals > 50) = lagVals(lagVals > 50) - 100;
    lagVals(lagVals < -50) = lagVals(lagVals < -50) + 100;

    lag = mean(lagVals, 'omitnan');
end

function idx = get_time_indices_for_scope(R, metricScope, nTime)

    scope = lower(string(metricScope));
    idx = [];

    switch scope

        case "poi"
            if result_has_poi(R)
                idx = R.POI.indices(:)';
            end

        case "stance"
            if isfield(R, 'StanceIndices') && ~isempty(R.StanceIndices)
                idx = R.StanceIndices(:)';
            end

        case "swing"
            if isfield(R, 'SwingIndices') && ~isempty(R.SwingIndices)
                idx = R.SwingIndices(:)';
            end

        case "full"
            idx = 1:nTime;

        otherwise
            idx = 1:nTime;
    end

    idx = idx(:)';
end

function val = get_scalar_from_result(R, bandName, metricScope, coherenceSource, metricType)

    val = NaN;

    try
        metricScope = lower(char(string(metricScope)));
        coherenceSource = lower(char(string(coherenceSource)));
        bandName = char(string(bandName));
        metricType = lower(char(string(metricType)));

        if ~isfield(R, 'Metrics')
            return;
        end

        if ~isfield(R.Metrics, coherenceSource)
            return;
        end

        if ~isfield(R.Metrics.(coherenceSource), metricScope)
            return;
        end

        M = R.Metrics.(coherenceSource).(metricScope);

        switch metricType

            case "mean"
                if isfield(M, 'mean') && isfield(M.mean, bandName)
                    val = M.mean.(bandName);
                end

            case "auc_norm"
                if isfield(M, 'auc_norm') && isfield(M.auc_norm, bandName)
                    val = M.auc_norm.(bandName);
                end

            case "peak"
                if isfield(M, 'peak') && isfield(M.peak, bandName)
                    val = M.peak.(bandName);
                end
        end

    catch
        val = NaN;
    end
end
function age_group = subject_to_group(subjID, C)

    age_group = "Unknown";

    if isfield(C, 'groups') && isa(C.groups, 'containers.Map')
        if isKey(C.groups, char(subjID))
            age_group = string(C.groups(char(subjID)));
        end
    end
end
function z = zscore_safe(x)

    z = x;

    if all(~isfinite(x))
        z(:) = NaN;
        return;
    end

    mu = mean(x, 'omitnan');
    sd = std(x, 0, 'omitnan');

    if ~isfinite(sd) || sd == 0
        z = x - mu;
    else
        z = (x - mu) ./ sd;
    end
end

function txt = label_from_var(v)

    v = string(v);

    switch v
        case "coherence_mean"
            txt = "Mean coherence";
        case "coherence_auc_norm"
            txt = "Normalized coherence AUC";
        case "coherence_peak"
            txt = "Peak coherence";
        case "temporal_corr"
            txt = "Envelope correlation";
        case "coactivation_iou"
            txt = "Coactivation overlap (IoU)";
        case "coactivation_minmax"
            txt = "Coactivation overlap (min/max)";
        case "peak_lag_pct"
            txt = "Peak lag (% gait cycle)";
        case "abs_peak_lag_pct"
            txt = "Absolute peak lag (% gait cycle)";
        case "mean_amp_pair"
            txt = "Mean envelope amplitude";
        otherwise
            txt = strrep(char(v), '_', ' ');
    end
end

function T = groupcounts_table(Tin, groupVars)

    if isempty(Tin)
        T = table();
        return;
    end

    G = findgroups(Tin(:, groupVars));
    T = unique(Tin(:, groupVars), 'rows');
    T.n_rows = splitapply(@numel, Tin.subject, G);
    T.n_subjects = splitapply(@(x) numel(unique(x)), Tin.subject, G);
end

function write_lme_report(T, dvName, formula, outTxt)

    fid = fopen(outTxt, 'w');

    if fid == -1
        warning('Could not open model report file:\n%s', outTxt);
        return;
    end

    fprintf(fid, 'Dependent variable: %s\n', dvName);
    fprintf(fid, 'Formula: %s\n\n', formula);
    fprintf(fid, 'N rows: %d\n', height(T));
    fprintf(fid, 'N subjects: %d\n\n', numel(unique(T.subject)));

    try
        lme = fitlme(T, formula);

        fprintf(fid, '===== MODEL SUMMARY =====\n');
        fprintf(fid, '%s\n\n', evalc('disp(lme)'));

        fprintf(fid, '===== FIXED EFFECTS =====\n');
        fprintf(fid, '%s\n\n', evalc('disp(lme.Coefficients)'));

        fprintf(fid, '===== ANOVA =====\n');
        fprintf(fid, '%s\n\n', evalc('disp(anova(lme))'));

    catch ME
        fprintf(fid, 'Model failed.\n');
        fprintf(fid, '%s\n', ME.message);
    end

    fclose(fid);
end

function S = fit_lme_extract_terms(T, formula, requestedTerms)

    S = struct();

    S.p_age_group   = NaN;
    S.p_condition   = NaN;
    S.p_interaction = NaN;
    S.p_temporal    = NaN;
    S.p_amplitude   = NaN;
    S.model_ok      = false;

    try
        lme = fitlme(T, formula);

        % Use ANOVA for term-level / omnibus effects
        A = anova(lme);

        S.model_ok = true;

        for i = 1:numel(requestedTerms)

            term = requestedTerms{i};
            p = get_p_from_anova_table(A, term);

            switch string(term)

                case "age_group"
                    S.p_age_group = p;

                case "condition"
                    S.p_condition = p;

                case "age_group:condition"
                    S.p_interaction = p;

                otherwise
                    if contains(string(term), "mean_amp_pair")
                        S.p_amplitude = p;
                    else
                        S.p_temporal = p;
                    end
            end
        end

    catch ME
        warning('LME omnibus extraction failed for formula:\n%s\nReason: %s', formula, ME.message);
    end
end

function p = get_p_from_anova_table(A, termName)

    p = NaN;
    termName = string(termName);

    try
        % ============================================================
        % 1) Get variable names robustly: table vs dataset
        % ============================================================
        if istable(A)
            varNames = string(A.Properties.VariableNames);
        elseif isa(A, 'dataset')
            varNames = string(A.Properties.VarNames);
        else
            fprintf('\nUnknown ANOVA output class: %s\n', class(A));
            disp(A);
            return;
        end

        % ============================================================
        % 2) Find p-value column
        % ============================================================
        pCol = "";

        pCandidates = ["pValue", "pValueDF", "pValueLR", "PValue", "p"];

        for i = 1:numel(pCandidates)
            if any(varNames == pCandidates(i))
                pCol = pCandidates(i);
                break;
            end
        end

        if pCol == ""
            fprintf('\nCould not find p-value column. Available columns:\n');
            disp(varNames');
            disp(A);
            return;
        end

        % ============================================================
        % 3) Find term names
        % ============================================================
        terms = string.empty;

        % Case A: table row names
        if istable(A) && ~isempty(A.Properties.RowNames)
            terms = string(A.Properties.RowNames);
        end

        % Case B: dataset observation names
        if isa(A, 'dataset') && ~isempty(A.Properties.ObsNames)
            terms = string(A.Properties.ObsNames);
        end

        % Case C: term names stored in a variable/column
        if isempty(terms)
            termCandidates = ["Term", "Name", "ModelTerm", "Effect"];

            for i = 1:numel(termCandidates)
                if any(varNames == termCandidates(i))
                    terms = string(A.(char(termCandidates(i))));
                    break;
                end
            end
        end

        if isempty(terms)
            fprintf('\nCould not find ANOVA term names. ANOVA output:\n');
            disp(A);
            return;
        end

        % ============================================================
        % 4) Match requested term
        % ============================================================
        idx = terms == termName;

        % Flexible fallback
        if ~any(idx)
            termsNoSpace = erase(terms, " ");
            termNoSpace  = erase(termName, " ");
            idx = termsNoSpace == termNoSpace;
        end

        % Extra fallback for interaction formatting
        if ~any(idx) && contains(termName, ":")
            parts = split(termName, ":");
            idx = true(size(terms));

            for ip = 1:numel(parts)
                idx = idx & contains(terms, parts(ip));
            end
        end

        if ~any(idx)
            fprintf('\nTerm not found: %s\n', termName);
            fprintf('Available terms:\n');
            disp(terms);
            return;
        end

        % ============================================================
        % 5) Extract p-value
        % ============================================================
        pVals = A.(char(pCol));
        p = pVals(find(idx, 1, 'first'));

    catch ME
        fprintf('\nFailed to extract p-value for term: %s\n', termName);
        fprintf('Reason: %s\n', ME.message);
        p = NaN;
    end
end

function txt = p_to_sig_label(p)

    if isnan(p)
        txt = "NA";
    elseif p < 0.001
        txt = "***";
    elseif p < 0.01
        txt = "**";
    elseif p < 0.05
        txt = "*";
    else
        txt = "ns";
    end
end
