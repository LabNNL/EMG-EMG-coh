function [sensor_map, log_rows] = resolve_emg_channel_mapping(analogs, C, subjID, cond, trial, log_rows)
%RESOLVE_EMG_CHANNEL_MAPPING Resolve EMG channel mapping according to config

mode = lower(string(C.a_extract_raw.mapping.mode));

switch mode

    case "association_script"
        [sensor_map, log_rows] = mapping_from_association_script(analogs, C, subjID, cond, trial, log_rows);

    case "fixed_names"
        [sensor_map, log_rows] = mapping_from_fixed_names(analogs, C, subjID, cond, trial, log_rows);

    case "auto"
        [sensor_map, log_rows] = auto_map_emg_channels_lr(analogs, C, subjID, cond, trial, log_rows);

    otherwise
        error('Unknown mapping mode: %s', mode);
end
end