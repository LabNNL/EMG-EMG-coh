function P = package_poi_metrics(poiMetrics)

    P = struct();

    P.mean = poiMetrics.mean_coherence_poi;
    P.auc_raw = poiMetrics.auc_coherence_poi;
    P.auc_norm = poiMetrics.auc_coherence_poi_norm;
    P.peak = poiMetrics.peak_coherence_poi;

    P.fullband_mean = poiMetrics.fullband_mean_poi;
    P.fullband_auc_raw = poiMetrics.fullband_auc_raw_poi;
    P.fullband_auc_norm = poiMetrics.fullband_auc_norm_poi;
    P.fullband_peak = poiMetrics.fullband_peak_poi;
end