function f_save_outputs(FINAL_PAIRED_SIGNALS, CYCLE_QC_TABLE, PAIR_CYCLE_QC_TABLE, FINAL_SIGNAL_SUMMARY, CROSSTALK_QC_TABLE, CROSSTALK_QC_SUSPICIOUS, RECAPS, C)
% F_SAVE_OUTPUTS  Writes the QC tables (xlsx), the merged recap tables,
% FINAL_PAIRED_SIGNALS.mat (pair struct, QC tables, recaps, settings), and
% the exports read by stage g: FINAL_PAIRED_SIGNALS_OVERALL.mat and one
% FINAL_PAIRED_SIGNALS_<BAND>.mat per band.

    IO = C.f_final_signals.io;
    P  = C.f_final_signals.params;
    PL = C.f_final_signals.plot;
    bandNames = fieldnames(C.f_final_signals.params.wavelet_contamination_qc.freq_bands);
    ANALYZABLE_SIGNALS = RECAPS.ANALYZABLE_SIGNALS;
    ANALYZABLE_SIGNALS_BY_BAND = RECAPS.ANALYZABLE_SIGNALS_BY_BAND;

    %% ===================== SAVE =====================

    fprintf('\nSaving tables as xlsx...\n');
    writetable(CYCLE_QC_TABLE, IO.cycle_qc_xlsx);
    fprintf('Saved:\n  %s\n', IO.cycle_qc_xlsx);
    writetable(PAIR_CYCLE_QC_TABLE, IO.pair_cycle_xlsx);
    fprintf('Saved:\n  %s\n', IO.pair_cycle_xlsx);
    writetable(FINAL_SIGNAL_SUMMARY, IO.signal_sum_xlsx);
    fprintf('Saved:\n  %s\n', IO.signal_sum_xlsx);

    %% ===================== SAVE MERGED RECAP TABLES =====================

    fprintf('\nBuilding merged recap master tables...\n');

    RECAP_MASTER_SIGNAL_BY_PAIR_BAND = build_master_signal_recap_by_pair_band(ANALYZABLE_SIGNALS, "OVERALL");
    RECAP_MASTER_PARTICIPANT_BY_PAIR_BAND = build_master_participant_recap_by_pair_band(ANALYZABLE_SIGNALS, "OVERALL");
    RECAP_MASTER_CYCLE_DISTRIBUTION_BY_PAIR_BAND = build_master_cycle_distribution_by_pair_band(FINAL_SIGNAL_SUMMARY, "OVERALL", "included_after_crosstalk", "n_valid_cycles");
    for ib = 1:numel(bandNames)
        band = bandNames{ib};
        RECAP_MASTER_SIGNAL_BY_PAIR_BAND = [RECAP_MASTER_SIGNAL_BY_PAIR_BAND; build_master_signal_recap_by_pair_band(ANALYZABLE_SIGNALS_BY_BAND.(band), upper(band))]; %#ok<AGROW>
        RECAP_MASTER_PARTICIPANT_BY_PAIR_BAND = [RECAP_MASTER_PARTICIPANT_BY_PAIR_BAND; build_master_participant_recap_by_pair_band(ANALYZABLE_SIGNALS_BY_BAND.(band), upper(band))]; %#ok<AGROW>
        RECAP_MASTER_CYCLE_DISTRIBUTION_BY_PAIR_BAND = [RECAP_MASTER_CYCLE_DISTRIBUTION_BY_PAIR_BAND; build_master_cycle_distribution_by_pair_band(FINAL_SIGNAL_SUMMARY, upper(band), ['included_after_crosstalk_' lower(band)], ['n_valid_cycles_' lower(band)])]; %#ok<AGROW>
    end

    writetable(RECAP_MASTER_SIGNAL_BY_PAIR_BAND, fullfile(IO.recap_xlsx_dir, 'RECAP_MASTER_SIGNAL_BY_PAIR_BAND.xlsx'));

    writetable(RECAP_MASTER_PARTICIPANT_BY_PAIR_BAND, fullfile(IO.recap_xlsx_dir, 'RECAP_MASTER_PARTICIPANT_BY_PAIR_BAND.xlsx'));

    writetable(RECAP_MASTER_CYCLE_DISTRIBUTION_BY_PAIR_BAND, fullfile(IO.recap_xlsx_dir, 'RECAP_MASTER_CYCLE_DISTRIBUTION_BY_PAIR_BAND.xlsx'));

    fprintf('Saved merged recap master tables to:\n  %s\n', IO.recap_xlsx_dir);

    %% ===================== EXPORT BAND-SPECIFIC FINAL SIGNAL FILES =====================

    fprintf('\nBuilding exported band-specific FINAL_PAIRED_SIGNALS files...\n');

    FINAL_PAIRED_SIGNALS_OVERALL = build_export_final_paired_signals(FINAL_PAIRED_SIGNALS, "overall");

    fprintf('Saving:\n  %s\n', IO.out_mat_overall);
    save(IO.out_mat_overall, 'FINAL_PAIRED_SIGNALS_OVERALL', '-v7.3');

    % One file per band, holding one variable FINAL_PAIRED_SIGNALS_<BAND>
    for ib = 1:numel(bandNames)
        band = bandNames{ib};
        BAND_EXPORT = struct();
        BAND_EXPORT.(['FINAL_PAIRED_SIGNALS_' upper(band)]) = build_export_final_paired_signals(FINAL_PAIRED_SIGNALS, band, bandNames);
        fprintf('Saving:\n  %s\n', IO.out_mat_band.(band));
        save(IO.out_mat_band.(band), '-struct', 'BAND_EXPORT', '-v7.3');
        clear BAND_EXPORT
    end

    S = RECAPS;
    S.FINAL_PAIRED_SIGNALS = FINAL_PAIRED_SIGNALS;
    S.CYCLE_QC_TABLE = CYCLE_QC_TABLE;
    S.PAIR_CYCLE_QC_TABLE = PAIR_CYCLE_QC_TABLE;
    S.FINAL_SIGNAL_SUMMARY = FINAL_SIGNAL_SUMMARY;
    S.CROSSTALK_QC_TABLE = CROSSTALK_QC_TABLE;
    S.CROSSTALK_QC_SUSPICIOUS = CROSSTALK_QC_SUSPICIOUS;
    S.IO = IO;
    S.P = P;
    S.PL = PL;
    fprintf('\nSaving:\n  %s\n', IO.out_mat);
    save(IO.out_mat, '-struct', 'S', '-v7.3');
    fprintf('Updated mat file with recap tables.\n');
end
