function plot_pooled_whole_signal_normalized_coherence(inFile, outDir, datasetName, FreqMin_this, FreqMax_this, W)

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    L = load(inFile);
    varNames = fieldnames(L);

    if isfield(L, 'FINAL_PAIRED_SIGNALS')
        FINAL_PAIRED_SIGNALS = L.FINAL_PAIRED_SIGNALS;
    else
        idx = find(startsWith(varNames, 'FINAL_PAIRED_SIGNALS'), 1, 'first');
        if isempty(idx)
            error('No variable starting with FINAL_PAIRED_SIGNALS found in %s', inFile);
        end
        FINAL_PAIRED_SIGNALS = L.(varNames{idx});
    end

    subjects = fieldnames(FINAL_PAIRED_SIGNALS);

    nTimeNorm = 1000;
    allMaps = [];
    cycleBoundaryDensity = zeros(1, nTimeNorm);

    nAccepted = 0;

    for iS = 1:numel(subjects)
        subjID = subjects{iS};
        conds = fieldnames(FINAL_PAIRED_SIGNALS.(subjID));

        for ic = 1:numel(conds)
            cond = conds{ic};
            legs = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond));

            for il = 1:numel(legs)
                leg = legs{il};
                pairNames = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg));

                for ip = 1:numel(pairNames)
                    pairName = pairNames{ip};
                    P = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                    if ~isfield(P, 'included_after_crosstalk') || ~P.included_after_crosstalk
                        continue;
                    end
                    if ~isfield(P, 'final_concatenated_signal_1') || ~isfield(P, 'final_concatenated_signal_2')
                        continue;
                    end
                    if ~isfield(P, 'final_cycle_segments_table') || isempty(P.final_cycle_segments_table)
                        continue;
                    end

                    x1 = P.final_concatenated_signal_1(:);
                    x2 = P.final_concatenated_signal_2(:);
                    fs = P.fs;
                    Tseg = P.final_cycle_segments_table;

                    if isempty(x1) || isempty(x2) || numel(x1) < 20 || numel(x2) < 20
                        continue;
                    end

                    % Optional padding, same helper as before
                    [x1_for_wav, idx_orig_1, ~] = build_padded_signal_for_wavelet(x1, Tseg, W.padding, 1);
                    [x2_for_wav, idx_orig_2, ~] = build_padded_signal_for_wavelet(x2, Tseg, W.padding, 2);

                    % Wavelet
                    Args = WaveletParameters(FreqMin_this, FreqMax_this, W.Resolution, W.WaveNumber, fs);

                    [Wx1_pad, period, ~, coi1_pad] = wavelet(x1_for_wav, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);
                    [Wx2_pad, ~,      ~, coi2_pad] = wavelet(x2_for_wav, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);

                    Wx1 = Wx1_pad(:, idx_orig_1);
                    Wx2 = Wx2_pad(:, idx_orig_2);
                    coi1 = coi1_pad(idx_orig_1);
                    coi2 = coi2_pad(idx_orig_2);

                    Freq = 1 ./ period;

                    % Proper smoothed whole-signal wavelet coherence
                    Coh = compute_smoothed_wavelet_coherence(Wx1, Wx2, Freq);

                    % COI mask
                    nFreq = numel(Freq);
                    nTime = size(Coh,2);

                    coi_pair = min(coi1(:)', coi2(:)');
                    coi_freq = 1 ./ coi_pair;

                    COI_mask = false(nFreq, nTime);
                    for t = 1:nTime
                        COI_mask(:,t) = Freq < coi_freq(t);
                    end
                    Coh(COI_mask) = NaN;

                    % Interpolate to normalized full-signal time axis (0..100%)
                    tOrig = linspace(0, 100, nTime);
                    tNorm = linspace(0, 100, nTimeNorm);

                    Coh_norm = interp2( ...
                        tOrig, Freq(:), Coh, ...
                        tNorm, Freq(:), ...
                        'linear', NaN);

                    allMaps(:,:,end+1) = Coh_norm; %#ok<AGROW>
                    nAccepted = nAccepted + 1;

                    % Cycle boundary density on normalized full-signal axis
                    nTotal = numel(x1);
                    endIdx = Tseg.final_concat_end_idx_signal1(:);
                    endIdx = endIdx(isfinite(endIdx) & endIdx >= 1 & endIdx <= nTotal);

                    if ~isempty(endIdx)
                        boundaryPct = 100 * endIdx / nTotal;
                        boundaryBins = round(1 + (nTimeNorm-1) * boundaryPct / 100);
                        boundaryBins = max(1, min(nTimeNorm, boundaryBins));
                        cycleBoundaryDensity(boundaryBins) = cycleBoundaryDensity(boundaryBins) + 1;
                    end
                end
            end
        end
    end

    if isempty(allMaps)
        warning('No valid whole-signal coherence maps could be computed for %s.', datasetName);
        return;
    end

    meanMap = mean(allMaps, 3, 'omitnan');

    % Mean over time for side diagnostic
    meanOverFreq = mean(meanMap, 1, 'omitnan');

    tNorm = linspace(0,100,nTimeNorm);

    % Zoom windows in normalized full-signal time
    edgePct = 10;   % first / last 10%
    idx_start = tNorm <= edgePct;
    idx_end   = tNorm >= (100 - edgePct);

    t_start = tNorm(idx_start);
    t_end   = tNorm(idx_end);

    meanOverFreq_start = meanOverFreq(idx_start);
    meanOverFreq_end   = meanOverFreq(idx_end);

    fig = figure('Visible','off','Color','w','Position',[100 100 1300 900]);

    % ===================== START OF SIGNAL =====================
    subplot(4,1,1);
    imagesc(t_start, Freq, meanMap(:, idx_start));
    axis xy;
    xlabel('Normalized full-signal time (%)');
    ylabel('Frequency (Hz)');
    title(sprintf('Start of full signal (0-%d%%) | %s | n=%d signals', ...
        edgePct, datasetName, nAccepted), 'Interpreter', 'none');
    colorbar;
    caxis([0 1]);
    hold on;

    bd_start = cycleBoundaryDensity(idx_start);
    if any(bd_start > 0)
        bd_start = bd_start / max(bd_start);
        yy = FreqMin_this + 0.05*(FreqMax_this-FreqMin_this) + bd_start * 0.12*(FreqMax_this-FreqMin_this);
        plot(t_start, yy, 'w-', 'LineWidth', 1.5);
    end

    subplot(4,1,2);
    plot(t_start, meanOverFreq_start, 'k-', 'LineWidth', 2);
    xlabel('Normalized full-signal time (%)');
    ylabel('Mean coherence');
    title('Frequency-averaged coherence | start of signal');
    ylim([0 1]);
    grid on; box on;

    % ===================== END OF SIGNAL =====================
    subplot(4,1,3);
    imagesc(t_end, Freq, meanMap(:, idx_end));
    axis xy;
    xlabel('Normalized full-signal time (%)');
    ylabel('Frequency (Hz)');
    title(sprintf('End of full signal (%d-100%%) | %s', ...
        100-edgePct, datasetName), 'Interpreter', 'none');
    colorbar;
    caxis([0 1]);
    hold on;

    bd_end = cycleBoundaryDensity(idx_end);
    if any(bd_end > 0)
        bd_end = bd_end / max(bd_end);
        yy = FreqMin_this + 0.05*(FreqMax_this-FreqMin_this) + bd_end * 0.12*(FreqMax_this-FreqMin_this);
        plot(t_end, yy, 'w-', 'LineWidth', 1.5);
    end

    subplot(4,1,4);
    plot(t_end, meanOverFreq_end, 'k-', 'LineWidth', 2);
    xlabel('Normalized full-signal time (%)');
    ylabel('Mean coherence');
    title('Frequency-averaged coherence | end of signal');
    ylim([0 1]);
    grid on; box on;

    sgtitle(sprintf('Pooled whole-signal coherence QC | edge zooms | %s', datasetName), ...
        'Interpreter', 'none');

    saveas(fig, fullfile(outDir, sprintf('POOLED_WHOLE_SIGNAL_COHERENCE_EDGE_ZOOM_%s.png', char(datasetName))));
    close(fig);

    fprintf('Saved pooled whole-signal edge-zoom coherence QC in:\n%s\n', outDir);
end

function Coh = compute_smoothed_wavelet_coherence(Wx1, Wx2, Freq)

    % Cross / auto spectra
    Wxy = Wx1 .* conj(Wx2);
    Sxx = abs(Wx1).^2;
    Syy = abs(Wx2).^2;

    % Light smoothing in time and frequency
    % Time smoothing window in samples
    timeWin = 25;

    % Frequency smoothing window in bins
    freqWin = 3;

    Wxy_s = smooth_tf_complex(Wxy, timeWin, freqWin);
    Sxx_s = smooth_tf_real(Sxx, timeWin, freqWin);
    Syy_s = smooth_tf_real(Syy, timeWin, freqWin);

    Coh = abs(Wxy_s).^2 ./ (Sxx_s .* Syy_s);
    Coh(~isfinite(Coh)) = NaN;
    Coh(Coh < 0) = 0;
    Coh(Coh > 1) = 1;
end

function Xs = smooth_tf_real(X, timeWin, freqWin)

    Xs = movmean(X, timeWin, 2, 'omitnan');

    if freqWin > 1
        kernel = ones(freqWin,1) / freqWin;
        Xs = conv2(Xs, kernel, 'same');
    end
end

function Xs = smooth_tf_complex(X, timeWin, freqWin)

    Xr = movmean(real(X), timeWin, 2, 'omitnan');
    Xi = movmean(imag(X), timeWin, 2, 'omitnan');

    if freqWin > 1
        kernel = ones(freqWin,1) / freqWin;
        Xr = conv2(Xr, kernel, 'same');
        Xi = conv2(Xi, kernel, 'same');
    end

    Xs = Xr + 1i*Xi;
end
