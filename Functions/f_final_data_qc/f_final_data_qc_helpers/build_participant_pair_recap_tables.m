function R = build_participant_pair_recap_tables(T)

    R = init_empty_participant_pair_recap();

    if isempty(T)
        return;
    end

    subjPair = unique(T(:, {'subject','age_group','pair_name'}));
    rows = {};
    ri = 0;

    for iRow = 1:height(subjPair)
        subj = subjPair.subject(iRow);
        age_group = subjPair.age_group(iRow);
        pair_name = subjPair.pair_name(iRow);

        Ts = T(T.subject == subj & T.pair_name == pair_name, :);

        conds = unique(Ts.condition);
        legs  = unique(Ts.leg);

        ri = ri + 1;
        rows(ri,:) = { ...
            string(subj), ...
            string(age_group), ...
            string(pair_name), ...
            height(Ts), ...
            numel(conds), ...
            numel(legs), ...
            strjoin(string(conds), ","), ...
            strjoin(string(legs), ",") ...
            };
    end

    R.summary_by_pair = cell2table(rows, 'VariableNames', {'subject','age_group','pair_name','n_signals','n_conditions','n_legs','conditions_list','legs_list'});

    if ~isempty(R.summary_by_pair)
        R.by_pair = rename_groupcount_table(groupcounts(R.summary_by_pair, 'pair_name'), 'n_participants');
        R.by_pair_age = rename_groupcount_table(groupcounts(R.summary_by_pair, {'pair_name','age_group'}), 'n_participants');
        R.signals_per_participant_by_pair_age = groupsummary( ...
            R.summary_by_pair, {'pair_name','age_group'}, {'mean','median','min','max'}, 'n_signals');
        R.conditions_per_participant_by_pair_age = groupsummary( ...
            R.summary_by_pair, {'pair_name','age_group'}, {'mean','median','min','max'}, 'n_conditions');
    end

    if all(ismember({'subject','age_group','pair_name','condition'}, T.Properties.VariableNames))
        Tpc = unique(T(:, {'subject','age_group','pair_name','condition'}));
        R.by_pair_condition = rename_groupcount_table(groupcounts(Tpc, {'pair_name','condition'}), 'n_participants');
        R.by_pair_age_condition = rename_groupcount_table(groupcounts(Tpc, {'pair_name','age_group','condition'}), 'n_participants');
    end
end

function R = init_empty_participant_pair_recap()
    R = struct();
    R.summary_by_pair = table();
    R.by_pair = table();
    R.by_pair_age = table();
    R.signals_per_participant_by_pair_age = table();
    R.conditions_per_participant_by_pair_age = table();
    R.by_pair_condition = table();
    R.by_pair_age_condition = table();
end