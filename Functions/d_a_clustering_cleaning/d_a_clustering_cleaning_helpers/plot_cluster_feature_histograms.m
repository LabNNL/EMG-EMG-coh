function plot_cluster_feature_histograms(T, CLUSTER_RESULTS, featureVars, outDir)

    validIdx = T.cluster_valid;
    if ~any(validIdx), return; end

    if CLUSTER_RESULTS.meta.groupVar == "ALL"
        groupsToPlot = "ALL";
    else
        groupsToPlot = unique(T.cluster_group(validIdx));
        groupsToPlot = sort(groupsToPlot);
    end

    for g = 1:numel(groupsToPlot)
        groupLabel = groupsToPlot(g);

        idxg = validIdx & T.cluster_group == groupLabel;
        if ~any(idxg), continue; end

        clusters = unique(T.cluster_id(idxg));
        clusters = sort(clusters);

        % cluster sizes for this group
        clusterCounts = zeros(numel(clusters),1);
        for c = 1:numel(clusters)
            clusterCounts(c) = sum(idxg & T.cluster_id == clusters(c));
        end

        legendLabels = compose('Cluster %d (n=%d)', clusters, clusterCounts);

        fig = figure('Color','w','Position',[100 100 1400 900]);

        nF = numel(featureVars);
        nRows = ceil(nF/3);
        nCols = 3;

        for iF = 1:nF
            feat = featureVars{iF};
            subplot(nRows, nCols, iF); hold on;

            legendHandles = gobjects(0);

            for c = 1:numel(clusters)
                idxc = idxg & T.cluster_id == clusters(c);
                x = T.(feat)(idxc);
                x = x(~isnan(x));
                if isempty(x), continue; end

                h = histogram(x, 50, ...
                    'Normalization', 'probability', ...
                    'DisplayStyle', 'stairs', ...
                    'LineWidth', 1.5);

                legendHandles(end+1) = h; %#ok<AGROW>
            end

            xlabel(feat);
            ylabel('Probability');
            title(strrep(feat, '_', '\_'));
            if ~isempty(legendHandles)
                legend(legendHandles, legendLabels(1:numel(legendHandles)), 'Location', 'best');
            end
            grid on;
        end

        sgtitle(sprintf('Cluster feature distributions | %s', string(groupLabel)), 'Interpreter','none');
        fname = sprintf('cluster_feature_hists__%s.png', make_valid_fieldname(groupLabel));
        try
            saveas(fig, fullfile(outDir, fname));
            fprintf('Saved cluster feature histograms plot to %s\n', fullfile(outDir, fname));
        catch
            warning('Failed to save cluster feature histograms plot for group %s.', string(groupLabel));
        end
        % close(fig);
    end
end
