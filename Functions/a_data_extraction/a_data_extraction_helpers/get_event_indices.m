function indices = get_event_indices(acq, freqS, freqVicon, EMG, candidates)

    events = btkGetEvents(acq);
    N_EMG = length(EMG);
    TempsEMG = tempsE(N_EMG, freqS);

    indices = [];

    % Find first matching field
    for i = 1:numel(candidates)
        field = char(candidates(i));

        if isfield(events, field)
            event_times = events.(field);

            % Convert to seconds (same logic as before)
            fsrt_frame = btkGetFirstFrame(acq);
            event_times = ((event_times * freqVicon) - fsrt_frame) / freqVicon;

            % Convert to EMG indices
            idx = zeros(size(event_times));
            for k = 1:length(event_times)
                [~, idx(k)] = min(abs(TempsEMG - event_times(k)));
            end

            indices = idx;
            return;
        end
    end

    % If nothing found → return empty
end