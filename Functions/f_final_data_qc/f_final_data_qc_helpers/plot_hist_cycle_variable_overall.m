
function plot_hist_cycle_variable_overall(T, outDir, valueVar, titleStr, fileName, xLabelStr)

    if isempty(T) || ~ismember(valueVar, T.Properties.VariableNames)
        return;
    end

    x = T.(valueVar);
    x = x(~isnan(x));

    if isempty(x), return; end

    fig = figure('Visible','off','Color','w','Position',[100 100 900 600], ...
        'Toolbar','none','MenuBar','none');

    h = histogram(x, 'BinMethod', 'integers');

    maxCount = max(h.Values);
    if isempty(maxCount) || maxCount == 0 || ~isfinite(maxCount)
        maxCount = 1;
    end

    ylim([0, ceil(maxCount * 1.15)]);

    xlabel(xLabelStr, 'Interpreter','none');
    ylabel('Count');
    title(titleStr, 'Interpreter','none');
    grid on;

    exportgraphics(fig, fullfile(outDir, fileName), 'Resolution', 200);
    close(fig);
end
