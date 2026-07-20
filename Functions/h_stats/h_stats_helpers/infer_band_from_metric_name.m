function bandName = infer_band_from_metric_name(dv)

    dv = string(dv);

    if startsWith(dv, "Alpha", "IgnoreCase", true)
        bandName = "Alpha";
    elseif startsWith(dv, "Beta", "IgnoreCase", true)
        bandName = "Beta";
    elseif startsWith(dv, "Gamma", "IgnoreCase", true)
        bandName = "Gamma";
    else
        error('Cannot infer frequency band from dependent variable: %s', dv);
    end
end