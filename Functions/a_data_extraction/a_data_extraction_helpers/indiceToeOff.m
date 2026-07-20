function indices = indiceToeOff(data, freqS, freqVicon, EMG, side)
%INDICETOE OFF Find Toe Off event indices in EMG sample coordinates.

    fsrt_frame = btkGetFirstFrame(data);
    moments = btkGetEvents(data);
    N_EMG = length(EMG);

    event_names = fieldnames(moments);

    if strcmpi(side,'left')
        exact_name = 'Left_Foot_Off';
        partial_pat = 'left_foot_off';
        err_id = 'indiceToeOff:MissingLeftFootOff';
    else
        exact_name = 'Right_Foot_Off';
        partial_pat = 'right_foot_off';
        err_id = 'indiceToeOff:MissingRightFootOff';
    end

    exact_idx = find(strcmp(event_names, exact_name), 1, 'first');

    if ~isempty(exact_idx)
        field_name = event_names{exact_idx};
    else
        partial_idx = find(contains(lower(event_names), partial_pat), 1, 'first');
        if isempty(partial_idx)
            error(err_id, 'No event field containing "%s" was found.', exact_name);
        end
        field_name = event_names{partial_idx};
    end

    TO = ((moments.(field_name) * freqVicon) - fsrt_frame) / freqVicon;
    TempsEMG = tempsE(N_EMG, freqS);

    indices = zeros(size(TO));
    for i = 1:length(TO)
        [~, indices(i)] = min(abs(TempsEMG - TO(i)));
    end
end