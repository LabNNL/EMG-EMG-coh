function plot_burst_detection_full_signal(outDir, subjID, cond, leg, mf, fs, ...
    x, x_env, burst_mask, bursts_idx, thr_values, thr_start_idx, thr_end_idx)

    fig = figure('Visible','off','Color','w','Position',[100 100 1400 700]);

    t = (0:numel(x)-1) / fs;

    % ---------- Top panel: signal + envelope + threshold ----------
    subplot(2,1,1);
    hSig = plot(t, x, 'k'); hold on;
    hEnv = plot(t, x_env, 'b', 'LineWidth', 1);

    % fprintf('Plotting signal and envelope for %s | %s | %s | %s...\n', subjID, cond, leg, mf);
    % plot threshold as piecewise constant over windows
    hThr = gobjects(numel(thr_values),1);
    for i = 1:numel(thr_values)
        x1 = (thr_start_idx(i)-1) / fs;
        x2 = (thr_end_idx(i)-1) / fs;
        hThr(i) = line([x1 x2], [thr_values(i) thr_values(i)], ...
            'Color', 'r', 'LineStyle', '--', 'LineWidth', 1.2);
    end

    yl = ylim;
    for iB = 1:size(bursts_idx,1)
        x1 = (bursts_idx(iB,1)-1) / fs;
        x2 = (bursts_idx(iB,2)-1) / fs;
        patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], ...
            [0.85 0.85 0.85], ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 0.35, ...
            'HandleVisibility', 'off');
    end

    uistack(hSig, 'top');      % bring signal above patches
    uistack(hEnv, 'top');      % then envelope above signal
    uistack(hThr, 'top');      % finally threshold above everything

    xlabel('Time (s)');
    ylabel('Amplitude');
    title(sprintf('%s | %s | %s | %s', subjID, cond, leg, mf), 'Interpreter','none');

    if ~isempty(hThr)
        legend([hSig hEnv hThr(1)], {'Signal','Envelope','Threshold'}, 'Location','best');
    else
        legend([hSig hEnv], {'Signal','Envelope'}, 'Location','best');
    end

    grid on;
    % fprintf('Finished plotting signal and envelope for %s | %s | %s | %s.\n', subjID, cond, leg, mf);
    % ---------- Bottom panel: binary burst mask ----------
    subplot(2,1,2);
    stairs(t, double(burst_mask), 'LineWidth', 1);
    ylim([-0.1 1.1]);
    xlabel('Time (s)');
    ylabel('Burst mask');
    title('Detected bursts (binary mask)');
    grid on;
    % fprintf('Finished plotting burst mask for %s | %s | %s | %s.\n', subjID, cond, leg, mf);
    fname = sprintf('%s__%s__%s__%s__burst_detection.png', subjID, cond, leg, mf);
    exportgraphics(fig, fullfile(outDir, fname), 'Resolution', 150);
    % fprintf('Exported burst detection plot for %s | %s | %s | %s to %s.\n', subjID, cond, leg, mf, fullfile(outDir, fname));
    close(fig);
end