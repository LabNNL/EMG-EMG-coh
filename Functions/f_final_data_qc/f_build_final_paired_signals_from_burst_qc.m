function f_build_final_paired_signals_from_burst_qc()
% F_BUILD_FINAL_PAIRED_SIGNALS_FROM_BURST_QC  Stage f: which gait cycles count,
% and the analysis-ready muscle-pair signals rebuilt from them.
%
% Reads   mat_final_burst_decision/FINAL_BURST_QC.mat (stage e),
%         mat_bursts_data/<subj>_EMG_BURSTS.mat (stage c)
% Writes  mat_final_paired_signals/FINAL_PAIRED_SIGNALS.mat, _OVERALL.mat and
%         _<BAND>.mat (read by stage g); QC tables and recaps in
%         Results/f_cycle_level_qc_and_signal_rebuild/; QC figures
% Settings  C.f_final_signals (config/config_emg.m)
%
% A cycle is kept for a pair when it is valid in both muscles: it has a good
% burst, no flatline, and no bad burst close enough to the pair's phase of
% interest to contaminate the wavelet there (closeness = the cone-of-influence
% half-width of the lowest frequency of the band, so each band has its own
% mask). A pair signal needs C.f_final_signals.params.min_cycles_required
% kept cycles. The two signals of a pair are rebuilt from the same kept
% cycles, so they stay synchronized; each cycle keeps its trial and run id.
%
% The steps are in Functions/f_final_data_qc/f_final_data_qc_steps/.

    C = config_emg();

    addpath(genpath(C.paths.helpers.general));
    addpath(genpath(C.paths.helpers.final_data_qc));

    IO = C.f_final_signals.io;
    PL = C.f_final_signals.plot;


    if ~exist(IO.out_dir, 'dir'), mkdir(IO.out_dir); end
    if ~exist(IO.xlsx_dir, 'dir'), mkdir(IO.xlsx_dir); end
    if ~exist(IO.recap_xlsx_dir, 'dir'), mkdir(IO.recap_xlsx_dir); end
    if ~exist(PL.hist_cycles_dir, 'dir'), mkdir(PL.hist_cycles_dir); end
    if ~exist(PL.excluded.out_dir, 'dir'), mkdir(PL.excluded.out_dir); end
    if ~exist(PL.rebuilt.out_dir, 'dir'), mkdir(PL.rebuilt.out_dir); end
    if ~exist(PL.manual.out_dir, 'dir'), mkdir(PL.manual.out_dir); end
    if ~exist(IO.excluded_burst_position_xlsx, 'dir'), mkdir(fileparts(IO.excluded_burst_position_xlsx)); end
    if ~exist(IO.excluded_burst_position_plot_dir, 'dir'), mkdir(IO.excluded_burst_position_plot_dir); end

    %% ===================== STEPS =====================

    [FINAL_PAIRED_SIGNALS, CYCLE_QC_ROWS, PAIR_QC_ROWS, SIGNAL_ROWS] = f_select_cycles_and_rebuild_pairs(C);
    [CYCLE_QC_TABLE, PAIR_CYCLE_QC_TABLE, FINAL_SIGNAL_SUMMARY, FINAL_PAIRED_SIGNALS, CROSSTALK_QC_TABLE, CROSSTALK_QC_SUSPICIOUS] = f_build_qc_tables(FINAL_PAIRED_SIGNALS, CYCLE_QC_ROWS, PAIR_QC_ROWS, SIGNAL_ROWS, C);
    FULL_LEG_PAIR_DETAIL_RECAP = f_cycle_count_recaps_and_tests(FINAL_PAIRED_SIGNALS, FINAL_SIGNAL_SUMMARY, C);
    f_recoverability_recaps(FINAL_SIGNAL_SUMMARY, FULL_LEG_PAIR_DETAIL_RECAP, C);
    RECAPS = f_analyzable_signal_recaps(FINAL_SIGNAL_SUMMARY, C);
    f_qc_example_plots(FINAL_PAIRED_SIGNALS, FINAL_SIGNAL_SUMMARY, C);
    f_save_outputs(FINAL_PAIRED_SIGNALS, CYCLE_QC_TABLE, PAIR_CYCLE_QC_TABLE, FINAL_SIGNAL_SUMMARY, CROSSTALK_QC_TABLE, CROSSTALK_QC_SUSPICIOUS, RECAPS, C);
end
