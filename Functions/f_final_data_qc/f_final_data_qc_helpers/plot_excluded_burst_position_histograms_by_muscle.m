
function plot_excluded_burst_position_histograms_by_muscle(T, outDir, C)

    muscles = unique(string(T.muscle));
    muscles(ismissing(muscles)) = [];
    muscles = sort(muscles);

    if isempty(muscles)
        return;
    end

    burstKeep = table_col_to_logical(T.burst_keep);

    nM = numel(muscles);
    nCols = min(2, nM);
    nRows = ceil(nM / nCols);

    fig = figure('Visible','off','Color','w','Position',[100 100 1400 900], ...
        'Toolbar','none','MenuBar','none');

    colGood = C.plotting.colors.include;
    colBad  = C.plotting.colors.exclude;

    for iM = 1:nM
        ax = subplot(nRows, nCols, iM); hold(ax,'on');

        idx = string(T.muscle) == muscles(iM);
        xGood = T.overlap_center_pct(idx & burstKeep);
        xBad  = T.overlap_center_pct(idx & ~burstKeep);

        legendHandles = gobjects(0);
        legendEntries = {};

        if ~isempty(xGood)
            h1 = histogram(ax, xGood, 0:5:100, ...
                'FaceColor', colGood, 'FaceAlpha', 0.6, 'EdgeColor', 'none');
            legendHandles(end+1) = h1; %#ok<AGROW>
            legendEntries{end+1} = sprintf('Good burst (n=%d)', numel(xGood)); %#ok<AGROW>
        end

        if ~isempty(xBad)
            h2 = histogram(ax, xBad, 0:5:100, ...
                'FaceColor', colBad, 'FaceAlpha', 0.6, 'EdgeColor', 'none');
            legendHandles(end+1) = h2; %#ok<AGROW>
            legendEntries{end+1} = sprintf('Bad burst (n=%d)', numel(xBad)); %#ok<AGROW>
        end

        xlabel(ax, 'Burst center in cycle (%)');
        ylabel(ax, 'Count');
        title(ax, sprintf('%s', muscles(iM)), 'Interpreter','none');
        grid(ax,'on');

        if ~isempty(legendEntries)
            legend(ax, legendHandles, legendEntries, 'Location','best');
        end
    end

    sgtitle('Burst center positions in excluded cycles by muscle', 'Interpreter','none');
    exportgraphics(fig, fullfile(outDir, 'excluded_cycle_burst_positions_by_muscle.png'), 'Resolution', 200);
    close(fig);
end
