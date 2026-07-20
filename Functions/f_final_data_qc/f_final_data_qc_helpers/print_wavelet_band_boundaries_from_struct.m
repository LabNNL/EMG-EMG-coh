function print_wavelet_band_boundaries_from_struct(BAND_BOUNDARIES, WCQ)

    fprintf('\n=== Wavelet-based band boundaries actually used ===\n');
    fprintf('boundary_type = %s\n', char(string(WCQ.boundary_type)));
    fprintf('mode          = %s\n', char(string(WCQ.mode)));

    if isfield(WCQ, 'overall_rule')
        fprintf('overall_rule  = %s\n', char(string(WCQ.overall_rule)));
    end

    if isfield(WCQ, 'amplitude_tol')
        fprintf('amplitude_tol = %.4f\n', WCQ.amplitude_tol);
    end

    bandNames = fieldnames(BAND_BOUNDARIES);
    for i = 1:numel(bandNames)
        band = bandNames{i};

        switch string(WCQ.boundary_type)
            case "classical_coi"
                val = BAND_BOUNDARIES.(band).coi_half_width_sec;
            case "amplitude_based"
                val = BAND_BOUNDARIES.(band).amplitude_based_half_width_sec;
            otherwise
                error('Unknown boundary_type: %s', string(WCQ.boundary_type));
        end

        fprintf('%s: %.6f s\n', band, val);
    end
end