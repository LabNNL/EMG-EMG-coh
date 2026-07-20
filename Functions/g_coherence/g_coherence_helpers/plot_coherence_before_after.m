function plot_coherence_before_after(R, outDir, freq_range)

    Freq = R.Freq;
    Time = R.Time_percent;
    Coherence = R.Coherence;
    Coherence_sig = R.Coherence_sig;

    seuil = R.SignificanceThreshold;

    idxFreq = Freq >= freq_range(1) & Freq <= freq_range(2);
    FreqPlot = Freq(idxFreq);

    CohRawPlot = Coherence(idxFreq, :);
    CohSigPlot = Coherence_sig(idxFreq, :);

    mean_raw_full = mean(Coherence, 2, 'omitnan');
    mean_sig_full = mean(Coherence_sig, 2, 'omitnan');

    mean_raw_stance = mean(Coherence(:, R.StanceIndices), 2, 'omitnan');
    mean_sig_stance = mean(Coherence_sig(:, R.StanceIndices), 2, 'omitnan');

    mean_raw_swing = mean(Coherence(:, R.SwingIndices), 2, 'omitnan');
    mean_sig_swing = mean(Coherence_sig(:, R.SwingIndices), 2, 'omitnan');

    fig = figure('Visible','off','Color','w','Position',[100 100 1600 900]);

    % ===== Raw coherence map =====
    subplot(2,3,1);
    imagesc(Time, FreqPlot, CohRawPlot);
    axis xy;
    xlim([0 100]);
    ylim(freq_range);
    xticks([0 20 40 60 80 100]);
    yticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    box on;
    set(gca, 'Layer','top');
    title('Raw coherence map');
    xlabel('% Cycle');
    ylabel('Frequency (Hz)');
    colorbar;

    % ===== Thresholded coherence map =====
    subplot(2,3,2);
    imagesc(Time, FreqPlot, CohSigPlot);
    axis xy;
    xlim([0 100]);
    ylim(freq_range);
    xticks([0 20 40 60 80 100]);
    yticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    box on;
    set(gca, 'Layer','top');
    title('Thresholded coherence map');
    xlabel('% Cycle');
    ylabel('Frequency (Hz)');
    colorbar;

    % ===== Difference / removed part =====
    subplot(2,3,3);
    imagesc(Time, FreqPlot, CohRawPlot - CohSigPlot);
    axis xy;
    xlim([0 100]);
    ylim(freq_range);
    xticks([0 20 40 60 80 100]);
    yticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    box on;
    set(gca, 'Layer','top');
    title('Removed by threshold');
    xlabel('% Cycle');
    ylabel('Frequency (Hz)');
    colorbar;

    % ===== Full-cycle spectrum =====
    subplot(2,3,4); hold on;
    plot(Freq, mean_raw_full, 'k', 'LineWidth', 1.5, 'DisplayName', 'Raw');
    plot(Freq, mean_sig_full, 'r', 'LineWidth', 1.5, 'DisplayName', 'After threshold subtraction');
    if ~isnan(seuil)
        yline(seuil, 'b--', 'LineWidth', 1.2, 'DisplayName', 'Threshold');
    end
    xlim(freq_range);
    xticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    ylim([0 1]);
    box on;
    set(gca, 'Layer','top');
    title('Full-cycle spectrum');
    xlabel('Frequency (Hz)');
    ylabel('Coherence');
    legend('Location','best');

    % ===== Stance spectrum =====
    subplot(2,3,5); hold on;
    plot(Freq, mean_raw_stance, 'k', 'LineWidth', 1.5, 'DisplayName', 'Raw');
    plot(Freq, mean_sig_stance, 'r', 'LineWidth', 1.5, 'DisplayName', 'After threshold subtraction');
    if ~isnan(seuil)
        yline(seuil, 'b--', 'LineWidth', 1.2, 'DisplayName', 'Threshold');
    end
    xlim(freq_range);
    xticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    ylim([0 1]);
    box on;
    set(gca, 'Layer','top');
    title('Stance spectrum');
    xlabel('Frequency (Hz)');
    ylabel('Coherence');

    % ===== Swing spectrum =====
    subplot(2,3,6); hold on;
    plot(Freq, mean_raw_swing, 'k', 'LineWidth', 1.5, 'DisplayName', 'Raw');
    plot(Freq, mean_sig_swing, 'r', 'LineWidth', 1.5, 'DisplayName', 'After threshold subtraction');
    if ~isnan(seuil)
        yline(seuil, 'b--', 'LineWidth', 1.2, 'DisplayName', 'Threshold');
    end
    xlim(freq_range);
    xticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    ylim([0 1]);
    box on;
    set(gca, 'Layer','top');
    title('Swing spectrum');
    xlabel('Frequency (Hz)');
    ylabel('Coherence');

    sgtitle(sprintf('%s | %s | %s | %s | before vs after threshold', ...
        R.subject, R.condition, R.leg, R.pair_name), ...
        'Interpreter','none');

    fname = sprintf('coherence_before_after__%s__%s__%s__%s.png', ...
        R.subject, R.condition, R.leg, R.pair_name);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end
