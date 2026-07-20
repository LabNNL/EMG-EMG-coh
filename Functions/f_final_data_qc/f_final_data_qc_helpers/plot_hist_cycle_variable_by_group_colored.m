function plot_hist_cycle_variable_by_group_colored(T, groupVar, groupOrder, colorStruct, ...
    outDir, groupLabel, valueVar, titleStr, fileName, xLabelStr)

    if isempty(T) || ~ismember(valueVar, T.Properties.VariableNames)
        return;
    end

    groupsPresent = unique(string(T.(groupVar)));
    groupsPresent(ismissing(groupsPresent)) = [];

    groups = string(groupOrder);
    groups = groups(ismember(groups, groupsPresent));

    extraGroups = setdiff(groupsPresent, groups, 'stable');
    groups = [groups; extraGroups];

    if isempty(groups), return; end

    nG = numel(groups);
    nCols = min(4, nG);
    nRows = ceil(nG / nCols);

    fig = figure('Visible','off','Color','w','Position',[100 100 1400 800], ...
        'Toolbar','none','MenuBar','none');

    % Shared ylim within this figure only
    maxCount = 0;
    for i = 1:nG
        idx = string(T.(groupVar)) == groups(i);
        x = T.(valueVar)(idx);
        x = x(~isnan(x));

        if isempty(x), continue; end

        counts = histcounts(x, 'BinMethod', 'integers');
        if ~isempty(counts)
            maxCount = max(maxCount, max(counts));
        end
    end

    if maxCount == 0
        maxCount = 1;
    end
    yLim = [0, ceil(maxCount * 1.15)];

    for i = 1:nG
        subplot(nRows, nCols, i);

        g = groups(i);
        idx = string(T.(groupVar)) == g;
        x = T.(valueVar)(idx);
        x = x(~isnan(x));

        if isempty(x)
            title(sprintf('%s (n=0)', g), 'Interpreter','none');
            ylim(yLim);
            grid on;
            continue;
        end

        thisColor = get_group_color(g, colorStruct);

        histogram(x, 'BinMethod', 'integers', ...
            'FaceColor', thisColor, ...
            'EdgeColor', 'k', ...
            'LineWidth', 0.8);

        ylim(yLim);
        xlabel(xLabelStr, 'Interpreter','none');
        ylabel('Count');
        title(sprintf('%s (n=%d)', g, numel(x)), 'Interpreter','none');
        grid on;
    end

    sgtitle(titleStr, 'Interpreter','none');

    exportgraphics(fig, fullfile(outDir, fileName), 'Resolution', 200);
    close(fig);
end