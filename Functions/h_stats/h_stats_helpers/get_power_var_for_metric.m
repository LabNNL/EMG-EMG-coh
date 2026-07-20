function powerVar = get_power_var_for_metric(dv)

    dv = string(dv);

    if startsWith(dv, "Alpha", "IgnoreCase", true)
        powerVar = "Alpha_LogPower";
    elseif startsWith(dv, "Beta", "IgnoreCase", true)
        powerVar = "Beta_LogPower";
    elseif startsWith(dv, "Gamma", "IgnoreCase", true)
        powerVar = "Gamma_LogPower";
    else
        powerVar = "";
    end
end