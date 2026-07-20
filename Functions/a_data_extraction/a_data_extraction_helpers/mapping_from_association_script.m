function [sensor_map, log_rows] = mapping_from_association_script(analogs, C, subjID, cond, trial, log_rows)
%MAPPING_FROM_ASSOCIATION_SCRIPT Use Association.m mapping

sensor_map = struct();
sensor_map.left = struct();
sensor_map.right = struct();

Participant = {subjID};
clear sensor_association_left sensor_association_right

try
    run(C.a_extract_raw.mapping.association_script);

    if exist('sensor_association_left','var') ~= 1
        log_rows = append_log(log_rows, ...
            'ERROR','ASSOCIATION_VAR_MISSING',subjID,cond,trial,'left','', ...
            'Association.m', C.a_extract_raw.mapping.association_script, ...
            'sensor_association_left not defined','');
        return;
    end

    if exist('sensor_association_right','var') ~= 1
        log_rows = append_log(log_rows, ...
            'ERROR','ASSOCIATION_VAR_MISSING',subjID,cond,trial,'right','', ...
            'Association.m', C.a_extract_raw.mapping.association_script, ...
            'sensor_association_right not defined','');
        return;
    end

    sensor_map.left = sensor_association_left;
    sensor_map.right = sensor_association_right;

catch ME
    log_rows = append_log(log_rows, ...
        'ERROR','ASSOCIATION_LOAD_ERROR',subjID,cond,trial,'','', ...
        'Association.m', C.a_extract_raw.mapping.association_script, ...
        ME.identifier, ME.message);
end
end