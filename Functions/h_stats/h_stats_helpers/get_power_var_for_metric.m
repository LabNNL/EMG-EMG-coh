function powerVar = get_power_var_for_metric(dv)
% Log-power column matching a metric named <Band>[_<metric>], e.g.
% "HighBeta_AUC_norm" -> "HighBeta_LogPower"; "" if the name has no band.

    dv = string(dv);
    band = extractBefore(dv + "_", "_");

    if strlength(band) == 0
        powerVar = "";
    else
        powerVar = band + "_LogPower";
    end
end
