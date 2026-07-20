function preprocessing_qc_plots(P, plotCandidates, PNG_QC_DIR)
%PREPROCESSING_QC_PLOTS Generate QC plots for random samples of raw vs preprocessed EMG signals.
% This function creates time-domain and PSD comparison plots for a random subset of the data,
% helping to visually verify the effects of preprocessing steps.
% Inputs:
%   P - struct with preprocessing parameters (e.g. plot_seconds, n_random_examples)
%   plotCandidates - cell array with rows of {subjID, cond, leg, muscle, fs, raw_sig, filt_sig, rect_sig}
% Output:
%   Saves QC plots as PNG files in the specified directory.         

    nCand = size(plotCandidates,1);
    nPick = min(P.n_random_examples, nCand);

    rng(0); % reproducible
    pickIdx = randperm(nCand, nPick);

    fprintf('\nGenerating %d random QC plots (time + PSD)...\n', nPick);

    for ii = 1:nPick
        row = plotCandidates(pickIdx(ii),:);
        subjID = row{1}; cond = row{2}; leg = row{3}; mf = row{4};
        fs = row{5}; x = row{6}; y_filt = row{7}; y_rect = row{8};

        nSamp = min(numel(x), round(P.plot_seconds*fs));
        nSamp = min([nSamp, numel(y_filt), numel(y_rect)]);
        if nSamp < 10, continue; end

        t = (0:nSamp-1)/fs;

        fig = figure('Visible','off','Color','w');

        % ---- Time domain (3 traces) ----
        subplot(2,1,1);
        plot(t, x(1:nSamp), 'LineWidth', 0.8); hold on;
        plot(t, y_filt(1:nSamp), 'LineWidth', 0.8);
        plot(t, y_rect(1:nSamp), 'LineWidth', 0.8);
        xlabel('Time (s)'); ylabel('Amplitude');
        title(sprintf('Time | %s | %s | %s | %s', subjID, cond, leg, mf), 'Interpreter','none');
        legend({'raw (mean-removed)','filtered','rectified'}, 'Location','best');
        grid on;

        % ---- PSD (raw vs filtered) ----
        subplot(2,1,2);
        % Welch PSD settings (simple + stable)
        win = round(0.4*fs);      % 400 ms
        ov  = round(0.5*win);     % 50% overlap
        nfft = max(1024, 2^nextpow2(win));

        [Pxx,freq]  = pwelch(x(1:nSamp), win, ov, nfft, fs);
        [Pyy,~]     = pwelch(y_filt(1:nSamp), win, ov, nfft, fs);

        plot(freq, 10*log10(Pxx), 'LineWidth', 0.8); hold on;
        plot(freq, 10*log10(Pyy), 'LineWidth', 0.8);
        xlim([0 500]);
        xlabel('Frequency (Hz)'); ylabel('Power (dB)');
        title('PSD (Welch)'); grid on;
        legend({'raw','filtered'}, 'Location','best');

        outName = sprintf('%02d_%s_%s_%s_%s_QC_time_psd.png', ii, subjID, cond, leg, mf);
        outPath = fullfile(PNG_QC_DIR, outName);
        saveas(fig, outPath);
        close(fig);
    end

    fprintf('Saved QC plots to: %s\n', PNG_QC_DIR);
end