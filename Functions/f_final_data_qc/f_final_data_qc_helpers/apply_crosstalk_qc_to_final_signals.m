function [S, Tsum, CROSSTALK_QC_TABLE, CROSSTALK_QC_SUSPICIOUS] = ...
    apply_crosstalk_qc_to_final_signals(S, Tsum, C)

    XTK = C.f_final_signals.crosstalk;
    bandSuffixes = lower(string(fieldnames(C.f_final_signals.params.wavelet_contamination_qc.freq_bands)))';

    if ~exist(XTK.out_dir, 'dir'), mkdir(XTK.out_dir); end
    if ~exist(XTK.plot_dir, 'dir'), mkdir(XTK.plot_dir); end

    if height(Tsum) > 0
        Tsum.excluded_by_crosstalk = false(height(Tsum),1);
        Tsum.crosstalk_reason = repmat("", height(Tsum),1);

        Tsum.included_after_crosstalk = Tsum.included_for_analysis;
        for b = bandSuffixes
            Tsum.("included_after_crosstalk_" + b) = Tsum.("included_for_analysis_" + b);
        end
    end

    ROWS = {};
    ri = 0;

    subjFields = fieldnames(S);

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};
        age_group = subject_to_group(subjID, C);

        if ~matches_filter(age_group, XTK.target_age_groups)
            continue;
        end

        condFields = fieldnames(S.(subjID));
        for ic = 1:numel(condFields)
            cond = condFields{ic};

            if ~matches_filter(cond, XTK.target_conditions)
                continue;
            end

            legFields = fieldnames(S.(subjID).(cond));
            for il = 1:numel(legFields)
                leg = legFields{il};

                if ~matches_filter(leg, XTK.target_legs)
                    continue;
                end

                pairFields = fieldnames(S.(subjID).(cond).(leg));

                for ip = 1:numel(pairFields)
                    pairName = pairFields{ip};
                    P = S.(subjID).(cond).(leg).(pairName);

                    % ---------- Default: keep original inclusion unless cross-talk excludes it ----------
                    P.excluded_by_crosstalk = false;
                    P.crosstalk_reason = "";
                    P.included_after_crosstalk = P.included_for_analysis;

                    if isfield(P, 'band_specific')
                        bandNames = fieldnames(P.band_specific);
                        for ib = 1:numel(bandNames)
                            band = bandNames{ib};

                            P.band_specific.(band).excluded_by_crosstalk = false;
                            P.band_specific.(band).crosstalk_reason = "";
                            P.band_specific.(band).included_after_crosstalk = ...
                                P.band_specific.(band).included_for_analysis;
                        end
                    end

                    S.(subjID).(cond).(leg).(pairName) = P;

                    if ~matches_filter(pairName, XTK.target_pairs)
                        continue;
                    end

                    pairSuspicious = false;
                    pairReasons = strings(0,1);

                    for im = 1:numel(XTK.analysis_modes)
                        mode = string(XTK.analysis_modes(im));

                        [x1, x2, ok, sourceNote] = get_signals_for_mode(P, mode);
                        if ~ok || isempty(x1) || isempty(x2)
                            continue;
                        end

                        fs = P.fs;
                        x1 = x1(:);
                        x2 = x2(:);

                        n = min(numel(x1), numel(x2));
                        x1 = x1(1:n);
                        x2 = x2(1:n);

                        if n < fs
                            continue;
                        end

                        M = compute_crosstalk_metrics(x1, x2, fs, XTK);
                        [suspicious, suspicion_reason] = classify_crosstalk_suspicion(M, XTK);

                        if suspicious
                            pairSuspicious = true;
                            pairReasons(end+1) = mode + ":" + string(suspicion_reason);
                        end

                        ri = ri + 1;
                        ROWS(ri,:) = { ...
                            string(subjID), string(age_group), string(cond), string(leg), ...
                            string(pairName), string(mode), string(sourceNote), ...
                            n, fs, ...
                            M.raw_zero_lag_corr, ...
                            M.rectified_zero_lag_corr, ...
                            M.max_abs_cumulant_around_zero, ...
                            M.peak_lag_ms, ...
                            M.peak_width_ms, ...
                            M.broad_peak_width_ms, ...
                            M.central_spike_peak, ...
                            M.central_spike_lag_ms, ...
                            M.central_spike_width_ms, ...
                            M.central_spike_prominence, ...
                            M.central_spike_valid, ...
                            M.mean_coh_alpha, ...
                            M.mean_coh_beta, ...
                            M.mean_coh_gamma, ...
                            M.mean_coh_broad, ...
                            suspicious, ...
                            string(suspicion_reason) ...
                            };
                    end

                    if pairSuspicious
                        if isempty(pairReasons)
                            reasonFinal = "suspicious_crosstalk";
                        else
                            reasonFinal = strjoin(pairReasons, "+");
                        end

                        % update PairStruct
                        P.excluded_by_crosstalk = true;
                        P.crosstalk_reason = reasonFinal;
                        P.included_after_crosstalk = false;

                        if isfield(P, 'band_specific')
                            bandNames = fieldnames(P.band_specific);
                            for ib = 1:numel(bandNames)
                                band = bandNames{ib};
                                P.band_specific.(band).included_after_crosstalk = false;
                                P.band_specific.(band).excluded_by_crosstalk = true;
                                P.band_specific.(band).crosstalk_reason = reasonFinal;
                            end
                        end

                        S.(subjID).(cond).(leg).(pairName) = P;

                        % update summary rows
                        idx = string(Tsum.subject) == string(subjID) & ...
                              string(Tsum.condition) == string(cond) & ...
                              string(Tsum.leg) == string(leg) & ...
                              string(Tsum.pair_name) == string(pairName);

                        Tsum.excluded_by_crosstalk(idx) = true;
                        Tsum.crosstalk_reason(idx) = reasonFinal;

                        Tsum.included_after_crosstalk(idx) = false;
                        for b = bandSuffixes
                            Tsum.("included_after_crosstalk_" + b)(idx) = false;
                        end
                    else
                        P.excluded_by_crosstalk = false;
                        P.crosstalk_reason = "";
                        P.included_after_crosstalk = P.included_for_analysis;

                        if isfield(P, 'band_specific')
                            bandNames = fieldnames(P.band_specific);
                            for ib = 1:numel(bandNames)
                                band = bandNames{ib};
                                P.band_specific.(band).excluded_by_crosstalk = false;
                                P.band_specific.(band).crosstalk_reason = "";
                                P.band_specific.(band).included_after_crosstalk = ...
                                    P.band_specific.(band).included_for_analysis;
                            end
                        end

                        S.(subjID).(cond).(leg).(pairName) = P;
                    end
                end
            end
        end
    end

    if isempty(ROWS)
        CROSSTALK_QC_TABLE = table();
        CROSSTALK_QC_SUSPICIOUS = table();
    else
        CROSSTALK_QC_TABLE = cell2table(ROWS, 'VariableNames', { ...
            'subject','age_group','condition','leg','pair_name','analysis_mode','signal_source', ...
            'n_samples','fs', ...
            'raw_zero_lag_corr', ...
            'rectified_zero_lag_corr', ...
            'max_abs_cumulant_around_zero', ...
            'peak_lag_ms', ...
            'peak_width_ms', ...
            'broad_peak_width_ms', ...
            'central_spike_peak', ...
            'central_spike_lag_ms', ...
            'central_spike_width_ms', ...
            'central_spike_prominence', ...
            'central_spike_valid', ...
            'mean_coh_alpha', ...
            'mean_coh_beta', ...
            'mean_coh_gamma', ...
            'mean_coh_broad', ...
            'suspicious_crosstalk', ...
            'suspicion_reason'});

        CROSSTALK_QC_SUSPICIOUS = CROSSTALK_QC_TABLE(CROSSTALK_QC_TABLE.suspicious_crosstalk == true, :);
    end

    writetable(CROSSTALK_QC_TABLE, XTK.out_xlsx);
    writetable(CROSSTALK_QC_SUSPICIOUS, XTK.out_suspicious_xlsx);

    %% ---------- Optional plots ----------
    if XTK.plot.enable && ~isempty(CROSSTALK_QC_TABLE)

        fprintf('\nGenerating cross-talk QC plots...\n');

        if ~exist(XTK.plot_dir, 'dir')
            mkdir(XTK.plot_dir);
        end

        delete(fullfile(XTK.plot_dir, '*.png'));

        if XTK.plot.only_suspicious
            Tplot = CROSSTALK_QC_SUSPICIOUS;
        else
            Tplot = CROSSTALK_QC_TABLE;
        end

        if ~isempty(Tplot)
            if isempty(XTK.plot.random_seed)
                rng('shuffle');
            else
                rng(XTK.plot.random_seed);
            end

            nAvail = height(Tplot);
            nPlot = min(XTK.plot.max_plots, nAvail);
            idxPick = randperm(nAvail, nPlot);

            for i = 1:nPlot
                row = Tplot(idxPick(i), :);

                subjID   = char(row.subject);
                cond     = char(row.condition);
                leg      = char(row.leg);
                pairName = char(row.pair_name);
                mode     = string(row.analysis_mode);

                if ~isfield(S, subjID) || ...
                ~isfield(S.(subjID), cond) || ...
                ~isfield(S.(subjID).(cond), leg) || ...
                ~isfield(S.(subjID).(cond).(leg), pairName)

                    warning('Skipping cross-talk plot: missing pair %s | %s | %s | %s', ...
                        subjID, cond, leg, pairName);
                    continue;
                end

                P = S.(subjID).(cond).(leg).(pairName);
                [x1, x2, ok, ~] = get_signals_for_mode(P, mode);

                if ~ok
                    continue;
                end

                plot_crosstalk_qc_one_signal(x1, x2, P.fs, row, XTK, XTK.plot_dir);
            end
        end

        fprintf('Cross-talk QC plots saved to:\n  %s\n', XTK.plot_dir);
    end

    %% ---------- Quick recap ----------
    if ~isempty(CROSSTALK_QC_TABLE)
        fprintf('\n===================== CROSSTALK QC RECAP =====================\n');

        fprintf('\n--- By condition ---\n');
        disp(groupcounts(CROSSTALK_QC_TABLE, 'condition'));

        fprintf('\n--- By leg ---\n');
        disp(groupcounts(CROSSTALK_QC_TABLE, 'leg'));

        fprintf('\n--- Suspicious by condition ---\n');
        if ~isempty(CROSSTALK_QC_SUSPICIOUS)
            disp(groupcounts(CROSSTALK_QC_SUSPICIOUS, 'condition'));
        else
            fprintf('No suspicious signals.\n');
        end
    end

    fprintf('Cross-talk QC rows: %d\n', height(CROSSTALK_QC_TABLE));
    fprintf('Suspicious cross-talk rows: %d\n', height(CROSSTALK_QC_SUSPICIOUS));
end

function tf = matches_filter(value, filterValue)

    value = string(value);
    filterValue = string(filterValue);

    if any(lower(filterValue) == "all")
        tf = true;
    else
        tf = any(value == filterValue);
    end
end



function [x1, x2, ok, sourceNote] = get_signals_for_mode(P, analysis_mode)

    x1 = [];
    x2 = [];
    ok = false;
    sourceNote = "";

    analysis_mode = string(analysis_mode);

    switch analysis_mode
        case "overall"
            if isfield(P, 'included_for_analysis') && ~P.included_for_analysis
                sourceNote = "overall_not_included";
                return;
            end

            if isfield(P, 'final_concatenated_signal_1') && isfield(P, 'final_concatenated_signal_2')
                x1 = P.final_concatenated_signal_1;
                x2 = P.final_concatenated_signal_2;
                ok = true;
                sourceNote = "overall_final_concatenated";
            end

        otherwise
            % one of the configured frequency bands
            band = char(analysis_mode);

            if ~isfield(P, 'band_specific') || ~isfield(P.band_specific, band)
                sourceNote = "missing_band_specific";
                return;
            end

            B = P.band_specific.(band);

            if isfield(B, 'included_for_analysis') && ~B.included_for_analysis
                sourceNote = band + "_not_included";
                return;
            end

            x1 = B.final_concatenated_signal_1;
            x2 = B.final_concatenated_signal_2;
            ok = true;
            sourceNote = string(band) + "_final_concatenated";
    end
end

function M = compute_crosstalk_metrics(x1, x2, fs, XTK)

    x1 = x1(:);
    x2 = x2(:);

    n = min(numel(x1), numel(x2));
    x1 = x1(1:n);
    x2 = x2(1:n);

    % ---------- Center raw ----------
    x1c = x1 - mean(x1, 'omitnan');
    x2c = x2 - mean(x2, 'omitnan');

    % ---------- Rectified centered ----------
    x1r = abs(x1c);
    x2r = abs(x2c);
    x1r = x1r - mean(x1r, 'omitnan');
    x2r = x2r - mean(x2r, 'omitnan');

    M = struct();

    M.raw_zero_lag_corr = corr_safe(x1c, x2c);
    M.rectified_zero_lag_corr = corr_safe(x1r, x2r);

    % % ---------- Normalized cross-correlation ----------
    % maxLagSamples = round(XTK.max_lag_ms / 1000 * fs);
    % zeroLagWinSamples = max(1, round(XTK.zero_lag_window_ms / 1000 * fs));

    % [xc, lags] = xcorr(x1r, x2r, maxLagSamples, 'coeff');
    % lagMs = 1000 * lags / fs;

    % idxZeroWin = abs(lags) <= zeroLagWinSamples;

    % [M.max_abs_xcorr_around_zero, localIdx] = max(abs(xc(idxZeroWin)));
    % zeroLags = lags(idxZeroWin);
    % zeroLagMs = lagMs(idxZeroWin);

    % M.peak_lag_samples = zeroLags(localIdx);
    % M.peak_lag_ms = zeroLagMs(localIdx);

    % M.peak_width_ms = estimate_peak_width_ms(abs(xc), lagMs, localIdx, idxZeroWin);

    % M.xcorr = xc;
    % M.xcorr_lag_ms = lagMs;
    % ---------- Cumulant density function from cross-spectrum ----------
    [cumDensity, lagMs] = compute_cumulant_density_from_cpsd(x1r, x2r, fs, XTK);

    idxZeroWin = abs(lagMs) <= XTK.zero_lag_window_ms;

    [M.max_abs_cumulant_around_zero, localIdx] = max(abs(cumDensity(idxZeroWin)));
    zeroLagMs = lagMs(idxZeroWin);

    M.peak_lag_ms = zeroLagMs(localIdx);
    M.peak_lag_samples = round(M.peak_lag_ms / 1000 * fs);

    % This is the width of the whole broad mound
    M.broad_peak_width_ms = estimate_peak_width_ms(abs(cumDensity), lagMs, localIdx, idxZeroWin);

    % Detect the narrow central spike separately
    SPIKE = compute_central_spike_metrics(cumDensity, lagMs, fs, XTK);

    M.central_spike_peak = SPIKE.peak;
    M.central_spike_lag_ms = SPIKE.lag_ms;
    M.central_spike_width_ms = SPIKE.width_ms;
    M.central_spike_prominence = SPIKE.prominence;
    M.central_spike_valid = SPIKE.valid;

    M.cumulant_density = cumDensity;
    M.cumulant_lag_ms = lagMs;
    M.cumulant_broad_component = SPIKE.broad_component;
    M.cumulant_sharp_component = SPIKE.sharp_component;

    % Backward compatibility
    M.peak_width_ms = M.central_spike_width_ms;
    M.xcorr = cumDensity;
    M.xcorr_lag_ms = lagMs;

    % ---------- Coherence ----------
    [f, Cxy] = compute_mscohere_safe(x1r, x2r, fs, XTK);

    M.coherence_f = f;
    M.coherence = Cxy;

    M.mean_coh_alpha = mean_band_value(f, Cxy, XTK.freq_bands.Alpha);
    M.mean_coh_beta  = mean_band_value(f, Cxy, XTK.freq_bands.Beta);
    M.mean_coh_gamma = mean_band_value(f, Cxy, XTK.freq_bands.Gamma);
    M.mean_coh_broad = mean_band_value(f, Cxy, XTK.freq_bands.Broad);

    M.suspicion_reason = "";
end

function r = corr_safe(x, y)

    x = x(:);
    y = y(:);

    valid = isfinite(x) & isfinite(y);
    x = x(valid);
    y = y(valid);

    if numel(x) < 3 || std(x) == 0 || std(y) == 0
        r = NaN;
        return;
    end

    R = corrcoef(x, y);
    r = R(1,2);
end

function widthMs = estimate_peak_width_ms(absXc, lagMs, localIdx, idxZeroWin)

    widthMs = NaN;

    idxs = find(idxZeroWin);
    if isempty(idxs)
        return;
    end

    peakGlobalIdx = idxs(localIdx);
    peakVal = absXc(peakGlobalIdx);

    if ~isfinite(peakVal) || peakVal <= 0
        return;
    end

    halfVal = peakVal / 2;

    leftIdx = peakGlobalIdx;
    while leftIdx > 1 && absXc(leftIdx) >= halfVal
        leftIdx = leftIdx - 1;
    end

    rightIdx = peakGlobalIdx;
    while rightIdx < numel(absXc) && absXc(rightIdx) >= halfVal
        rightIdx = rightIdx + 1;
    end

    widthMs = lagMs(rightIdx) - lagMs(leftIdx);
end

function [f, Cxy] = compute_mscohere_safe(x1, x2, fs, XTK)

    winLength = max(64, round(XTK.coh_window_sec * fs));
    winLength = min(winLength, numel(x1));

    noverlap = round(XTK.coh_overlap_fraction * winLength);
    noverlap = min(noverlap, winLength - 1);

    nfft = max(256, round(XTK.coh_nfft_sec * fs));

    try
        [Cxy, f] = mscohere(x1, x2, hamming(winLength), noverlap, nfft, fs);
    catch
        warning('mscohere failed. Returning NaNs.');
        f = (0:XTK.coh_fmax)';
        Cxy = nan(size(f));
        return;
    end

    idx = f <= XTK.coh_fmax;
    f = f(idx);
    Cxy = Cxy(idx);
end

function v = mean_band_value(f, y, band)

    idx = f >= band(1) & f <= band(2);

    if ~any(idx)
        v = NaN;
    else
        v = mean(y(idx), 'omitnan');
    end
end

function [suspicious, suspicion_reason] = classify_crosstalk_suspicion(M, XTK)

    reasons = strings(0,1);

    hasNarrowCentralSpike = ...
        isfield(M, 'central_spike_valid') && M.central_spike_valid && ...
        isfinite(M.central_spike_width_ms) && ...
        M.central_spike_width_ms <= XTK.central_spike.max_width_ms && ...
        isfinite(M.central_spike_lag_ms) && ...
        abs(M.central_spike_lag_ms) <= XTK.thresholds.peak_abs_lag_ms;

    hasHighBroadbandCoherence = ...
        isfinite(M.mean_coh_broad) && ...
        M.mean_coh_broad >= XTK.thresholds.mean_coh_broad;

    hasHighSimilarity = ...
        (isfinite(M.rectified_zero_lag_corr) && abs(M.rectified_zero_lag_corr) >= XTK.thresholds.rectified_zero_lag_corr) || ...
        (isfinite(M.raw_zero_lag_corr) && abs(M.raw_zero_lag_corr) >= XTK.thresholds.raw_zero_lag_corr);

    if hasNarrowCentralSpike
        reasons(end+1) = "narrow_zero_lag_central_spike";
    end

    if hasHighBroadbandCoherence
        reasons(end+1) = "high_broadband_coherence";
    end

    if hasHighSimilarity
        reasons(end+1) = "high_zero_lag_signal_similarity";
    end

    % Strict cross-talk rule:
    % narrow zero-lag spike is required; coherence/similarity supports it.
    suspicious = hasNarrowCentralSpike && (hasHighBroadbandCoherence || hasHighSimilarity);

    if suspicious
        suspicion_reason = strjoin(reasons, "+");
    else
        if isempty(reasons)
            suspicion_reason = "none";
        else
            suspicion_reason = "review_only_" + strjoin(reasons, "+");
        end
    end
end


function plot_crosstalk_qc_one_signal(x1, x2, fs, row, XTK, outDir)

    x1 = x1(:);
    x2 = x2(:);

    n = min(numel(x1), numel(x2));
    x1 = x1(1:n);
    x2 = x2(1:n);

    x1c = x1 - mean(x1, 'omitnan');
    x2c = x2 - mean(x2, 'omitnan');

    x1r = abs(x1c);
    x2r = abs(x2c);
    x1r = x1r - mean(x1r, 'omitnan');
    x2r = x2r - mean(x2r, 'omitnan');

    M = compute_crosstalk_metrics(x1, x2, fs, XTK);

    fig = figure('Visible','off','Color','w','Position',[100 100 1000 1000], ...
        'Toolbar','none','MenuBar','none');

    tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

    % ---------- Short time trace ----------
    ax1 = nexttile;
    hold(ax1,'on');

    nShow = min(n, round(5 * fs));
    t = (0:nShow-1) / fs;

    z1 = zscore_safe(x1c(1:nShow));
    z2 = zscore_safe(x2c(1:nShow));

    plot(ax1, t, z1, 'k', 'LineWidth', 0.8);
    plot(ax1, t, z2 + 4, 'LineWidth', 0.8);

    ylabel(ax1, 'z-score + offset');
    xlabel(ax1, 'Time (s)');
    title(ax1, 'Short raw EMG trace');
    legend(ax1, {'Muscle 1','Muscle 2 + offset'}, 'Location','best');
    grid(ax1,'on');

    %% ---------- Cumulant density ----------
    ax2 = nexttile;
    plot(ax2, M.cumulant_lag_ms, M.cumulant_density, 'k', 'LineWidth', 1.2);
    hold(ax2,'on');

    % broad component
    plot(ax2, M.cumulant_lag_ms, M.cumulant_broad_component, ...
        '--', 'LineWidth', 1.0);

    % sharp residual, vertically offset for visibility
    offset = min(M.cumulant_density, [], 'omitnan');
    plot(ax2, M.cumulant_lag_ms, M.cumulant_sharp_component + offset, ...
        ':', 'LineWidth', 1.0);

    xline(ax2, 0, '--', 'LineWidth', 1.2);
    xline(ax2, -XTK.zero_lag_window_ms, ':');
    xline(ax2,  XTK.zero_lag_window_ms, ':');

    xlabel(ax2, 'Lag (ms)');
    ylabel(ax2, 'Normalized cumulant density');

    title(ax2, sprintf(['Cumulant peak lag %.2f ms | broad width %.1f ms | ' ...
        'central spike lag %.2f ms | spike width %.2f ms | prom %.2g'], ...
        M.peak_lag_ms, ...
        M.broad_peak_width_ms, ...
        M.central_spike_lag_ms, ...
        M.central_spike_width_ms, ...
        M.central_spike_prominence));

    legend(ax2, {'Cumulant density','Broad component','Sharp residual + offset'}, ...
        'Location','best');

    grid(ax2,'on');

    % ---------- Coherence ----------
    ax3 = nexttile;
    plot(ax3, M.coherence_f, M.coherence, 'k', 'LineWidth', 1.2);
    xlabel(ax3, 'Frequency (Hz)');
    ylabel(ax3, 'Magnitude-squared coherence');
    ylim(ax3, [0 1]);
    xlim(ax3, [0 XTK.coh_fmax]);
    title(ax3, sprintf('Mean coherence | Alpha %.3f | Beta %.3f | Gamma %.3f | Broad %.3f', ...
        M.mean_coh_alpha, M.mean_coh_beta, M.mean_coh_gamma, M.mean_coh_broad));
    grid(ax3,'on');

    sgtitle(sprintf('%s (%s) | %s | %s | %s \n suspicious=%d %s', ...
        string(row.subject), string(row.age_group), string(row.condition), string(row.leg), string(row.pair_name), ...
        row.suspicious_crosstalk, string(row.suspicion_reason)), ...
        'Interpreter','none');

    fname = sprintf('crosstalk_qc__%s__%s__%s__%s__%s.png', ...
        char(string(row.subject)), ...
        char(string(row.condition)), ...
        char(string(row.leg)), ...
        char(string(row.pair_name)), ...
        char(string(row.analysis_mode)));

    fname = matlab.lang.makeValidName(fname);
    fname = [fname '.png'];

    exportgraphics(fig, fullfile(outDir, fname), 'Resolution', 200);
    close(fig);
end

function z = zscore_safe(x)

    x = x(:);
    s = std(x, 'omitnan');

    if ~isfinite(s) || s == 0
        z = zeros(size(x));
    else
        z = (x - mean(x, 'omitnan')) ./ s;
    end
end

function [qxy, lagMs] = compute_cumulant_density_from_cpsd(x, y, fs, XTK)

    x = x(:);
    y = y(:);

    n = min(numel(x), numel(y));
    x = x(1:n);
    y = y(1:n);

    x = x - mean(x, 'omitnan');
    y = y - mean(y, 'omitnan');

    winLength = max(64, round(XTK.coh_window_sec * fs));
    winLength = min(winLength, n);

    noverlap = round(XTK.coh_overlap_fraction * winLength);
    noverlap = min(noverlap, winLength - 1);

    nfft = max(256, round(XTK.coh_nfft_sec * fs));

    % Two-sided cross-spectrum
    [Pxy, f] = cpsd(x, y, hamming(winLength), noverlap, nfft, fs, 'twosided');

    % Inverse Fourier transform of cross-spectrum = cumulant density
    qxy_full = real(ifft(Pxy, 'symmetric'));

    % Shift zero lag to center
    qxy_full = fftshift(qxy_full);

    % Build lag axis
    nFreq = numel(qxy_full);
    lags = (-floor(nFreq/2):ceil(nFreq/2)-1)';
    lagMs_full = 1000 * lags / fs;

    % Keep requested lag range
    keep = abs(lagMs_full) <= XTK.max_lag_ms;

    qxy = qxy_full(keep);
    lagMs = lagMs_full(keep);

    % Optional normalization for easier comparison across recordings
    denom = sqrt(var(x, 'omitnan') * var(y, 'omitnan'));
    if isfinite(denom) && denom > 0
        qxy = qxy ./ denom;
    end
end

function SPIKE = compute_central_spike_metrics(q, lagMs, fs, XTK)

    q = q(:);
    lagMs = lagMs(:);

    SPIKE = struct();
    SPIKE.peak = NaN;
    SPIKE.lag_ms = NaN;
    SPIKE.width_ms = NaN;
    SPIKE.prominence = NaN;
    SPIKE.valid = false;
    SPIKE.broad_component = nan(size(q));
    SPIKE.sharp_component = nan(size(q));

    if isempty(q) || all(~isfinite(q))
        return;
    end

    % ---------- Estimate broad component ----------
    smoothWinSamples = max(3, round(XTK.central_spike.broad_smooth_window_ms / 1000 * fs));

    if mod(smoothWinSamples, 2) == 0
        smoothWinSamples = smoothWinSamples + 1;
    end

    qBroad = movmedian(q, smoothWinSamples, 'omitnan');
    qSharp = q - qBroad;

    SPIKE.broad_component = qBroad;
    SPIKE.sharp_component = qSharp;

    % ---------- Search only around zero lag ----------
    idxSearch = abs(lagMs) <= XTK.central_spike.search_window_ms;

    if ~any(idxSearch)
        return;
    end

    qSearch = qSharp(idxSearch);
    lagSearch = lagMs(idxSearch);

    [peakAbs, localIdx] = max(abs(qSearch));

    if isempty(peakAbs) || ~isfinite(peakAbs)
        return;
    end

    peakSigned = qSearch(localIdx);
    peakLag = lagSearch(localIdx);

    % global index of central spike
    searchIdxs = find(idxSearch);
    peakGlobalIdx = searchIdxs(localIdx);

    % ---------- Estimate local baseline of sharp component ----------
    baselineIdx = abs(lagMs) >= XTK.central_spike.search_window_ms & ...
                  abs(lagMs) <= 2 * XTK.central_spike.search_window_ms;

    if any(baselineIdx)
        baseline = median(abs(qSharp(baselineIdx)), 'omitnan');
    else
        baseline = 0;
    end

    prominence = peakAbs - baseline;

    % ---------- FWHM of sharp residual peak ----------
    halfVal = peakAbs / 2;

    leftIdx = peakGlobalIdx;
    while leftIdx > 1 && abs(qSharp(leftIdx)) >= halfVal
        leftIdx = leftIdx - 1;
    end

    rightIdx = peakGlobalIdx;
    while rightIdx < numel(qSharp) && abs(qSharp(rightIdx)) >= halfVal
        rightIdx = rightIdx + 1;
    end

    widthMs = lagMs(rightIdx) - lagMs(leftIdx);

    SPIKE.peak = peakSigned;
    SPIKE.lag_ms = peakLag;
    SPIKE.width_ms = widthMs;
    SPIKE.prominence = prominence;

    SPIKE.valid = ...
        isfinite(widthMs) && ...
        isfinite(prominence) && ...
        prominence >= XTK.central_spike.min_prominence;
end
