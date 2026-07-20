function plot_random_coi_examples(COI_EXAMPLES, W, PLOT)

    if isempty(COI_EXAMPLES)
        warning('No COI examples available to plot.');
        return;
    end

    if isfield(PLOT, 'out_dir') && ~isempty(PLOT.out_dir)
        outDir = PLOT.out_dir;
    elseif isfield(PLOT, 'dir') && ~isempty(PLOT.dir)
        outDir = PLOT.dir;
    else
        error('No valid output directory found in PLOT.out_dir or PLOT.dir.');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    if isfield(PLOT, 'delete_old_png') && PLOT.delete_old_png
        oldPng = dir(fullfile(outDir, '*.png'));
        for k = 1:numel(oldPng)
            delete(fullfile(oldPng(k).folder, oldPng(k).name));
        end
    end

    if isfield(PLOT, 'random_seed') && ~isempty(PLOT.random_seed)
        rng(PLOT.random_seed);
    end

    nAvail = numel(COI_EXAMPLES);
    nToPlot = min(PLOT.n_random, nAvail);
    idx = randperm(nAvail, nToPlot);

    for i = 1:nToPlot
        E = COI_EXAMPLES(idx(i));

        Args1 = WaveletParameters(W.FreqMin, W.FreqMax, W.Resolution, W.WaveNumber, E.fs);
        [~, period1, ~, coi1] = wavelet(E.x1, Args1.DT, Args1.Pad, Args1.DJ, Args1.S0, Args1.J1, Args1.Mother, Args1.Cycles);

        Args2 = WaveletParameters(W.FreqMin, W.FreqMax, W.Resolution, W.WaveNumber, E.fs);
        [~, period2, ~, coi2] = wavelet(E.x2, Args2.DT, Args2.Pad, Args2.DJ, Args2.S0, Args2.J1, Args2.Mother, Args2.Cycles);

        freq1 = 1 ./ period1;
        freq2 = 1 ./ period2;

        coi_freq1 = 1 ./ coi1(:);
        coi_freq2 = 1 ./ coi2(:);

        coi_freq1(~isfinite(coi_freq1)) = NaN;
        coi_freq2(~isfinite(coi_freq2)) = NaN;

        coi_freq1(coi_freq1 > W.FreqMax) = W.FreqMax;
        coi_freq2(coi_freq2 > W.FreqMax) = W.FreqMax;

        t1 = (0:numel(E.x1)-1) / E.fs;
        t2 = (0:numel(E.x2)-1) / E.fs;

        fig = figure('Visible','off','Color','w','Position',[100 100 1200 700]);

        % ===================== Muscle 1 =====================
        subplot(2,1,1);
        hold on;

        plot(t1, coi_freq1, 'r', 'LineWidth', 2);

        yline(W.FreqMin, 'k--', 'LineWidth', 1);
        yline(W.FreqMax, 'k--', 'LineWidth', 1);

        %ylim([0 max(W.FreqMax, max(coi_freq1(~isinf(coi_freq1) & ~isnan(coi_freq1)))) * 1.05]);
        ylim([W.FreqMin W.FreqMax]);
        xlim([t1(1) t1(end)]);
        xlabel('Time (s)');
        ylabel('Frequency (Hz)');
        title(sprintf('%s | Muscle 1: %s', E.pair_name, E.muscle1_name), 'Interpreter','none');
        grid on; box on;

        % ===================== Muscle 2 =====================
        subplot(2,1,2);
        hold on;

        plot(t2, coi_freq2, 'b', 'LineWidth', 2);

        yline(W.FreqMin, 'k--', 'LineWidth', 1);
        yline(W.FreqMax, 'k--', 'LineWidth', 1);

        ylim([W.FreqMin W.FreqMax]);
        xlim([t2(1) t2(end)]);
        xlabel('Time (s)');
        ylabel('Frequency (Hz)');
        title(sprintf('%s | Muscle 2: %s', E.pair_name, E.muscle2_name), 'Interpreter','none');
        grid on; box on;

        sgtitle(sprintf('COI example | %s | %s | %s | %s', ...
            E.subject, E.condition, E.leg, E.pair_name), ...
            'Interpreter','none');

        fname = sprintf('COI__%s__%s__%s__%s.png', ...
            E.subject, E.condition, E.leg, E.pair_name);
        saveas(fig, fullfile(outDir, fname));
        close(fig);
    end

    fprintf('Saved %d random COI example plots in:\n%s\n', nToPlot, outDir);
end