function M = package_full_stance_swing_metrics(metrics)

    M = struct();

    % ---------- Full gait cycle ----------
    M.full = struct();
    M.full.mean = metrics.mean_coherence_full;
    M.full.auc_raw = metrics.auc_coherence_full;
    M.full.auc_norm = metrics.auc_coherence_norm_full;
    M.full.peak = metrics.peak_coherence_full;

    M.full.fullband_mean = metrics.fullband_mean;
    M.full.fullband_auc_raw = metrics.fullband_auc_raw;
    M.full.fullband_auc_norm = metrics.fullband_auc_norm;
    M.full.fullband_peak = metrics.fullband_peak;

    % ---------- Stance ----------
    M.stance = struct();
    M.stance.mean = metrics.mean_coherence_stance;
    M.stance.auc_raw = metrics.auc_coherence_stance;
    M.stance.auc_norm = metrics.auc_coherence_norm_stance;
    M.stance.peak = metrics.peak_coherence_stance;

    M.stance.fullband_mean = metrics.fullband_mean_stance;
    M.stance.fullband_auc_raw = metrics.fullband_auc_raw_stance;
    M.stance.fullband_auc_norm = metrics.fullband_auc_norm_stance;
    M.stance.fullband_peak = metrics.fullband_peak_stance;

    % ---------- Swing ----------
    M.swing = struct();
    M.swing.mean = metrics.mean_coherence_swing;
    M.swing.auc_raw = metrics.auc_coherence_swing;
    M.swing.auc_norm = metrics.auc_coherence_norm_swing;
    M.swing.peak = metrics.peak_coherence_swing;

    M.swing.fullband_mean = metrics.fullband_mean_swing;
    M.swing.fullband_auc_raw = metrics.fullband_auc_raw_swing;
    M.swing.fullband_auc_norm = metrics.fullband_auc_norm_swing;
    M.swing.fullband_peak = metrics.fullband_peak_swing;
end