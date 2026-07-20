function CoherenceReal = compute_coherence_from_precomputed_wavelets(TFR1_all, TFR2_all, idxTrials)

    TFR1 = TFR1_all(:,:,idxTrials);
    TFR2 = TFR2_all(:,:,idxTrials);

    PowSpec1 = mean(abs(TFR1).^2, 3);
    PowSpec2 = mean(abs(TFR2).^2, 3);
    CrossSpec = mean(TFR1 .* conj(TFR2), 3);

    CoherenceReal = abs(CrossSpec).^2 ./ (PowSpec1 .* PowSpec2);

    CoherenceReal(~isfinite(CoherenceReal)) = NaN;
    CoherenceReal(CoherenceReal < 0) = 0;
    CoherenceReal(CoherenceReal > 1) = 1;
end