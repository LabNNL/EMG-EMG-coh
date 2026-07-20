function plot_one_wavelet_roi_exclusion_cycle(P, subjID, cond, leg, pairName, cycleNum, WCQ, outDir, C, band)

    fs = P.fs;
    mus1 = P.muscles{1};
    mus2 = P.muscles{2};

    c1 = P.cycle_starts(cycleNum);
    c2 = P.cycle_ends(cycleNum);

    x1 = P.original_signal_1(c1:c2);
    x2 = P.original_signal_2(c1:c2);

    nSamp = numel(x1);
    xPct = linspace(0, 100, nSamp);

    cycle_duration_sec = nSamp / fs;
    phaseIntervals_sec = get_phase_intervals_for_pair(pairName, cycle_duration_sec, WCQ);
    phaseIntervals_pct = 100 * phaseIntervals_sec / cycle_duration_sec;

    cyc1 = P.muscle1_cycle_qc;
    cyc2 = P.muscle2_cycle_qc;

    fig = figure('Visible','off','Color','w','Position',[100 100 1500 900], ...
        'Toolbar','none','MenuBar','none');

    tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

    plot_one_cycle_subplot(nexttile, xPct, x1, cyc1, cycleNum, mus1, phaseIntervals_pct, fs, cycle_duration_sec, C, band);
    plot_one_cycle_subplot(nexttile, xPct, x2, cyc2, cycleNum, mus2, phaseIntervals_pct, fs, cycle_duration_sec, C, band);

    reason1 = get_reason_for_band(cyc1, cycleNum, band);
    reason2 = get_reason_for_band(cyc2, cycleNum, band);

    if strcmpi(string(band), "overall")
        modeLabel = "OVERALL";
    else
        modeLabel = upper(string(band));
    end

    sgtitle(sprintf('%s | %s | %s | %s | cycle %d | %s\nM1: %s | M2: %s', ...
        subjID, cond, leg, pairName, cycleNum, modeLabel, reason1, reason2), ...
        'Interpreter','none');

    fname = sprintf('wavelet_roi_exclusion__%s__%s__%s__%s__cycle_%03d__%s.png', ...
        subjID, cond, leg, pairName, cycleNum, lower(char(modeLabel)));

    exportgraphics(fig, fullfile(outDir, fname), 'Resolution', 200);
    close(fig);
end
