function powerMetrics = compute_pair_poi_power_metrics( ...
    PowSpec_s1, PowSpec_s2, Freq, pairName, C, FreqBands_this)

    powerMetrics = struct();

    powerMetrics.power_poi_signal1 = struct();
    powerMetrics.power_poi_signal2 = struct();
    powerMetrics.power_poi_mean_both = struct();
    powerMetrics.power_poi_log_mean_both = struct();
    powerMetrics.power_poi_ratio_1over2 = struct();

    for bandName = fieldnames(FreqBands_this)'
        band = bandName{1};
        powerMetrics.power_poi_signal1.(band) = NaN;
        powerMetrics.power_poi_signal2.(band) = NaN;
        powerMetrics.power_poi_mean_both.(band) = NaN;
        powerMetrics.power_poi_log_mean_both.(band) = NaN;
        powerMetrics.power_poi_ratio_1over2.(band) = NaN;
    end

    if ~isfield(C, 'physio') || ~isfield(C.physio, 'phase_windows_pct')
        return;
    end

    pairChar = char(string(pairName));
    if ~isfield(C.physio.phase_windows_pct, pairChar)
        return;
    end

    Wpoi = C.physio.phase_windows_pct.(pairChar);
    if ~isfield(Wpoi, 'start_pct') || ~isfield(Wpoi, 'end_pct')
        return;
    end

    nTime = size(PowSpec_s1, 2);
    time_percent = linspace(0, 100, nTime);

    if Wpoi.start_pct <= Wpoi.end_pct
        poi_idx = find(time_percent >= Wpoi.start_pct & time_percent <= Wpoi.end_pct);
    else
        poi_idx = find(time_percent >= Wpoi.start_pct | time_percent <= Wpoi.end_pct);
    end

    if isempty(poi_idx)
        return;
    end

    for bandName = fieldnames(FreqBands_this)'
        band = bandName{1};
        range = FreqBands_this.(band);

        idx_band = Freq >= range(1) & Freq <= range(2);
        if ~any(idx_band)
            continue;
        end

        p1 = mean(PowSpec_s1(idx_band, poi_idx), 'all', 'omitnan');
        p2 = mean(PowSpec_s2(idx_band, poi_idx), 'all', 'omitnan');

        powerMetrics.power_poi_signal1.(band) = p1;
        powerMetrics.power_poi_signal2.(band) = p2;
        powerMetrics.power_poi_mean_both.(band) = mean([p1 p2], 'omitnan');
        powerMetrics.power_poi_log_mean_both.(band) = log10(powerMetrics.power_poi_mean_both.(band) + eps);

        if ~isnan(p2) && p2 ~= 0
            powerMetrics.power_poi_ratio_1over2.(band) = p1 / p2;
        end
    end
end