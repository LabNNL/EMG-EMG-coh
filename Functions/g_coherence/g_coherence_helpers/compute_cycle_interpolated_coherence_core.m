function core = compute_cycle_interpolated_coherence_core( ...
    TFR1, TFR2, coi1, coi2, Tseg, Freq, ...
    analysis_cycle_mask, ...
    mask_real_outer, mask_analysis_outer, mask_analysis_middle, ...
    W, DS)

    nFreq = numel(Freq);

    % Accumulators used to build the FINAL coherence estimate
    % from all retained analysis cycles together.
    PowSpec_s1 = zeros(nFreq, W.n_interp_time);
    PowSpec_s2 = zeros(nFreq, W.n_interp_time);
    CrossSpec  = zeros(nFreq, W.n_interp_time);
    Ncycle = 0;

    % Separate accumulators for true first/last cycles of the signal.
    % These are only for diagnostics, not for the main coherence result.
    PowSpec_s1_real_outer = zeros(nFreq, W.n_interp_time);
    PowSpec_s2_real_outer = zeros(nFreq, W.n_interp_time);
    CrossSpec_real_outer  = zeros(nFreq, W.n_interp_time);
    Ncycle_real_outer = 0;

    % Separate accumulators for the first/last RETAINED analysis cycles.
    % Useful to compare retained boundary cycles vs retained middle cycles.
    PowSpec_s1_analysis_outer = zeros(nFreq, W.n_interp_time);
    PowSpec_s2_analysis_outer = zeros(nFreq, W.n_interp_time);
    CrossSpec_analysis_outer  = zeros(nFreq, W.n_interp_time);
    Ncycle_analysis_outer = 0;

    % Separate accumulators for retained middle cycles only.
    PowSpec_s1_analysis_middle = zeros(nFreq, W.n_interp_time);
    PowSpec_s2_analysis_middle = zeros(nFreq, W.n_interp_time);
    CrossSpec_analysis_middle  = zeros(nFreq, W.n_interp_time);
    Ncycle_analysis_middle = 0;

    % Accumulators for the mean cone-of-influence (COI) across cycles,
    % after each cycle is normalized to the same time axis.
    COI_period_accum = zeros(1, W.n_interp_time);
    COI_freq_accum   = zeros(1, W.n_interp_time);

    % Per-cycle scalar summaries.
    % These are simple cycle-wise diagnostics, not the final coherence result.
    fullrange_by_cycle = nan(height(Tseg),1);
    alpha_by_cycle = nan(height(Tseg),1);
    beta_by_cycle  = nan(height(Tseg),1);
    gamma_by_cycle = nan(height(Tseg),1);

    for iC = 1:height(Tseg)

        % Recover this cycle's time indices inside the FULL concatenated TFR.
        s1 = Tseg.final_concat_start_idx_signal1(iC);
        e1 = Tseg.final_concat_end_idx_signal1(iC);
        s2 = Tseg.final_concat_start_idx_signal2(iC);
        e2 = Tseg.final_concat_end_idx_signal2(iC);

        % Skip invalid or empty cycles.
        if e1 <= s1 || e2 <= s2
            continue;
        end

        % Extract this cycle directly from the FULL-SIGNAL wavelet transform.
        % We do not recompute wavelet per cycle from scratch.
        TFR_cycle_1 = TFR1(:, s1:e1);
        TFR_cycle_2 = TFR2(:, s2:e2);

        % Interpolate each cycle to a common number of time points.
        % This normalizes all cycles to 0-100% gait cycle so they can be averaged.
        [X1, Y1] = meshgrid(1:size(TFR_cycle_1,2), 1:size(TFR_cycle_1,1));
        [Xq1, Yq1] = meshgrid(linspace(1, size(TFR_cycle_1,2), W.n_interp_time), 1:size(TFR_cycle_1,1));
        TFR_int_1 = interp2(X1, Y1, TFR_cycle_1, Xq1, Yq1, 'spline');

        [X2, Y2] = meshgrid(1:size(TFR_cycle_2,2), 1:size(TFR_cycle_2,1));
        [Xq2, Yq2] = meshgrid(linspace(1, size(TFR_cycle_2,2), W.n_interp_time), 1:size(TFR_cycle_2,1));
        TFR_int_2 = interp2(X2, Y2, TFR_cycle_2, Xq2, Yq2, 'spline');

        % Compute per-cycle auto-spectra and cross-spectrum.
        % These are the quantities that will be averaged across cycles.
        Pow1_cycle  = abs(TFR_int_1).^2;
        Pow2_cycle  = abs(TFR_int_2).^2;
        Cross_cycle = TFR_int_1 .* conj(TFR_int_2);

        % Build a simple per-cycle coherence spectrum as a diagnostic summary.
        % This is only used to inspect individual cycles, not as the final estimate.
        Sxx_cyc = mean(Pow1_cycle, 2, 'omitnan');
        Syy_cyc = mean(Pow2_cycle, 2, 'omitnan');
        Sxy_cyc = mean(Cross_cycle, 2, 'omitnan');

        Coh_cyc = abs(Sxy_cyc).^2 ./ (Sxx_cyc .* Syy_cyc);
        Coh_cyc(~isfinite(Coh_cyc)) = NaN;
        Coh_cyc(Coh_cyc < 0) = 0;
        Coh_cyc(Coh_cyc > 1) = 1;

        % Store a few cycle-level scalar summaries by frequency range.
        % Again: useful for QC, but not used to build the final coherence map.
        idx_full = Freq >= DS.FreqMin_this & Freq <= DS.FreqMax_this;
        if any(idx_full)
            fullrange_by_cycle(iC) = mean(Coh_cyc(idx_full), 'omitnan');
        end

        if isfield(W.FreqBands, 'Alpha')
            idx_alpha = Freq >= W.FreqBands.Alpha(1) & Freq <= W.FreqBands.Alpha(2);
            if any(idx_alpha)
                alpha_by_cycle(iC) = mean(Coh_cyc(idx_alpha), 'omitnan');
            end
        end

        if isfield(W.FreqBands, 'Beta')
            idx_beta = Freq >= W.FreqBands.Beta(1) & Freq <= W.FreqBands.Beta(2);
            if any(idx_beta)
                beta_by_cycle(iC) = mean(Coh_cyc(idx_beta), 'omitnan');
            end
        end

        if isfield(W.FreqBands, 'Gamma')
            idx_gamma = Freq >= W.FreqBands.Gamma(1) & Freq <= W.FreqBands.Gamma(2);
            if any(idx_gamma)
                gamma_by_cycle(iC) = mean(Coh_cyc(idx_gamma), 'omitnan');
            end
        end

        % Add this cycle to the MAIN retained set used for final coherence.
        % Important: we average spectra across cycles first, then compute coherence once.
        if analysis_cycle_mask(iC)
            PowSpec_s1 = PowSpec_s1 + Pow1_cycle;
            PowSpec_s2 = PowSpec_s2 + Pow2_cycle;
            CrossSpec  = CrossSpec  + Cross_cycle;
            Ncycle = Ncycle + 1;
        end

        % Also accumulate true outer cycles for diagnostics.
        if mask_real_outer(iC)
            PowSpec_s1_real_outer = PowSpec_s1_real_outer + Pow1_cycle;
            PowSpec_s2_real_outer = PowSpec_s2_real_outer + Pow2_cycle;
            CrossSpec_real_outer  = CrossSpec_real_outer  + Cross_cycle;
            Ncycle_real_outer = Ncycle_real_outer + 1;
        end

        % Also accumulate retained outer analysis cycles for diagnostics.
        if mask_analysis_outer(iC)
            PowSpec_s1_analysis_outer = PowSpec_s1_analysis_outer + Pow1_cycle;
            PowSpec_s2_analysis_outer = PowSpec_s2_analysis_outer + Pow2_cycle;
            CrossSpec_analysis_outer  = CrossSpec_analysis_outer  + Cross_cycle;
            Ncycle_analysis_outer = Ncycle_analysis_outer + 1;
        end

        % Also accumulate retained middle analysis cycles for diagnostics.
        if mask_analysis_middle(iC)
            PowSpec_s1_analysis_middle = PowSpec_s1_analysis_middle + Pow1_cycle;
            PowSpec_s2_analysis_middle = PowSpec_s2_analysis_middle + Pow2_cycle;
            CrossSpec_analysis_middle  = CrossSpec_analysis_middle  + Cross_cycle;
            Ncycle_analysis_middle = Ncycle_analysis_middle + 1;
        end

        % Accumulate COI only for cycles contributing to the main coherence estimate
        if analysis_cycle_mask(iC)

            coi_cycle_1 = coi1(s1:e1);
            coi_cycle_2 = coi2(s2:e2);

            coi_int_1 = interp1( ...
                1:numel(coi_cycle_1), coi_cycle_1, ...
                linspace(1, numel(coi_cycle_1), W.n_interp_time), ...
                'linear');

            coi_int_2 = interp1( ...
                1:numel(coi_cycle_2), coi_cycle_2, ...
                linspace(1, numel(coi_cycle_2), W.n_interp_time), ...
                'linear');

            coi_pair_int = min(coi_int_1, coi_int_2);
            coi_freq_int = 1 ./ coi_pair_int;

            COI_period_accum = COI_period_accum + coi_pair_int;
            COI_freq_accum   = COI_freq_accum + coi_freq_int;
        end
    end

    % Build the FINAL coherence map from the retained cycles only.
    % We average spectra first, then compute coherence once from the averages.
    if Ncycle > 0
        PowSpec_s1 = PowSpec_s1 / Ncycle;
        PowSpec_s2 = PowSpec_s2 / Ncycle;
        CrossSpec_mean = CrossSpec / Ncycle;

        Coherence = abs(CrossSpec_mean).^2 ./ (PowSpec_s1 .* PowSpec_s2);
        Coherence(~isfinite(Coherence)) = NaN;
        Coherence(Coherence < 0) = 0;
        Coherence(Coherence > 1) = 1;
    else
        CrossSpec_mean = nan(nFreq, W.n_interp_time);
        Coherence = nan(nFreq, W.n_interp_time);
    end

    % Package everything needed downstream:
    % - final coherence result
    % - mean COI
    % - cycle-level QC summaries
    % - outer/middle diagnostic accumulators
    core = struct();
    core.Ncycle = Ncycle;
    core.PowSpec_s1 = PowSpec_s1;
    core.PowSpec_s2 = PowSpec_s2;
    core.CrossSpec_mean = CrossSpec_mean;
    core.Coherence = Coherence;

    core.COI_period_accum = COI_period_accum;
    core.COI_freq_accum   = COI_freq_accum;

    core.fullrange_by_cycle = fullrange_by_cycle;
    core.alpha_by_cycle = alpha_by_cycle;
    core.beta_by_cycle  = beta_by_cycle;
    core.gamma_by_cycle = gamma_by_cycle;

    core.PowSpec_s1_real_outer = PowSpec_s1_real_outer;
    core.PowSpec_s2_real_outer = PowSpec_s2_real_outer;
    core.CrossSpec_real_outer  = CrossSpec_real_outer;
    core.Ncycle_real_outer = Ncycle_real_outer;

    core.PowSpec_s1_analysis_outer = PowSpec_s1_analysis_outer;
    core.PowSpec_s2_analysis_outer = PowSpec_s2_analysis_outer;
    core.CrossSpec_analysis_outer  = CrossSpec_analysis_outer;
    core.Ncycle_analysis_outer = Ncycle_analysis_outer;

    core.PowSpec_s1_analysis_middle = PowSpec_s1_analysis_middle;
    core.PowSpec_s2_analysis_middle = PowSpec_s2_analysis_middle;
    core.CrossSpec_analysis_middle  = CrossSpec_analysis_middle;
    core.Ncycle_analysis_middle = Ncycle_analysis_middle;
end