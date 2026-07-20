function overall_sec = get_overall_contamination_boundary_sec(BAND_BOUNDARIES, WCQ)

    bandNames = fieldnames(BAND_BOUNDARIES);
    vals = nan(numel(bandNames),1);

    for i = 1:numel(bandNames)
        band = bandNames{i};

        switch string(WCQ.boundary_type)
            case "classical_coi"
                vals(i) = BAND_BOUNDARIES.(band).coi_half_width_sec;
            case "amplitude_based"
                vals(i) = BAND_BOUNDARIES.(band).amplitude_based_half_width_sec;
            otherwise
                error('Unknown boundary_type: %s', string(WCQ.boundary_type));
        end
    end

    switch string(WCQ.overall_rule)
        case "max_band"
            overall_sec = max(vals);
        case "alpha"
            switch string(WCQ.boundary_type)
                case "classical_coi"
                    overall_sec = BAND_BOUNDARIES.Alpha.coi_half_width_sec;
                case "amplitude_based"
                    overall_sec = BAND_BOUNDARIES.Alpha.amplitude_based_half_width_sec;
            end
        otherwise
            error('Unknown overall_rule: %s', string(WCQ.overall_rule));
    end

    overall_sec = overall_sec + WCQ.extra_buffer_sec;
end