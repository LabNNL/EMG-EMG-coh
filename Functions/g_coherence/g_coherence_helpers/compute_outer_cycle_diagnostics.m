function qcdiag = compute_outer_cycle_diagnostics( ...
    core, Freq, mask_real_outer, mask_analysis_outer, mask_analysis_middle, W)

    nFreq = numel(Freq);

    Coherence_real_outer = nan(nFreq, W.n_interp_time);
    Coherence_analysis_outer = nan(nFreq, W.n_interp_time);
    Coherence_analysis_middle = nan(nFreq, W.n_interp_time);

    if core.Ncycle_real_outer > 0
        Pow1 = core.PowSpec_s1_real_outer / core.Ncycle_real_outer;
        Pow2 = core.PowSpec_s2_real_outer / core.Ncycle_real_outer;
        Cross = core.CrossSpec_real_outer / core.Ncycle_real_outer;

        Coherence_real_outer = abs(Cross).^2 ./ (Pow1 .* Pow2);
        Coherence_real_outer(~isfinite(Coherence_real_outer)) = NaN;
        Coherence_real_outer(Coherence_real_outer < 0) = 0;
        Coherence_real_outer(Coherence_real_outer > 1) = 1;
    end

    if core.Ncycle_analysis_outer > 0
        Pow1 = core.PowSpec_s1_analysis_outer / core.Ncycle_analysis_outer;
        Pow2 = core.PowSpec_s2_analysis_outer / core.Ncycle_analysis_outer;
        Cross = core.CrossSpec_analysis_outer / core.Ncycle_analysis_outer;

        Coherence_analysis_outer = abs(Cross).^2 ./ (Pow1 .* Pow2);
        Coherence_analysis_outer(~isfinite(Coherence_analysis_outer)) = NaN;
        Coherence_analysis_outer(Coherence_analysis_outer < 0) = 0;
        Coherence_analysis_outer(Coherence_analysis_outer > 1) = 1;
    end

    if core.Ncycle_analysis_middle > 0
        Pow1 = core.PowSpec_s1_analysis_middle / core.Ncycle_analysis_middle;
        Pow2 = core.PowSpec_s2_analysis_middle / core.Ncycle_analysis_middle;
        Cross = core.CrossSpec_analysis_middle / core.Ncycle_analysis_middle;

        Coherence_analysis_middle = abs(Cross).^2 ./ (Pow1 .* Pow2);
        Coherence_analysis_middle(~isfinite(Coherence_analysis_middle)) = NaN;
        Coherence_analysis_middle(Coherence_analysis_middle < 0) = 0;
        Coherence_analysis_middle(Coherence_analysis_middle > 1) = 1;
    end

    mean_real_outer_spectrum      = mean(Coherence_real_outer, 2, 'omitnan');
    mean_analysis_outer_spectrum  = mean(Coherence_analysis_outer, 2, 'omitnan');
    mean_analysis_middle_spectrum = mean(Coherence_analysis_middle, 2, 'omitnan');

    diag_full_mean_real_outer      = mean(mean_real_outer_spectrum, 'omitnan');
    diag_full_mean_analysis_outer  = mean(mean_analysis_outer_spectrum, 'omitnan');
    diag_full_mean_analysis_middle = mean(mean_analysis_middle_spectrum, 'omitnan');

    diag_diff_realouter_vs_middle     = diag_full_mean_real_outer - diag_full_mean_analysis_middle;
    diag_diff_analysisouter_vs_middle = diag_full_mean_analysis_outer - diag_full_mean_analysis_middle;

    qcdiag = struct();
    qcdiag.mask_real_outer      = mask_real_outer;
    qcdiag.mask_analysis_outer  = mask_analysis_outer;
    qcdiag.mask_analysis_middle = mask_analysis_middle;

    qcdiag.Ncycle_real_outer      = core.Ncycle_real_outer;
    qcdiag.Ncycle_analysis_outer  = core.Ncycle_analysis_outer;
    qcdiag.Ncycle_analysis_middle = core.Ncycle_analysis_middle;

    qcdiag.Coherence_real_outer      = Coherence_real_outer;
    qcdiag.Coherence_analysis_outer  = Coherence_analysis_outer;
    qcdiag.Coherence_analysis_middle = Coherence_analysis_middle;

    qcdiag.mean_real_outer_spectrum      = mean_real_outer_spectrum;
    qcdiag.mean_analysis_outer_spectrum  = mean_analysis_outer_spectrum;
    qcdiag.mean_analysis_middle_spectrum = mean_analysis_middle_spectrum;

    qcdiag.diag_full_mean_real_outer      = diag_full_mean_real_outer;
    qcdiag.diag_full_mean_analysis_outer  = diag_full_mean_analysis_outer;
    qcdiag.diag_full_mean_analysis_middle = diag_full_mean_analysis_middle;

    qcdiag.diag_diff_realouter_vs_middle     = diag_diff_realouter_vs_middle;
    qcdiag.diag_diff_analysisouter_vs_middle = diag_diff_analysisouter_vs_middle;
end