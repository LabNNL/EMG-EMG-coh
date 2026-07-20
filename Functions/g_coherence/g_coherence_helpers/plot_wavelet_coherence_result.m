function plot_wavelet_coherence_result(R, outDir, freq_range)

    Freq = R.Freq;
    Time = R.Time_percent;
    Coherence = R.Coherence;
    Pow1 = R.PowSpec_signal1;
    Pow2 = R.PowSpec_signal2;
    seuil = R.SignificanceThreshold;

    mus1 = R.muscles{1};
    mus2 = R.muscles{2};

    idxFreq = Freq >= freq_range(1) & Freq <= freq_range(2);
    FreqPlot = Freq(idxFreq);
    Pow1Plot = Pow1(idxFreq, :);
    Pow2Plot = Pow2(idxFreq, :);
    CohPlot  = Coherence(idxFreq, :);

    fig = figure('Visible','off','Color','w','Position',[100 100 1500 850]);

    subplot(2,3,1);
    imagesc(Time, FreqPlot, Pow1Plot);
    axis xy;
    ylim(freq_range);
    yticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    box on;
    set(gca, 'Layer', 'top');
    title(sprintf('Power %s', mus1), 'Interpreter','none');
    xlabel('% Cycle'); ylabel('Frequency (Hz)');

    subplot(2,3,2);
    imagesc(Time, FreqPlot, Pow2Plot);
    axis xy;
    ylim(freq_range);
    yticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    box on;
    set(gca, 'Layer', 'top');
    title(sprintf('Power %s', mus2), 'Interpreter','none');
    xlabel('% Cycle'); ylabel('Frequency (Hz)');

    subplot(2,3,3);
    imagesc(Time, FreqPlot, CohPlot);
    axis xy;
    ylim(freq_range);
    yticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    box on;
    set(gca, 'Layer', 'top');
    title(sprintf('Coherence %s-%s', mus1, mus2), 'Interpreter','none');
    xlabel('% Cycle'); ylabel('Frequency (Hz)');
    colorbar;

    subplot(2,3,4);
    plot(Freq, mean(Coherence,2), 'k', 'LineWidth', 1.2);
    hold on;
    if ~isnan(seuil)
        yline(seuil, 'r--', 'LineWidth', 1.2);
    end
    xlim(freq_range); 
    xticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    box on;
    set(gca, 'Layer', 'top');
    ylim([0 1]);
    title('Mean coherence (full cycle)');
    xlabel('Frequency (Hz)'); ylabel('Coherence');

    subplot(2,3,5);
    plot(Freq, mean(Coherence(:, R.StanceIndices),2), 'k', 'LineWidth', 1.2);
    hold on;
    if ~isnan(seuil)
        yline(seuil, 'r--', 'LineWidth', 1.2);
    end
    xlim(freq_range); 
    xticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    box on;
    set(gca, 'Layer', 'top');
    ylim([0 1]);
    title('Mean coherence (stance)');
    xlabel('Frequency (Hz)'); ylabel('Coherence');

    subplot(2,3,6);
    plot(Freq, mean(Coherence(:, R.SwingIndices),2), 'k', 'LineWidth', 1.2);
    hold on;
    if ~isnan(seuil)
        yline(seuil, 'r--', 'LineWidth', 1.2);
    end
    xlim(freq_range); 
    xticks(unique([freq_range(1), 10:10:freq_range(2), freq_range(2)]));
    box on;
    set(gca, 'Layer', 'top');

    ylim([0 1]);
    title('Mean coherence (swing)');
    xlabel('Frequency (Hz)'); ylabel('Coherence');

    sgtitle(sprintf('%s | %s | %s | %s | cycles=%d', ...
        R.subject, R.condition, R.leg, R.pair_name, R.n_cycles_used), ...
        'Interpreter','none');

    fname = sprintf('coherence__%s__%s__%s__%s.png', ...
        R.subject, R.condition, R.leg, R.pair_name);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end
