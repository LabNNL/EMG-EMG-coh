function plot_excluded_burst_position_histograms(T, outDir, C)

    fig = figure('Visible','off','Color','w','Position',[100 100 1200 900], ...
        'Toolbar','none','MenuBar','none');

    colGood = C.plotting.colors.include;
    colBad  = C.plotting.colors.exclude;

    % robust conversion of burst_keep to logical
    burstKeep = table_col_to_logical(T.burst_keep);

    % ---------- All bursts ----------
    ax1 = subplot(3,1,1); hold(ax1,'on');
    xGood = T.overlap_center_pct(burstKeep);
    xBad  = T.overlap_center_pct(~burstKeep);

    if ~isempty(xGood)
        histogram(ax1, xGood, 0:5:100, 'FaceColor', colGood, 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    end
    if ~isempty(xBad)
        histogram(ax1, xBad, 0:5:100, 'FaceColor', colBad, 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    end
    xlabel(ax1, 'Burst center position in excluded cycle (%)');
    ylabel(ax1, 'Count');
    title(ax1, 'All overlapping bursts in excluded cycles');
    legend(ax1, {'Good burst','Bad burst'}, 'Location','best');
    grid(ax1,'on');

    % ---------- Bad bursts only ----------
    ax2 = subplot(3,1,2); hold(ax2,'on');
    if ~isempty(xBad)
        histogram(ax2, xBad, 0:5:100, 'FaceColor', colBad, 'FaceAlpha', 0.8, 'EdgeColor', 'none');
    end
    xlabel(ax2, 'Burst center position in excluded cycle (%)');
    ylabel(ax2, 'Count');
    title(ax2, 'Bad bursts only in excluded cycles');
    grid(ax2,'on');

    % ---------- Good bursts only ----------
    ax3 = subplot(3,1,3); hold(ax3,'on');
    if ~isempty(xGood)
        histogram(ax3, xGood, 0:5:100, 'FaceColor', colGood, 'FaceAlpha', 0.8, 'EdgeColor', 'none');
    end
    xlabel(ax3, 'Burst center position in excluded cycle (%)');
    ylabel(ax3, 'Count');
    title(ax3, 'Good bursts only in excluded cycles');
    grid(ax3,'on');

    sgtitle('Burst positions within excluded cycles', 'Interpreter','none');

    exportgraphics(fig, fullfile(outDir, 'excluded_cycle_burst_positions_overall.png'), 'Resolution', 200);
    close(fig);
end
