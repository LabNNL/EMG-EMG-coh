function [CYCLE_QC_TABLE, PAIR_CYCLE_QC_TABLE, FINAL_SIGNAL_SUMMARY, FINAL_PAIRED_SIGNALS, CROSSTALK_QC_TABLE, CROSSTALK_QC_SUSPICIOUS] = f_build_qc_tables(FINAL_PAIRED_SIGNALS, CYCLE_QC_ROWS, PAIR_QC_ROWS, SIGNAL_ROWS, C)
% F_BUILD_QC_TABLES  Turns the QC rows into tables, applies the crosstalk
% exclusion (C.f_final_signals.crosstalk) to the pair struct and the summary,
% and adds cycle-retention columns.

    bandNames = fieldnames(C.f_final_signals.params.wavelet_contamination_qc.freq_bands);

    %% ===================== BUILD TABLES =====================
    fprintf('\nBuilding output tables...\n');
    if ~isempty(CYCLE_QC_ROWS)
        CYCLE_QC_TABLE = cell2table(CYCLE_QC_ROWS, 'VariableNames', { 'subject','condition','leg','muscle', 'cycle_number','cycle_start_idx','cycle_end_idx', 'n_overlapping_bursts', 'has_any_burst','has_good_burst','has_bad_burst', 'cycle_keep','cycle_reason'});
    else
        CYCLE_QC_TABLE = table();
    end
    fprintf('Cycle QC rows: %d\n', size(CYCLE_QC_ROWS,1));

    if ~isempty(PAIR_QC_ROWS)
        pairVarNames = { 'subject','condition','leg','pair_name','muscle1','muscle2', 'cycle_number','cycle_start_idx','cycle_end_idx', 'muscle1_cycle_keep','muscle2_cycle_keep', 'pair_cycle_keep','pair_cycle_reason'};
        pairVarNames = [pairVarNames, strcat('pair_cycle_keep_', lower(bandNames(:)')), strcat('pair_cycle_reason_', lower(bandNames(:)'))];

        assert(size(PAIR_QC_ROWS,2) == numel(pairVarNames), 'PAIR_QC_ROWS has %d columns but pairVarNames has %d names.', size(PAIR_QC_ROWS,2), numel(pairVarNames));

        PAIR_CYCLE_QC_TABLE = cell2table(PAIR_QC_ROWS, 'VariableNames', pairVarNames);
    else
        PAIR_CYCLE_QC_TABLE = table();
    end
    fprintf('Pair cycle QC rows: %d\n', size(PAIR_QC_ROWS,1));

    if ~isempty(SIGNAL_ROWS)
        FINAL_SIGNAL_SUMMARY = cell2table(SIGNAL_ROWS, 'VariableNames', [{ 'subject','age_group','condition','leg','pair_name','muscle1','muscle2', 'n_cycles_total','n_valid_cycles','n_removed_cycles', 'included_for_analysis','exclusion_reason', 'final_signal_length_1','final_signal_length_2','fs', 'cycle_source_field_muscle1','cycle_source_field_muscle2','cycle_alignment_note'}, ...
            strcat('n_valid_cycles_', lower(bandNames(:)')), strcat('included_for_analysis_', lower(bandNames(:)'))]);
    else
        FINAL_SIGNAL_SUMMARY = table();
    end

    fprintf('Final signal summary rows: %d\n', size(FINAL_SIGNAL_SUMMARY,1));


    %% ===================== APPLY CROSS-TALK EXCLUSION =====================


    if isfield(C.f_final_signals, 'crosstalk') && C.f_final_signals.crosstalk.enable
        XTK = C.f_final_signals.crosstalk;
        fprintf('\nApplying cross-talk QC exclusion...\n');

        [FINAL_PAIRED_SIGNALS, FINAL_SIGNAL_SUMMARY, CROSSTALK_QC_TABLE, CROSSTALK_QC_SUSPICIOUS] = apply_crosstalk_qc_to_final_signals( FINAL_PAIRED_SIGNALS, FINAL_SIGNAL_SUMMARY, C);

    else
        CROSSTALK_QC_TABLE = table();
        CROSSTALK_QC_SUSPICIOUS = table();

        FINAL_SIGNAL_SUMMARY.excluded_by_crosstalk = false(height(FINAL_SIGNAL_SUMMARY),1);
        FINAL_SIGNAL_SUMMARY.crosstalk_reason = repmat("", height(FINAL_SIGNAL_SUMMARY),1);

        FINAL_SIGNAL_SUMMARY.included_after_crosstalk = FINAL_SIGNAL_SUMMARY.included_for_analysis;
        for ib = 1:numel(bandNames)
            b = lower(bandNames{ib});
            FINAL_SIGNAL_SUMMARY.(['included_after_crosstalk_' b]) = FINAL_SIGNAL_SUMMARY.(['included_for_analysis_' b]);
        end
    end

    %% ===================== CYCLE RETENTION METRICS =====================

    if ~isempty(FINAL_SIGNAL_SUMMARY)
        FINAL_SIGNAL_SUMMARY.n_initial_cycles = FINAL_SIGNAL_SUMMARY.n_cycles_total;
        FINAL_SIGNAL_SUMMARY.n_final_valid_cycles = FINAL_SIGNAL_SUMMARY.n_valid_cycles;
        FINAL_SIGNAL_SUMMARY.n_cycles_removed_by_qc = FINAL_SIGNAL_SUMMARY.n_initial_cycles - FINAL_SIGNAL_SUMMARY.n_final_valid_cycles;

        FINAL_SIGNAL_SUMMARY.percent_cycles_kept = 100 * FINAL_SIGNAL_SUMMARY.n_final_valid_cycles ./ FINAL_SIGNAL_SUMMARY.n_initial_cycles;

        FINAL_SIGNAL_SUMMARY.percent_cycles_removed = 100 * FINAL_SIGNAL_SUMMARY.n_cycles_removed_by_qc ./ FINAL_SIGNAL_SUMMARY.n_initial_cycles;

        FINAL_SIGNAL_SUMMARY.percent_cycles_kept(~isfinite(FINAL_SIGNAL_SUMMARY.percent_cycles_kept)) = NaN;
        FINAL_SIGNAL_SUMMARY.percent_cycles_removed(~isfinite(FINAL_SIGNAL_SUMMARY.percent_cycles_removed)) = NaN;
    end

    %% ===================== FINAL CHECKS =====================

    fprintf('\n===================== BAND DIFFERENCE CHECK =====================\n');
    fprintf('Different valid-cycle counts vs overall:\n');
    for ib = 1:numel(bandNames)
        fprintf('  %s: %d\n', bandNames{ib}, sum(FINAL_SIGNAL_SUMMARY.(['n_valid_cycles_' lower(bandNames{ib})]) ~= FINAL_SIGNAL_SUMMARY.n_valid_cycles));
    end

    fprintf('Different inclusion status vs overall:\n');
    for ib = 1:numel(bandNames)
        fprintf('  %s: %d\n', bandNames{ib}, sum(FINAL_SIGNAL_SUMMARY.(['included_for_analysis_' lower(bandNames{ib})]) ~= FINAL_SIGNAL_SUMMARY.included_for_analysis));
    end
end
