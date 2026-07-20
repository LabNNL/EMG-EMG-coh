function [sensor_map, log_rows] = auto_map_emg_channels_lr(analogs, C, subjID, cond, trial, log_rows)

channel_names = fieldnames(analogs);

sensor_map = struct();
sensor_map.left = struct();
sensor_map.right = struct();

muscles = fieldnames(C.a_extract_raw.channels.muscle_keywords);

for i = 1:numel(muscles)
    mus = muscles{i};
    keywords = lower(C.a_extract_raw.channels.muscle_keywords.(mus));

    for k = 1:numel(channel_names)
        ch = channel_names{k};
        ch_low = lower(ch);

        % ---- Check muscle match ----
        if any(contains(ch_low, keywords))

            % ---- Check LEFT ----
            if any(contains(ch_low, lower(C.a_extract_raw.channels.left_keywords)))
                if ~isfield(sensor_map.left, mus)
                    sensor_map.left.(mus) = ch;
                end
            end

            % ---- Check RIGHT ----
            if any(contains(ch_low, lower(C.a_extract_raw.channels.right_keywords)))
                if ~isfield(sensor_map.right, mus)
                    sensor_map.right.(mus) = ch;
                end
            end

        end
    end

    % ---- Logging missing ----
    if ~isfield(sensor_map.left, mus)
        log_rows = append_log(log_rows, ...
            'WARN','CHANNEL_LEFT_NOT_FOUND',subjID,cond,trial,'left',mus, ...
            '', '', 'No LEFT channel found', strjoin(keywords, ','));
    end

    if ~isfield(sensor_map.right, mus)
        log_rows = append_log(log_rows, ...
            'WARN','CHANNEL_RIGHT_NOT_FOUND',subjID,cond,trial,'right',mus, ...
            '', '', 'No RIGHT channel found', strjoin(keywords, ','));
    end
end