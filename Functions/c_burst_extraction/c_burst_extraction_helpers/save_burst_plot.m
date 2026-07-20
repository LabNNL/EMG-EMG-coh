function save_burst_plot(outDir, subjID, cond, leg, mf, minute, x, x_env, thr, bursts_local, fs)
    fig = figure('Visible','off','Color','w','Position',[100 100 1200 500]);

    t = (0:numel(x)-1) / fs;

    plot(t, x, 'k'); hold on;
    plot(t, x_env, 'b', 'LineWidth', 1.2);
    yline(thr, '--r', 'Threshold');

    yl = ylim;
    for iB = 1:size(bursts_local,1)
        x1 = (bursts_local(iB,1)-1) / fs;
        x2 = (bursts_local(iB,2)-1) / fs;
        patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], ...
            [0.85 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.35);
    end

    uistack(findobj(gca, 'Type', 'line'), 'top');

    xlabel('Time (s)');
    ylabel('Amplitude');
    title(sprintf('%s | %s | %s | %s | minute %d', subjID, cond, leg, mf, minute), ...
        'Interpreter', 'none');
    legend({'Signal','Envelope','Threshold'}, 'Location', 'best');
    grid on;

    fname = sprintf('%s__%s__%s__%s__min%02d_bursts.png', subjID, cond, leg, mf, minute);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end
