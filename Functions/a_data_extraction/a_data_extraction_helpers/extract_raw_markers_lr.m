function [RAW_MARKERS, log_rows] = extract_raw_markers_lr(acq, C, RAW_MARKERS, subjID, cond, trial_id, c3dname, fullpth, log_rows)
%EXTRACT_RAW_MARKERS_LR Extract raw heel/toe marker trajectories from C3D.
% Robust behavior:
%   - missing markers are logged as WARN
%   - marker read errors are logged as WARN/ERROR
%   - EMG extraction should continue

if ~isfield(C.a_extract_raw, 'markers') || ~C.a_extract_raw.markers.enable
    return;
end
fprintf('   -> Extracting markers for %s %s trial %s\n', subjID, cond, trial_id);

% Always initialize output structure, even if markers fail
if ~isfield(RAW_MARKERS, subjID)
    RAW_MARKERS.(subjID) = struct();
end
if ~isfield(RAW_MARKERS.(subjID), cond)
    RAW_MARKERS.(subjID).(cond) = struct();
end

try
    markers = btkGetMarkers(acq);
    fs_marker = btkGetPointFrequency(acq);
    fprintf('      Marker frequency: %.1f Hz\n', fs_marker);

    marker_fields = fieldnames(markers);
    fprintf('      Number of markers found: %d\n', numel(marker_fields));

    % Uncomment if you want to see every marker name
    % disp(marker_fields)
catch ME
    log_rows = append_log(log_rows, ...
        'WARN','MARKER_READ_ERROR',subjID,cond,trial_id,'','', ...
        c3dname,fullpth,ME.identifier,ME.message);
    return;
end

if isempty(markers) || isempty(fieldnames(markers))
    log_rows = append_log(log_rows, ...
        'WARN','NO_MARKERS_FOUND',subjID,cond,trial_id,'','', ...
        c3dname,fullpth,'No marker trajectories found in C3D','');
    return;
end

legs = ["left","right"];

for iL = 1:numel(legs)
    leg = legs(iL);

    if leg == "left"
        toe_candidates  = C.a_extract_raw.markers.left.toe_candidates;
        heel_candidates = C.a_extract_raw.markers.left.heel_candidates;
    else
        toe_candidates  = C.a_extract_raw.markers.right.toe_candidates;
        heel_candidates = C.a_extract_raw.markers.right.heel_candidates;
    end

    [toe_name, toe_xyz, toe_status] = find_marker_robust(markers, toe_candidates);
    [heel_name, heel_xyz, heel_status] = find_marker_robust(markers, heel_candidates);

    fprintf('      %s leg:\n', leg);
    fprintf('         Toe : %s (%s)\n', char(toe_name), char(toe_status));
    fprintf('         Heel: %s (%s)\n', char(heel_name), char(heel_status));

    if strcmp(toe_status,'FOUND')
        fprintf('            Toe size : %d x %d\n', size(toe_xyz,1), size(toe_xyz,2));
    end

    if strcmp(heel_status,'FOUND')
        fprintf('            Heel size: %d x %d\n', size(heel_xyz,1), size(heel_xyz,2));
    end

    leg_char = char(leg);
    if ~isfield(RAW_MARKERS.(subjID).(cond), leg_char)
        RAW_MARKERS.(subjID).(cond).(leg_char) = struct();
    end

    trial_field = matlab.lang.makeValidName(sprintf('trial_%s', trial_id));

    RAW_MARKERS.(subjID).(cond).(leg_char).(trial_field).fs_marker = fs_marker;
    RAW_MARKERS.(subjID).(cond).(leg_char).(trial_field).toe_marker_name = toe_name;
    RAW_MARKERS.(subjID).(cond).(leg_char).(trial_field).heel_marker_name = heel_name;
    RAW_MARKERS.(subjID).(cond).(leg_char).(trial_field).toe_xyz = toe_xyz;
    RAW_MARKERS.(subjID).(cond).(leg_char).(trial_field).heel_xyz = heel_xyz;
    RAW_MARKERS.(subjID).(cond).(leg_char).(trial_field).toe_status = toe_status;
    RAW_MARKERS.(subjID).(cond).(leg_char).(trial_field).heel_status = heel_status;
    RAW_MARKERS.(subjID).(cond).(leg_char).(trial_field).source_file = c3dname;

    if toe_status ~= "FOUND"
        log_rows = append_log(log_rows, ...
            'WARN','TOE_MARKER_MISSING',subjID,cond,trial_id,leg_char,'', ...
            c3dname,fullpth,'Toe marker not found',strjoin(string(toe_candidates), ', '));
    end

    if heel_status ~= "FOUND"
        log_rows = append_log(log_rows, ...
            'WARN','HEEL_MARKER_MISSING',subjID,cond,trial_id,leg_char,'', ...
            c3dname,fullpth,'Heel marker not found',strjoin(string(heel_candidates), ', '));
    end

    if toe_status == "FOUND" && any(isnan(toe_xyz(:)))
        log_rows = append_log(log_rows, ...
            'WARN','TOE_MARKER_HAS_NANS',subjID,cond,trial_id,leg_char,'', ...
            c3dname,fullpth,'Toe marker contains NaNs',toe_name);
    end

    if heel_status == "FOUND" && any(isnan(heel_xyz(:)))
        log_rows = append_log(log_rows, ...
            'WARN','HEEL_MARKER_HAS_NANS',subjID,cond,trial_id,leg_char,'', ...
            c3dname,fullpth,'Heel marker contains NaNs',heel_name);
    end
end

fprintf('   -> Marker extraction finished.\n');
end

function [marker_name, xyz, status] = find_marker_robust(markers, candidates)

marker_name = "";
xyz = [];
status = "MISSING";

marker_fields = fieldnames(markers);

for i = 1:numel(candidates)
    cand = char(candidates(i));

    idx = find(strcmp(marker_fields, cand), 1);

    if isempty(idx)
        idx = find(strcmpi(marker_fields, cand), 1);
    end

    if ~isempty(idx)
        marker_name = string(marker_fields{idx});
        xyz = markers.(marker_fields{idx});

        if isempty(xyz)
            status = "EMPTY";
        else
            status = "FOUND";
        end

        return;
    end
end

end