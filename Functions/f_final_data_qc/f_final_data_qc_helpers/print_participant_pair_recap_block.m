function print_participant_pair_recap_block(label, R)

    fprintf('\n--------------------- %s ---------------------\n', upper(label));

    fprintf('\n--- Participants by pair ---\n');
    disp(R.by_pair);

    fprintf('\n--- Participants by pair x age group ---\n');
    disp(R.by_pair_age);

    fprintf('\n--- Participants by pair x condition ---\n');
    disp(R.by_pair_condition);

    fprintf('\n--- Participants by pair x age group x condition ---\n');
    disp(R.by_pair_age_condition);

    fprintf('\n--- Signals per participant by pair x age group ---\n');
    disp(R.signals_per_participant_by_pair_age);

    fprintf('\n--- Conditions per participant by pair x age group ---\n');
    disp(R.conditions_per_participant_by_pair_age);
end