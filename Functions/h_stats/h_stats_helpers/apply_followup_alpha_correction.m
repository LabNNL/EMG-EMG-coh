function HS = apply_followup_alpha_correction(HS, nTests)
% Alpha for the SPM follow-up tests of one figure (one test per stratum).
% HS.followup_alpha_correction = 'bonferroni' (default) divides HS.spm_alpha
% by the number of strata; 'none' keeps it. HS.followup_alpha_label says which.

    method = "bonferroni";
    if isfield(HS, 'followup_alpha_correction') && ~isempty(HS.followup_alpha_correction)
        method = lower(string(HS.followup_alpha_correction));
    end
    alpha0 = HS.spm_alpha;

    switch method
        case "bonferroni"
            HS.spm_alpha = alpha0 / max(nTests, 1);
            HS.followup_alpha_label = sprintf('follow-up alpha = %.3g (%.3g Bonferroni over %d strata)', HS.spm_alpha, alpha0, nTests);
        case "none"
            HS.followup_alpha_label = sprintf('follow-up alpha = %.3g (uncorrected over %d strata)', alpha0, nTests);
        otherwise
            error('Unknown followup_alpha_correction: %s', method);
    end
end
