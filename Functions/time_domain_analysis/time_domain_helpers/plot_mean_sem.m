function plot_mean_sem(ax, X, col, labelText, alphaVal)
    if isempty(X), return; end

    M = mean(X, 1, 'omitnan');
    S = std(X, 0, 1, 'omitnan') ./ sqrt(size(X,1));
    x = linspace(0, 100, numel(M));

    fill(ax, [x fliplr(x)], [M-S fliplr(M+S)], col, 'FaceAlpha', alphaVal, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax, x, M, 'LineWidth', 2, 'Color', col, 'DisplayName', labelText);
end
