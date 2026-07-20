function plot_wavelet_padding_comparison( ...
    x, fs, Tseg, whichSignal, W, padCfgA, padCfgB, ...
    labelA, labelB, outFile, plotFreqRange)

    % ---------- Build padded versions ----------
    [xA_pad, idxA, ~] = build_padded_signal_for_wavelet(x, Tseg, padCfgA, whichSignal);
    [xB_pad, idxB, ~] = build_padded_signal_for_wavelet(x, Tseg, padCfgB, whichSignal);

    % ---------- Wavelet parameters ----------
    Args = WaveletParameters(W.FreqMin, W.FreqMax, W.Resolution, W.WaveNumber, fs);

    % ---------- Wavelet transform ----------
    [TFR_A_pad, period, ~, coi_A_pad] = wavelet( ...
        xA_pad, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);

    [TFR_B_pad, ~, ~, coi_B_pad] = wavelet( ...
        xB_pad, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);

    % ---------- Crop back to original signal support ----------
    TFR_A = TFR_A_pad(:, idxA);
    TFR_B = TFR_B_pad(:, idxB);

    coi_A = coi_A_pad(idxA);
    coi_B = coi_B_pad(idxB);

    Freq = 1 ./ period;
    t = (0:numel(x)-1) / fs;

    % ---------- Power maps ----------
    Pow_A = abs(TFR_A).^2;
    Pow_B = abs(TFR_B).^2;

    % Log scale for readability
    Pow_A_plot = log10(Pow_A + eps);
    Pow_B_plot = log10(Pow_B + eps);
    Diff_plot  = Pow_B_plot - Pow_A_plot;

    % ---------- COI as frequency ----------
    coi_freq_A = 1 ./ coi_A(:);
    coi_freq_B = 1 ./ coi_B(:);

    % ---------- Shared color scales ----------
    clim_min = min([Pow_A_plot(:); Pow_B_plot(:)], [], 'omitnan');
    clim_max = max([Pow_A_plot(:); Pow_B_plot(:)], [], 'omitnan');

    diff_abs = max(abs(Diff_plot(:)), [], 'omitnan');
    if isempty(diff_abs) || isnan(diff_abs) || diff_abs == 0
        diff_abs = 1;
    end

    % ---------- Zoom windows ----------
    zoom_s = 1.0;  % first / last 1 second
    t_end = t(end);

    idx_start = t <= min(zoom_s, t_end);
    idx_end   = t >= max(0, t_end - zoom_s);

    t_start = t(idx_start);
    t_endwin = t(idx_end);

    % ---------- Figure ----------
    fig = figure('Visible','off','Color','w','Position',[100 100 1400 1400]);

    % ===================== START OF SIGNAL =====================

    % Row 1: start | reference
    subplot(6,1,1);
    imagesc(t_start, Freq, Pow_A_plot(:, idx_start));
    axis xy;
    caxis([clim_min clim_max]);
    colorbar;
    hold on;
    plot(t_start, coi_freq_A(idx_start), 'w', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(sprintf('Start of signal | %s', labelA), 'Interpreter','none');
    ylim(plotFreqRange);
    box on; grid on;

    % Row 2: start | current
    subplot(6,1,2);
    imagesc(t_start, Freq, Pow_B_plot(:, idx_start));
    axis xy;
    caxis([clim_min clim_max]);
    colorbar;
    hold on;
    plot(t_start, coi_freq_B(idx_start), 'w', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(sprintf('Start of signal | %s', labelB), 'Interpreter','none');
    ylim(plotFreqRange);
    box on; grid on;

    % Row 3: start | difference
    subplot(6,1,3);
    imagesc(t_start, Freq, Diff_plot(:, idx_start));
    axis xy;
    caxis([-diff_abs diff_abs]);
    colorbar;
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(sprintf('Start difference (log power): %s - %s', labelB, labelA), 'Interpreter','none');
    ylim(plotFreqRange);
    box on; grid on;

    % ===================== END OF SIGNAL =====================

    % Row 4: end | reference
    subplot(6,1,4);
    imagesc(t_endwin, Freq, Pow_A_plot(:, idx_end));
    axis xy;
    caxis([clim_min clim_max]);
    colorbar;
    hold on;
    plot(t_endwin, coi_freq_A(idx_end), 'w', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(sprintf('End of signal | %s', labelA), 'Interpreter','none');
    ylim(plotFreqRange);
    box on; grid on;

    % Row 5: end | current
    subplot(6,1,5);
    imagesc(t_endwin, Freq, Pow_B_plot(:, idx_end));
    axis xy;
    caxis([clim_min clim_max]);
    colorbar;
    hold on;
    plot(t_endwin, coi_freq_B(idx_end), 'w', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(sprintf('End of signal | %s', labelB), 'Interpreter','none');
    ylim(plotFreqRange);
    box on; grid on;

    % Row 6: end | difference
    subplot(6,1,6);
    imagesc(t_endwin, Freq, Diff_plot(:, idx_end));
    axis xy;
    caxis([-diff_abs diff_abs]);
    colorbar;
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(sprintf('End difference (log power): %s - %s', labelB, labelA), 'Interpreter','none');
    ylim(plotFreqRange);
    box on; grid on;

    sgtitle('Effect of padding on wavelet transform (zoom on first and last second)', ...
        'Interpreter', 'none');

    saveas(fig, outFile);
    close(fig);
end