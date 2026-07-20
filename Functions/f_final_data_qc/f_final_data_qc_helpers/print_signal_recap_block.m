function print_signal_recap_block(label, T, R)

    fprintf('\n--------------------- %s ---------------------\n', upper(label));
    fprintf('Total analyzable final paired signals: %d\n', height(T));

    fprintf('\n--- By age group ---\n');
    disp(R.by_age);

    fprintf('\n--- By condition ---\n');
    disp(R.by_condition);

    fprintf('\n--- By pair ---\n');
    disp(R.by_pair);

    fprintf('\n--- By age group x condition ---\n');
    disp(R.by_age_condition);

    fprintf('\n--- By pair x age group ---\n');
    disp(R.by_pair_age);

    fprintf('\n--- By pair x condition ---\n');
    disp(R.by_pair_condition);

    fprintf('\n--- By pair x age group x condition ---\n');
    disp(R.by_pair_age_condition);
end