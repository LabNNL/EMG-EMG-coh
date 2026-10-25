function R = init_empty_participant_pair_recap()
% INIT_EMPTY_PARTICIPANT_PAIR_RECAP  Empty participant-by-pair recap struct.
%
% Used by f_build_final_paired_signals_from_burst_qc when there is nothing
% to summarise. Kept as its own file because that caller lives in another
% file and cannot see a local function.

R = struct();
R.summary_by_pair = table();
R.by_pair = table();
R.by_pair_age = table();
R.signals_per_participant_by_pair_age = table();
R.conditions_per_participant_by_pair_age = table();
R.by_pair_condition = table();
R.by_pair_age_condition = table();
end
