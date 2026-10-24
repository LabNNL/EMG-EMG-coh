function R = init_empty_participant_recap()
% INIT_EMPTY_PARTICIPANT_RECAP  Empty participant-recap struct.
%
% Used by f_build_final_paired_signals_from_burst_qc when there is nothing
% to summarise. Kept as its own file because that caller lives in another
% file and cannot see a local function.

R = struct();
R.n_total = 0;
R.summary = table();
R.by_age = table();
R.by_condition = table();
R.by_age_condition = table();
R.signals_per_participant_by_age = table();
R.conditions_per_participant_by_age = table();
end
