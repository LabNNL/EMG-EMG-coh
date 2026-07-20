function val = get_power_by_scope(R, bandName, metricScope)

    val = NaN;

    try
        switch lower(string(metricScope))
            case "poi"
                val = R.PowerPOI_log_mean_both.(char(bandName));
            otherwise
                val = NaN; % only POI power saved for now
        end
    catch
        val = NaN;
    end
end