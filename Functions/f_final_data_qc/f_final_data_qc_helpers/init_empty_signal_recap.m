function R = init_empty_signal_recap()
% INIT_EMPTY_SIGNAL_RECAP  Empty signal-recap struct.
%
% Used by f_build_final_paired_signals_from_burst_qc when there is nothing
% to summarise. Kept as its own file because that caller lives in another
% file and cannot see a local function.

R = struct();
R.n_total = 0;
R.by_age = table();
R.by_condition = table();
R.by_pair = table();
R.by_age_condition = table();
R.by_pair_age = table();
R.by_pair_condition = table();
R.by_pair_age_condition = table();
end
