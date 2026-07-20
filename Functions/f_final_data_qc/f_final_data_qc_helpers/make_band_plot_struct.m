function Pplot = make_band_plot_struct(PairStruct, band)

    Pplot = struct();

    Pplot.fs = PairStruct.fs;
    Pplot.cycle_starts = PairStruct.cycle_starts;
    Pplot.cycle_ends   = PairStruct.cycle_ends;
    Pplot.n_cycles_total = PairStruct.n_cycles_total;
    Pplot.min_cycles_required = PairStruct.min_cycles_required;

    Pplot.original_signals = { ...
        PairStruct.original_signal_1, ...
        PairStruct.original_signal_2};

    Pplot.signal_labels = PairStruct.muscles;

    Pplot.rebuilt_signals = { ...
        PairStruct.band_specific.(band).final_concatenated_signal_1, ...
        PairStruct.band_specific.(band).final_concatenated_signal_2};

    Pplot.pair_cycle_keep_mask = PairStruct.band_specific.(band).pair_cycle_keep_mask;
    Pplot.final_cycle_segments_table = PairStruct.band_specific.(band).final_cycle_segments_table;

    Pplot.n_valid_cycles = PairStruct.band_specific.(band).n_valid_cycles;
    Pplot.included_for_analysis = PairStruct.band_specific.(band).included_for_analysis;

    if Pplot.included_for_analysis
        Pplot.exclusion_reason = "";
    else
        Pplot.exclusion_reason = "too_few_valid_cycles";
    end

    Pplot.cycle_keep_masks = { ...
        PairStruct.muscle1_cycle_qc.band_keep_mask.(band), ...
        PairStruct.muscle2_cycle_qc.band_keep_mask.(band)};

    Pplot.cycle_reason_lists = { ...
        PairStruct.muscle1_cycle_qc.band_reason.(band), ...
        PairStruct.muscle2_cycle_qc.band_reason.(band)};
end