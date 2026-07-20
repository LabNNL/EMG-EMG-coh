function [C_surr_thr, C_delta] = compute_surrogate_delta_coherence( ...
    TFR1, TFR2, Tseg, Freq, analysis_cycle_mask, W, SurrCfg, subjID, cond, leg, pairName)

    nFreq = numel(Freq);
    nTime = W.n_interp_time;

    C_surr_thr = nan(nFreq, nTime);
    C_delta    = nan(nFreq, nTime);

    idxCycles = find(analysis_cycle_mask);
    nCycles = numel(idxCycles);

    if nCycles < 2
        warning('Not enough cycles for surrogate coherence: %s | %s | %s | %s', ...
            subjID, cond, leg, pairName);
        return;
    end

    nSurrogates = 100;
    if isfield(SurrCfg, 'n_surrogates') && ~isempty(SurrCfg.n_surrogates)
        nSurrogates = SurrCfg.n_surrogates;
    end

    pct = 95;
    if isfield(SurrCfg, 'percentile') && ~isempty(SurrCfg.percentile)
        pct = SurrCfg.percentile;
    end

    if isfield(SurrCfg, 'random_seed') && ~isempty(SurrCfg.random_seed)
        seedVal = double(SurrCfg.random_seed) + ...
            double(sum(char(string(subjID)))) + ...
            double(sum(char(string(cond)))) + ...
            double(sum(char(string(leg)))) + ...
            double(sum(char(string(pairName))));
        rng(seedVal);
    end

    % ---------- True coherence using normal cycle pairing ----------
    [Pow1_true, Pow2_true, Cross_true] = accumulate_cycle_spectra_with_pairing( ...
        TFR1, TFR2, Tseg, idxCycles, idxCycles, W);

    C_true = coherence_from_accumulated_spectra(Pow1_true, Pow2_true, Cross_true, nCycles);

    % ---------- Surrogate coherences ----------
    C_surr_stack = nan(nFreq, nTime, nSurrogates);

    for iSur = 1:nSurrogates

        shuffledCycles2 = idxCycles(randperm(nCycles));

        [Pow1_s, Pow2_s, Cross_s] = accumulate_cycle_spectra_with_pairing( ...
            TFR1, TFR2, Tseg, idxCycles, shuffledCycles2, W);

        C_surr_stack(:,:,iSur) = coherence_from_accumulated_spectra( ...
            Pow1_s, Pow2_s, Cross_s, nCycles);
    end

    C_surr_thr = prctile(C_surr_stack, pct, 3);

    C_delta = C_true - C_surr_thr;
    C_delta(C_delta < 0) = 0;
end

function [Pow1_accum, Pow2_accum, Cross_accum] = accumulate_cycle_spectra_with_pairing( ...
    TFR1, TFR2, Tseg, idxCycles1, idxCycles2, W)

    nFreq = size(TFR1, 1);

    Pow1_accum  = zeros(nFreq, W.n_interp_time);
    Pow2_accum  = zeros(nFreq, W.n_interp_time);
    Cross_accum = zeros(nFreq, W.n_interp_time);

    nPairs = numel(idxCycles1);

    for i = 1:nPairs

        iC1 = idxCycles1(i);
        iC2 = idxCycles2(i);

        s1 = Tseg.final_concat_start_idx_signal1(iC1);
        e1 = Tseg.final_concat_end_idx_signal1(iC1);

        s2 = Tseg.final_concat_start_idx_signal2(iC2);
        e2 = Tseg.final_concat_end_idx_signal2(iC2);

        if e1 <= s1 || e2 <= s2
            continue;
        end

        TFR_cycle_1 = TFR1(:, s1:e1);
        TFR_cycle_2 = TFR2(:, s2:e2);

        TFR_int_1 = interpolate_tfr_cycle_to_npoints(TFR_cycle_1, W.n_interp_time);
        TFR_int_2 = interpolate_tfr_cycle_to_npoints(TFR_cycle_2, W.n_interp_time);

        Pow1_accum  = Pow1_accum  + abs(TFR_int_1).^2;
        Pow2_accum  = Pow2_accum  + abs(TFR_int_2).^2;
        Cross_accum = Cross_accum + TFR_int_1 .* conj(TFR_int_2);
    end
end

function C = coherence_from_accumulated_spectra(Pow1_accum, Pow2_accum, Cross_accum, nCycles)

    if nCycles <= 0
        C = nan(size(Pow1_accum));
        return;
    end

    Pow1_mean = Pow1_accum / nCycles;
    Pow2_mean = Pow2_accum / nCycles;
    Cross_mean = Cross_accum / nCycles;

    C = abs(Cross_mean).^2 ./ (Pow1_mean .* Pow2_mean);

    C(~isfinite(C)) = NaN;
    C(C < 0) = 0;
    C(C > 1) = 1;
end

function TFR_int = interpolate_tfr_cycle_to_npoints(TFR_cycle, nTime)

    [X, Y] = meshgrid(1:size(TFR_cycle,2), 1:size(TFR_cycle,1));
    [Xq, Yq] = meshgrid(linspace(1, size(TFR_cycle,2), nTime), 1:size(TFR_cycle,1));

    TFR_int = interp2(X, Y, TFR_cycle, Xq, Yq, 'spline');
end