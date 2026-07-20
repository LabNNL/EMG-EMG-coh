function plot_burst_qc_signal_cluster_final(subjID, cond, leg, mf, fs, x, x_env, bursts_idx, ...
    burst_keep, burst_reason, outDir, C)

    fig = figure('Visible','off','Color','w','Position',[100 100 1400 700]);
    t = (0:numel(x)-1)/fs;

    includeColor = C.plotting.colors.include;
    excludeColor = C.plotting.colors.exclude_cluster_based;

    if isfield(C, 'plotting') && isfield(C.plotting, 'AlphaTransparency') && ...
            ~isempty(C.plotting.AlphaTransparency)
        faceAlpha = C.plotting.AlphaTransparency;
    else
        faceAlpha = 0.35;
    end

    subplot(2,1,1);
    plot(t, x, 'k'); hold on;
    if ~isempty(x_env)
        plot(t, x_env, 'b', 'LineWidth', 1);
    end
    yl = ylim;

    for iB = 1:size(bursts_idx,1)
        x1 = (bursts_idx(iB,1)-1)/fs;
        x2 = (bursts_idx(iB,2)-1)/fs;

        if iB <= numel(burst_keep) && burst_keep(iB)
            fc = includeColor;
        else
            fc = excludeColor;
        end

        patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], fc, ...
            'EdgeColor','none', 'FaceAlpha', faceAlpha);
    end

    uistack(findobj(gca,'Type','line'),'top');
    title(sprintf('%s | %s | %s | %s', subjID, cond, leg, mf), 'Interpreter','none');
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;

    subplot(2,1,2);
    stairs(t, zeros(size(t)), 'w'); hold on;
    ylim([-0.1 1.1]);

    for iB = 1:size(bursts_idx,1)
        x1 = (bursts_idx(iB,1)-1)/fs;
        x2 = (bursts_idx(iB,2)-1)/fs;

        if iB <= numel(burst_keep)
            yv = double(burst_keep(iB));
        else
            yv = 0;
        end

        if yv == 1
            col = includeColor;
        else
            col = excludeColor;
        end

        plot([x1 x2], [yv yv], 'LineWidth', 6, 'Color', col);
    end

    yticks([0 1]);
    yticklabels({'reject','keep'});
    xlabel('Time (s)');
    ylabel('Decision');
    title('Burst-level decision from clustering');
    grid on;

    sgtitle(sprintf('%s | rejected bursts: %d / %d', ...
        mf, sum(~burst_keep), numel(burst_keep)), 'Interpreter','none');

    fname = sprintf('ClusterQC_%s_%s_%s_%s.png', subjID, cond, leg, mf);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end