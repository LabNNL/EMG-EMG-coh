function R = build_signal_recap_tables(T)

    R = init_empty_signal_recap();

    if isempty(T)
        return;
    end

    R.n_total = height(T);

    if ismember('age_group', T.Properties.VariableNames)
        R.by_age = rename_groupcount_table(groupcounts(T, 'age_group'), 'n_signals');
    end

    if ismember('condition', T.Properties.VariableNames)
        R.by_condition = rename_groupcount_table(groupcounts(T, 'condition'), 'n_signals');
    end

    if ismember('pair_name', T.Properties.VariableNames)
        R.by_pair = rename_groupcount_table(groupcounts(T, 'pair_name'), 'n_signals');
    end

    if all(ismember({'age_group','condition'}, T.Properties.VariableNames))
        R.by_age_condition = rename_groupcount_table(groupcounts(T, {'age_group','condition'}), 'n_signals');
    end

    if all(ismember({'pair_name','age_group'}, T.Properties.VariableNames))
        R.by_pair_age = rename_groupcount_table(groupcounts(T, {'pair_name','age_group'}), 'n_signals');
    end

    if all(ismember({'pair_name','condition'}, T.Properties.VariableNames))
        R.by_pair_condition = rename_groupcount_table(groupcounts(T, {'pair_name','condition'}), 'n_signals');
    end

    if all(ismember({'pair_name','age_group','condition'}, T.Properties.VariableNames))
        R.by_pair_age_condition = rename_groupcount_table(groupcounts(T, {'pair_name','age_group','condition'}), 'n_signals');
    end
end

