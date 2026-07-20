function plot_excluded_burst_positions_by_method_and_muscle(T, outDir, C)

    Tbad = T(T.burst_keep == false, :);
    if isempty(Tbad)
        return;
    end

    muscles = unique(string(Tbad.muscle));
    muscles(ismissing(muscles)) = [];
    muscles = sort(muscles);

    methods = unique(string(Tbad.burst_method));
    methods(ismissing(methods)) = [];
    methods = sort(methods);

    if isempty(muscles) || isempty(methods)
        return;
    end

    nM = numel(muscles);
    nCols = min(2, nM);
    nRows = ceil(nM / nCols);

    fig = figure('Visible','off','Color','w','Position',[100 100 1500 900], ...
        'Toolbar','none','MenuBar','none');

    for iM = 1:nM
        ax = subplot(nRows, nCols, iM); hold(ax,'on');

        idxMus = string(Tbad.muscle) == muscles(iM);

        legendEntries = {};
        for iMet = 1:numel(methods)
            m = methods(iMet);
            idx = idxMus & string(Tbad.burst_method) == m;
            x = Tbad.overlap_center_pct(idx);

            if isempty(x)
                continue;
            end

            thisColor = get_exclusion_method_color(m, C);

            histogram(ax, x, 0:5:100, ...
                'FaceColor', thisColor, ...
                'FaceAlpha', 0.55, ...
                'EdgeColor', 'none');

            % legendEntries{end+1} = char(m); %#ok<AGROW>
            prettyMethod = strrep(char(m), '_', ' ');
            prettyMethod(1) = upper(prettyMethod(1));
            legendEntries{end+1} = sprintf('%s (n=%d)', prettyMethod, numel(x));
        end

        xlabel(ax, 'Burst center in cycle (%)');
        ylabel(ax, 'Count');
        title(ax, sprintf('%s', muscles(iM)), 'Interpreter','none');
        grid(ax,'on');

        if ~isempty(legendEntries)
            legend(ax, legendEntries, 'Location','best');
        end
    end

    sgtitle('Bad burst positions in excluded cycles by muscle and exclusion method', 'Interpreter','none');
    exportgraphics(fig, fullfile(outDir, 'excluded_cycle_bad_burst_positions_by_method_and_muscle.png'), 'Resolution', 200);
    close(fig);
end
