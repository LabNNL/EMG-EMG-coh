function val = get_peak_by_scope(R, bandName, metricScope)

    val = NaN;

    try
        switch lower(string(metricScope))
            case "poi"
                val = R.PeakCoherencePOI.(char(bandName));
            case "full"
                val = R.PeakCoherenceFull.(char(bandName));
            case "stance"
                val = R.PeakCoherenceStance.(char(bandName));
            case "swing"
                val = R.PeakCoherenceSwing.(char(bandName));
        end
    catch
        val = NaN;
    end
end
