function plot_hist_cycles_participant_3x4(T, outDir, conditionOrder, ageOrder, colorStruct, ...
    pairName, valueVar, figTitle, fileName, xLabelStr)

    if isempty(T)
        return;
    end

    conds = string(conditionOrder);
    ages  = string(ageOrder);

    fig = figure('Visible','off','Color','w','Position',[100 100 1600 1000], ...
        'Toolbar','none','MenuBar','none');

    tl = tiledlayout(numel(conds), numel(ages), ...
        'TileSpacing','compact', ...
        'Padding','compact');

    % Shared ylim within this figure
    maxCount = 0;
    for ic = 1:numel(conds)
        for ia = 1:numel(ages)
            idx = string(T.condition) == conds(ic) & string(T.age_group) == ages(ia);
            x = T.(valueVar)(idx);
            x = x(~isnan(x));

            if isempty(x), continue; end

            edges = (floor(min(x))-0.5):(ceil(max(x))+0.5);
            if numel(edges) < 2
                edges = [min(x)-0.5, min(x)+0.5];
            end

            counts = histcounts(x, edges);
            maxCount = max(maxCount, max(counts));
        end
    end

    if maxCount == 0
        maxCount = 1;
    end

    yLim = [0, ceil(maxCount * 1.15)];

    for ic = 1:numel(conds)
        for ia = 1:numel(ages)

            ax = nexttile(tl);
            hold(ax,'on');

            cond = conds(ic);
            age  = ages(ia);

            idx = string(T.condition) == cond & string(T.age_group) == age;
            x = T.(valueVar)(idx);
            x = x(~isnan(x));

            if isempty(x)
                axis(ax, 'on');
                title(ax, sprintf('%s | %s\nn=0', cond, age), 'Interpreter','none');
                ylim(ax, yLim);
                grid(ax,'on');
                continue;
            end

            thisColor = get_group_color(age, colorStruct);

            histogram(ax, x, 'BinMethod', 'integers', ...
                'FaceColor', thisColor, ...
                'EdgeColor', 'k', ...
                'LineWidth', 0.7);

            ylim(ax, yLim);
            xlabel(ax, xLabelStr);
            ylabel(ax, 'Participants');
            title(ax, sprintf('%s | %s\nn=%d', cond, age, numel(x)), 'Interpreter','none');
            grid(ax,'on');
            box(ax,'on');
        end
    end

    sgtitle(figTitle, 'Interpreter','none');
    exportgraphics(fig, fullfile(outDir, fileName), 'Resolution', 200);
    close(fig);
end