function metrics = compute_coherence_scalar_metrics( ...
    Coherence_sig, Freq, FreqBands_this, FullBandRange_this, computeFullBandMetrics, ...
    stance_phase_indices, swing_phase_indices)

    metrics = struct();

    mean_coherence_full = struct();
    auc_coherence_full  = struct();
    auc_coherence_norm_full = struct();
    peak_coherence_full   = struct();

    mean_freq_curve = mean(Coherence_sig, 2, 'omitnan');

    for bandName = fieldnames(FreqBands_this)'
        band = bandName{1};
        range = FreqBands_this.(band);
        idx_band = find(Freq >= range(1) & Freq <= range(2));

        if isempty(idx_band)
            mean_coherence_full.(band) = NaN;
            auc_coherence_full.(band)  = NaN;
            auc_coherence_norm_full.(band) = NaN;
            peak_coherence_full.(band) = NaN;
        else
            fband = Freq(idx_band);
            cband = mean_freq_curve(idx_band);

            [fband_sorted, ord] = sort(fband, 'ascend');
            cband_sorted = cband(ord);

            mean_coherence_full.(band) = mean(cband_sorted, 'omitnan');
            auc_coherence_full.(band)  = trapz(fband_sorted, cband_sorted);
            peak_coherence_full.(band) = max(cband_sorted, [], 'omitnan');

            if diff(range) > 0
                auc_coherence_norm_full.(band) = auc_coherence_full.(band) / diff(range);
            else
                auc_coherence_norm_full.(band) = NaN;
            end
        end
    end

    fullband_mean     = NaN;
    fullband_auc_raw  = NaN;
    fullband_auc_norm = NaN;
    fullband_peak     = NaN;

    if computeFullBandMetrics
        idx_full = Freq >= FullBandRange_this(1) & Freq <= FullBandRange_this(2);

        if any(idx_full)
            f_full = Freq(idx_full);
            c_full = mean_freq_curve(idx_full);

            [f_full_sorted, ord] = sort(f_full, 'ascend');
            c_full_sorted = c_full(ord);

            band_width_full = diff(FullBandRange_this);

            fullband_mean    = mean(c_full_sorted, 'omitnan');
            fullband_auc_raw = trapz(f_full_sorted, c_full_sorted);
            fullband_peak    = max(c_full_sorted, [], 'omitnan');

            if band_width_full > 0
                fullband_auc_norm = fullband_auc_raw / band_width_full;
            end
        end
    end

    mean_curve_stance = mean(Coherence_sig(:, stance_phase_indices), 2, 'omitnan');
    mean_curve_swing  = mean(Coherence_sig(:, swing_phase_indices), 2, 'omitnan');

    mean_coherence_stance = struct();
    mean_coherence_swing  = struct();
    auc_coherence_stance  = struct();
    auc_coherence_swing   = struct();
    auc_coherence_norm_stance = struct();
    auc_coherence_norm_swing  = struct();
    peak_coherence_stance = struct();
    peak_coherence_swing  = struct();

    for bandName = fieldnames(FreqBands_this)'
        band = bandName{1};
        range = FreqBands_this.(band);
        idx_band = Freq >= range(1) & Freq <= range(2);

        mean_coherence_stance.(band) = NaN;
        mean_coherence_swing.(band)  = NaN;
        auc_coherence_stance.(band)  = NaN;
        auc_coherence_swing.(band)   = NaN;
        auc_coherence_norm_stance.(band) = NaN;
        auc_coherence_norm_swing.(band)  = NaN;
        peak_coherence_stance.(band) = NaN;
        peak_coherence_swing.(band)  = NaN;

        if any(idx_band)
            fband = Freq(idx_band);
            c_stance = mean_curve_stance(idx_band);
            c_swing  = mean_curve_swing(idx_band);

            [fband_sorted, ord] = sort(fband, 'ascend');
            c_stance_sorted = c_stance(ord);
            c_swing_sorted  = c_swing(ord);

            mean_coherence_stance.(band) = mean(c_stance_sorted, 'omitnan');
            mean_coherence_swing.(band)  = mean(c_swing_sorted, 'omitnan');

            auc_coherence_stance.(band) = trapz(fband_sorted, c_stance_sorted);
            auc_coherence_swing.(band)  = trapz(fband_sorted, c_swing_sorted);

            if diff(range) > 0
                auc_coherence_norm_stance.(band) = auc_coherence_stance.(band) / diff(range);
                auc_coherence_norm_swing.(band)  = auc_coherence_swing.(band)  / diff(range);
            else
                auc_coherence_norm_stance.(band) = NaN;
                auc_coherence_norm_swing.(band)  = NaN;
            end

            peak_coherence_stance.(band) = max(c_stance_sorted, [], 'omitnan');
            peak_coherence_swing.(band)  = max(c_swing_sorted, [], 'omitnan');
        end
    end

    fullband_mean_stance     = NaN;
    fullband_mean_swing      = NaN;
    fullband_auc_raw_stance  = NaN;
    fullband_auc_raw_swing   = NaN;
    fullband_auc_norm_stance = NaN;
    fullband_auc_norm_swing  = NaN;
    fullband_peak_stance     = NaN;
    fullband_peak_swing      = NaN;

    if computeFullBandMetrics
        idx_full = Freq >= FullBandRange_this(1) & Freq <= FullBandRange_this(2);

        if any(idx_full)
            f_full = Freq(idx_full);
            c_full_stance = mean_curve_stance(idx_full);
            c_full_swing  = mean_curve_swing(idx_full);

            [f_full_sorted, ord] = sort(f_full, 'ascend');
            c_full_stance_sorted = c_full_stance(ord);
            c_full_swing_sorted  = c_full_swing(ord);

            band_width_full = diff(FullBandRange_this);

            fullband_mean_stance = mean(c_full_stance_sorted, 'omitnan');
            fullband_mean_swing  = mean(c_full_swing_sorted, 'omitnan');

            fullband_auc_raw_stance = trapz(f_full_sorted, c_full_stance_sorted);
            fullband_auc_raw_swing  = trapz(f_full_sorted, c_full_swing_sorted);

            fullband_peak_stance = max(c_full_stance_sorted, [], 'omitnan');
            fullband_peak_swing  = max(c_full_swing_sorted, [], 'omitnan');

            if band_width_full > 0
                fullband_auc_norm_stance = fullband_auc_raw_stance / band_width_full;
                fullband_auc_norm_swing  = fullband_auc_raw_swing  / band_width_full;
            else
                fullband_auc_norm_stance = NaN;
                fullband_auc_norm_swing  = NaN;
            end
        end
    end

    metrics.mean_coherence_full   = mean_coherence_full;
    metrics.auc_coherence_full    = auc_coherence_full;
    metrics.auc_coherence_norm_full = auc_coherence_norm_full;
    metrics.peak_coherence_full   = peak_coherence_full;

    metrics.mean_coherence_stance = mean_coherence_stance;
    metrics.mean_coherence_swing  = mean_coherence_swing;

    metrics.auc_coherence_stance  = auc_coherence_stance;
    metrics.auc_coherence_swing   = auc_coherence_swing;

    metrics.auc_coherence_norm_stance = auc_coherence_norm_stance;
    metrics.auc_coherence_norm_swing  = auc_coherence_norm_swing;

    metrics.peak_coherence_stance = peak_coherence_stance;
    metrics.peak_coherence_swing  = peak_coherence_swing;

    metrics.fullband_mean         = fullband_mean;
    metrics.fullband_auc_raw      = fullband_auc_raw;
    metrics.fullband_auc_norm     = fullband_auc_norm;
    metrics.fullband_peak         = fullband_peak;

    metrics.fullband_mean_stance      = fullband_mean_stance;
    metrics.fullband_mean_swing       = fullband_mean_swing;
    metrics.fullband_auc_raw_stance   = fullband_auc_raw_stance;
    metrics.fullband_auc_raw_swing    = fullband_auc_raw_swing;
    metrics.fullband_auc_norm_stance  = fullband_auc_norm_stance;
    metrics.fullband_auc_norm_swing   = fullband_auc_norm_swing;
    metrics.fullband_peak_stance      = fullband_peak_stance;
    metrics.fullband_peak_swing       = fullband_peak_swing;
end