function plot_clustering_scores(CLUSTER_RESULTS, outDir)

    gNames = fieldnames(CLUSTER_RESULTS.groups);
    if isempty(gNames), return; end

    for i = 1:numel(gNames)
        res = CLUSTER_RESULTS.groups.(gNames{i});

        fig = figure('Color','w','Position',[100 100 1400 900]);

        if res.skipped
            axes('Position',[0.1 0.1 0.8 0.8]);
            axis off;
            title(sprintf('%s (skipped)', string(res.group_label)), 'Interpreter','none');
            text(0.1, 0.5, res.reason, 'FontSize', 12);
        else
            kVals = res.k_values;

            % Find best index based on chosen k
            bestIdx = find(kVals == res.best_k, 1);

            % ---------- 1. Silhouette ----------
            subplot(2,2,1);
            ax = gca;
            ax.Toolbar.Visible = 'off';
            bar(kVals, res.silhouette_mean); hold on;
            if ~isempty(bestIdx)
                plot(kVals(bestIdx), res.silhouette_mean(bestIdx), 'r*', 'MarkerSize', 10, 'LineWidth', 1.5);
            end
            xlabel('k');
            ylabel('Mean silhouette');
            title('Silhouette');
            grid on;

            % ---------- 2. Calinski-Harabasz ----------
            subplot(2,2,2);
            ax = gca;
            ax.Toolbar.Visible = 'off';
            if isfield(res, 'calinski_harabasz')
                bar(kVals, res.calinski_harabasz); hold on;
                if ~isempty(bestIdx)
                    plot(kVals(bestIdx), res.calinski_harabasz(bestIdx), 'r*', 'MarkerSize', 10, 'LineWidth', 1.5);
                end
            else
                text(0.2, 0.5, 'Not available', 'FontSize', 12);
                axis off;
            end
            xlabel('k');
            ylabel('CH index');
            title('Calinski-Harabasz');
            grid on;

            % ---------- 3. Davies-Bouldin ----------
            subplot(2,2,3);
            ax = gca;
            ax.Toolbar.Visible = 'off';
            if isfield(res, 'davies_bouldin')
                bar(kVals, res.davies_bouldin); hold on;
                if ~isempty(bestIdx)
                    plot(kVals(bestIdx), res.davies_bouldin(bestIdx), 'r*', 'MarkerSize', 10, 'LineWidth', 1.5);
                end
            else
                text(0.2, 0.5, 'Not available', 'FontSize', 12);
                axis off;
            end
            xlabel('k');
            ylabel('DB index');
            title('Davies-Bouldin (lower is better)');
            grid on;

            % ---------- 4. WCSS ----------
            subplot(2,2,4);
            ax = gca;
            ax.Toolbar.Visible = 'off';
            
            if isfield(res, 'wcss')
                plot(kVals, res.wcss, '-o', 'LineWidth', 1.8); hold on;
                if ~isempty(bestIdx)
                    plot(kVals(bestIdx), res.wcss(bestIdx), 'r*', 'MarkerSize', 10, 'LineWidth', 1.5);
                end
            else
                text(0.2, 0.5, 'Not available', 'FontSize', 12);
                axis off;
            end
            xlabel('k');
            ylabel('WCSS');
            title('Within-cluster sum of squares');
            grid on;
        end

        sgtitle(sprintf('%s | best k = %d | selection = %s', ...
            string(res.group_label), res.best_k, string(CLUSTER_RESULTS.meta.k_selection_method)), ...
            'Interpreter','none');

        fname = sprintf('clustering_scores__%s.png', make_valid_fieldname(res.group_label));
        try
            saveas(fig, fullfile(outDir, fname));
            fprintf('Saved clustering score plot to %s\n', fullfile(outDir, fname));
        catch
            warning('Failed to save clustering score plot for %s.', string(res.group_label));
        end

        close(fig);
    end
end
