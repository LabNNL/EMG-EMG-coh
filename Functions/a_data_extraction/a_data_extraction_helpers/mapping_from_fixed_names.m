function [sensor_map, log_rows] = mapping_from_fixed_names(analogs, C, subjID, cond, trial, log_rows)
%MAPPING_FROM_FIXED_NAMES Use fixed channel names from config
%
% Expects:
% C.a_extract_raw.mapping.fixed_names.left.(muscle)  = 'channel_name'
% C.a_extract_raw.mapping.fixed_names.right.(muscle) = 'channel_name'

sensor_map = struct();
sensor_map.left  = struct();
sensor_map.right = struct();

channel_names = fieldnames(analogs);

% ---------------- LEFT ----------------
left_map = C.a_extract_raw.mapping.fixed_names.left;
left_muscles = fieldnames(left_map);

for i = 1:numel(left_muscles)

    mus = left_muscles{i};
    expected_channel = left_map.(mus);

    if isfield(analogs, expected_channel)
        sensor_map.left.(mus) = expected_channel;
    else
        log_rows = append_log(log_rows, ...
            'WARN','FIXED_CHANNEL_LEFT_NOT_FOUND',subjID,cond,trial,'left',mus, ...
            '', '', ...
            'Expected fixed LEFT channel not found', expected_channel);
    end
end

% ---------------- RIGHT ----------------
right_map = C.a_extract_raw.mapping.fixed_names.right;
right_muscles = fieldnames(right_map);

for i = 1:numel(right_muscles)

    mus = right_muscles{i};
    expected_channel = right_map.(mus);

    if isfield(analogs, expected_channel)
        sensor_map.right.(mus) = expected_channel;
    else
        log_rows = append_log(log_rows, ...
            'WARN','FIXED_CHANNEL_RIGHT_NOT_FOUND',subjID,cond,trial,'right',mus, ...
            '', '', ...
            'Expected fixed RIGHT channel not found', expected_channel);
    end
end

% ---------------- GLOBAL CHECK ----------------
if isempty(fieldnames(sensor_map.left)) && isempty(fieldnames(sensor_map.right))
    log_rows = append_log(log_rows, ...
        'ERROR','NO_FIXED_CHANNELS_FOUND',subjID,cond,trial,'','', ...
        '', '', ...
        'No fixed channels matched in file','');
end

end