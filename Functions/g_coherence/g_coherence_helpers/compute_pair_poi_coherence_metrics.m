function poiMetrics = compute_pair_poi_coherence_metrics( ...
    Coherence_sig, Freq, pairName, C, FreqBands_this, FullBandRange_this, computeFullBandMetrics)

    poiMetrics = struct();

    % ---------- Defaults ----------
    poiMetrics.mean_coherence_poi = struct();
    poiMetrics.auc_coherence_poi  = struct();
    poiMetrics.auc_coherence_poi_norm = struct();
    poiMetrics.peak_coherence_poi = struct();

    for bandName = fieldnames(FreqBands_this)'
        band = bandName{1};
        poiMetrics.mean_coherence_poi.(band) = NaN;
        poiMetrics.auc_coherence_poi.(band)  = NaN;
        poiMetrics.auc_coherence_poi_norm.(band) = NaN;
        poiMetrics.peak_coherence_poi.(band) = NaN;
    end

    poiMetrics.fullband_mean_poi     = NaN;
    poiMetrics.fullband_auc_raw_poi  = NaN;
    poiMetrics.fullband_auc_norm_poi = NaN;
    poiMetrics.fullband_peak_poi     = NaN;

    poiMetrics.poi_start_pct = NaN;
    poiMetrics.poi_end_pct   = NaN;
    poiMetrics.poi_indices   = [];
    poiMetrics.has_poi       = false;

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

    start_pct = Wpoi.start_pct;
    end_pct   = Wpoi.end_pct;

    poiMetrics.poi_start_pct = start_pct;
    poiMetrics.poi_end_pct   = end_pct;

    nTime = size(Coherence_sig, 2);
    time_percent = linspace(0, 100, nTime);

    if start_pct <= end_pct
        poi_idx = find(time_percent >= start_pct & time_percent <= end_pct);
    else
        poi_idx = find(time_percent >= start_pct | time_percent <= end_pct);
    end

    if isempty(poi_idx)
        return;
    end

    poiMetrics.poi_indices = poi_idx;
    poiMetrics.has_poi = true;

    mean_curve_poi = mean(Coherence_sig(:, poi_idx), 2, 'omitnan');

    for bandName = fieldnames(FreqBands_this)'
        band = bandName{1};
        range = FreqBands_this.(band);
        idx_band = find(Freq >= range(1) & Freq <= range(2));

        if isempty(idx_band)
            continue;
        end

        fband = Freq(idx_band);
        cband = mean_curve_poi(idx_band);

        [fband_sorted, ord] = sort(fband, 'ascend');
        cband_sorted = cband(ord);

        poiMetrics.mean_coherence_poi.(band) = mean(cband_sorted, 'omitnan');
        poiMetrics.auc_coherence_poi.(band)  = trapz(fband_sorted, cband_sorted);

        bw = diff(range);
        if bw > 0
            poiMetrics.auc_coherence_poi_norm.(band) = poiMetrics.auc_coherence_poi.(band) / bw;
        end

        poiMetrics.peak_coherence_poi.(band) = max(cband_sorted, [], 'omitnan');
    end

    if computeFullBandMetrics
        idx_full = find(Freq >= FullBandRange_this(1) & Freq <= FullBandRange_this(2));

        if ~isempty(idx_full)
            f_full = Freq(idx_full);
            c_full = mean_curve_poi(idx_full);

            [f_full_sorted, ord] = sort(f_full, 'ascend');
            c_full_sorted = c_full(ord);

            poiMetrics.fullband_mean_poi    = mean(c_full_sorted, 'omitnan');
            poiMetrics.fullband_auc_raw_poi = trapz(f_full_sorted, c_full_sorted);

            bw = diff(FullBandRange_this);
            if bw > 0
                poiMetrics.fullband_auc_norm_poi = poiMetrics.fullband_auc_raw_poi / bw;
            end
            poiMetrics.fullband_peak_poi = max(c_full_sorted, [], 'omitnan');
        end
    end
end