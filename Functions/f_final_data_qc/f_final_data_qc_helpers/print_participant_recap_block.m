function print_participant_recap_block(label, R)

    fprintf('\n--------------------- %s ---------------------\n', upper(label));
    fprintf('Total included participants: %d\n', R.n_total);

    fprintf('\n--- Participants by age group ---\n');
    disp(R.by_age);

    fprintf('\n--- Participants by condition ---\n');
    disp(R.by_condition);

    fprintf('\n--- Participants by age group x condition ---\n');
    disp(R.by_age_condition);

    fprintf('\n--- Signals per participant by age group ---\n');
    disp(R.signals_per_participant_by_age);

    fprintf('\n--- Conditions per participant by age group ---\n');
    disp(R.conditions_per_participant_by_age);
end