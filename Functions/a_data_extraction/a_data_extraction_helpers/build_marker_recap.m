function MARKER_RECAP = build_marker_recap(Participants, OUT_DIR, RESULTS_DIR)

rows = {};
ri = 0;

for iP = 1:numel(Participants)
    subjID = Participants{iP};
    mat_file = fullfile(OUT_DIR, sprintf('%s_RAW_CYCLES_CONCAT.mat', subjID));

    if ~isfile(mat_file)
        continue;
    end

    S = load(mat_file);

    if ~isfield(S, 'RAW_MARKERS') || ~isfield(S.RAW_MARKERS, subjID)
        continue;
    end

    conds = fieldnames(S.RAW_MARKERS.(subjID));

    for ic = 1:numel(conds)
        cond = conds{ic};

        legs = fieldnames(S.RAW_MARKERS.(subjID).(cond));
        for il = 1:numel(legs)
            leg = legs{il};

            trials = fieldnames(S.RAW_MARKERS.(subjID).(cond).(leg));
            for it = 1:numel(trials)
                trial_field = trials{it};

                M = S.RAW_MARKERS.(subjID).(cond).(leg).(trial_field);

                toe_n = NaN;
                heel_n = NaN;

                if isfield(M,'toe_xyz') && ~isempty(M.toe_xyz)
                    toe_n = size(M.toe_xyz, 1);
                end

                if isfield(M,'heel_xyz') && ~isempty(M.heel_xyz)
                    heel_n = size(M.heel_xyz, 1);
                end

                trial_id = erase(trial_field, 'trial_');

                ri = ri + 1;
                rows(ri,:) = { ...
                    string(subjID), ...
                    string(cond), ...
                    string(trial_id), ...
                    string(leg), ...
                    getfield_or_default(M, 'fs_marker', NaN), ...
                    string(getfield_or_default(M, 'toe_marker_name', "")), ...
                    string(getfield_or_default(M, 'heel_marker_name', "")), ...
                    string(getfield_or_default(M, 'toe_status', "UNKNOWN")), ...
                    string(getfield_or_default(M, 'heel_status', "UNKNOWN")), ...
                    toe_n, ...
                    heel_n, ...
                    string(getfield_or_default(M, 'source_file', "")) ...
                    };
            end
        end
    end
end

if isempty(rows)
    MARKER_RECAP = table( ...
        string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        zeros(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        zeros(0,1), zeros(0,1), string.empty(0,1), ...
        'VariableNames', {'participant','condition','trial','leg','fs_marker', ...
                          'toe_marker_name','heel_marker_name','toe_status','heel_status', ...
                          'toe_n_samples','heel_n_samples','source_file'});
else
    MARKER_RECAP = cell2table(rows, 'VariableNames', ...
        {'participant','condition','trial','leg','fs_marker', ...
         'toe_marker_name','heel_marker_name','toe_status','heel_status', ...
         'toe_n_samples','heel_n_samples','source_file'});
end

out_csv = fullfile(RESULTS_DIR, 'marker_recap.csv');
writetable(MARKER_RECAP, out_csv);
fprintf('Marker recap saved: %s\n', out_csv);

if ~isempty(MARKER_RECAP)
    fprintf('\n--- MARKER RECAP ---\n');
    disp(groupcounts(MARKER_RECAP, {'toe_status','heel_status'}));
    disp(groupcounts(MARKER_RECAP, {'condition','leg'}));
end

end

function val = getfield_or_default(S, field_name, default_val)

if isfield(S, field_name)
    val = S.(field_name);
else
    val = default_val;
end

end