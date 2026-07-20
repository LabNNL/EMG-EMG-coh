function BAND_BOUNDARIES = compute_wavelet_band_boundaries_from_config(WCQ)

    bandNames = fieldnames(WCQ.freq_bands);
    BAND_BOUNDARIES = struct();

    for i = 1:numel(bandNames)
        band = bandNames{i};
        fmin = WCQ.freq_bands.(band)(1);

        BAND_BOUNDARIES.(band) = morlet_time_boundaries( ...
            fmin, WCQ.wave_number, WCQ.amplitude_tol);
    end
end


function B = morlet_time_boundaries(f_hz, waveNumber, amplitude_tol)

    % Morlet Fourier factor
    fourier_factor = (4*pi) / (waveNumber + sqrt(2 + waveNumber^2));

    % Scale corresponding to this frequency
    scale = 1 ./ (f_hz .* fourier_factor);

    % Classical COI / e-folding boundary
    coi_half_width_sec = sqrt(2) .* scale;

    % Amplitude-threshold boundary
    amp_half_width_sec = scale .* sqrt(2 * log(1 ./ amplitude_tol));

    % Power at the amplitude-threshold boundary
    power_tol = amplitude_tol.^2;

    B = struct();
    B.frequency_hz = f_hz;
    B.waveNumber = waveNumber;
    B.fourier_factor = fourier_factor;
    B.scale_sec = scale;
    B.coi_half_width_sec = coi_half_width_sec;
    B.amplitude_tol = amplitude_tol;
    B.power_tol = power_tol;
    B.amplitude_based_half_width_sec = amp_half_width_sec;
end