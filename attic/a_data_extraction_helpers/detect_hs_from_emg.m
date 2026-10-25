function HS = detect_hs_from_emg(EMG, fs, params)

    % --- Envelope ---
    EMG = EMG(:);
    env = abs(EMG);

    % Low-pass filter
    [b,a] = butter(2, params.envelope_cutoff_hz / (fs/2), 'low');
    env = filtfilt(b,a,env);

    % --- Normalize ---
    env = env / max(env);

    % --- Peak detection ---
    minDist = round(params.min_peak_distance_s * fs);
    minHeight = params.min_peak_height_factor;

    [~, locs] = findpeaks(env, ...
        'MinPeakDistance', minDist, ...
        'MinPeakHeight', minHeight);

    HS = locs;
end