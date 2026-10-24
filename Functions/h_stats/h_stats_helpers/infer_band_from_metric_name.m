function bandName = infer_band_from_metric_name(dv)
% Band of a metric named <Band>[_<metric>], e.g. "HighBeta_AUC_norm" -> "HighBeta".
% Band names (C.shared_wavelet.FreqBands) contain no underscore.

    dv = string(dv);
    bandName = extractBefore(dv + "_", "_");

    if strlength(bandName) == 0
        error('Cannot infer frequency band from dependent variable: %s', dv);
    end
end
