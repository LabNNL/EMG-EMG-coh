function plot_pooled_before_after_edgecycle_qc( ...
    mean_before, mean_after, Freq, datasetName, nSignals, useSignificant, outDir)

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 900]);

    t = linspace(0, 100, size(mean_before,2));

    if useSignificant
        mapLabel = 'significant coherence';
        outName = sprintf('POOLED_BEFORE_AFTER_EDGE_CYCLE_QC_SIG_%s.png', char(datasetName));
    else
        mapLabel = 'raw coherence';
        outName = sprintf('POOLED_BEFORE_AFTER_EDGE_CYCLE_QC_RAW_%s.png', char(datasetName));
    end

    clim_max = max([mean_before(:); mean_after(:)], [], 'omitnan');
    if isempty(clim_max) || isnan(clim_max) || clim_max <= 0
        clim_max = 1;
    end

    % ---------- Top: before removing edge cycles ----------
    ax1 = subplot(3,1,1);
    imagesc(t, Freq, mean_before);
    axis xy;
    colorbar;
    caxis([0 clim_max]);
    xlabel('Normalized gait-cycle time (%)');
    ylabel('Frequency (Hz)');
    title(sprintf('Before edge-cycle removal | %s | %s | n = %d signals', ...
        char(datasetName), mapLabel, nSignals), 'Interpreter', 'none');
    grid on;
    box on;

    % ---------- Middle: after removing edge cycles ----------
    ax2 = subplot(3,1,2);
    imagesc(t, Freq, mean_after);
    axis xy;
    colorbar;
    caxis([0 clim_max]);
    xlabel('Normalized gait-cycle time (%)');
    ylabel('Frequency (Hz)');
    title(sprintf('After edge-cycle removal | %s | %s', ...
        char(datasetName), mapLabel), 'Interpreter', 'none');
    grid on;
    box on;

    % ---------- Bottom: frequency-averaged curves ----------
    ax3 = subplot(3,1,3);
    curve_before = mean(mean_before, 1, 'omitnan');
    curve_after  = mean(mean_after,  1, 'omitnan');

    plot(t, curve_before, 'k-', 'LineWidth', 1.5); hold on;
    plot(t, curve_after,  'r-', 'LineWidth', 1.5);

    xlabel('Normalized gait-cycle time (%)');
    ylabel('Mean coherence');
    title('Frequency-averaged coherence: before vs after edge-cycle removal');
    legend({'Before removal','After removal'}, 'Location', 'best');
    grid on;
    box on;

    linkaxes([ax1 ax2], 'xy');

    saveas(fig, fullfile(outDir, outName));
    close(fig);
end