function plot_histograms_overall(T, featureVars, nbins, outDir)
    fig = figure('Color','w', 'Visible','off', 'Position',[100 100 1400 900]);

    nF = numel(featureVars);
    nRows = ceil(nF/3);
    nCols = 3;

    for i = 1:nF
        subplot(nRows, nCols, i);
        x = T.(featureVars{i});
        x = x(~isnan(x));
        if isempty(x), continue; end
        histogram(x, nbins, 'Normalization', 'probability', 'DisplayStyle', 'stairs', 'LineWidth', 1.8);
        title(strrep(featureVars{i}, '_', '\_'));
        xlabel(featureVars{i});
        ylabel('Probability');
        grid on;
    end

    sgtitle('Overall feature distributions');
    saveas(fig, fullfile(outDir, 'hist_overall_features.png'));
    close(fig);
end