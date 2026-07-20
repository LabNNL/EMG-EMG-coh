function R = build_participant_recap_tables(T)

    R = init_empty_participant_recap();

    if isempty(T)
        return;
    end

    subjList = unique(T.subject);
    rows = {};
    ri = 0;

    for iSub = 1:numel(subjList)
        subj = subjList(iSub);
        Ts = T(T.subject == subj, :);

        age_group = "Unknown";
        if ismember('age_group', Ts.Properties.VariableNames) && ~isempty(Ts.age_group)
            age_group = Ts.age_group(1);
        end

        conds = unique(Ts.condition);
        legs  = unique(Ts.leg);
        pairs = unique(Ts.pair_name);

        ri = ri + 1;
        rows(ri,:) = { ...
            string(subj), ...
            string(age_group), ...
            height(Ts), ...
            numel(conds), ...
            numel(legs), ...
            numel(pairs), ...
            strjoin(string(conds), ","), ...
            strjoin(string(legs), ","), ...
            strjoin(string(pairs), ",") ...
            };
    end

    R.summary = cell2table(rows, 'VariableNames', { ...
        'subject','age_group','n_signals','n_conditions','n_legs','n_pairs', ...
        'conditions_list','legs_list','pairs_list'});

    R.n_total = height(R.summary);

    if ismember('age_group', R.summary.Properties.VariableNames)
        R.by_age = rename_groupcount_table(groupcounts(R.summary, 'age_group'), 'n_participants');
        R.signals_per_participant_by_age = groupsummary(R.summary, 'age_group', {'mean','median','min','max'}, 'n_signals');
        R.conditions_per_participant_by_age = groupsummary(R.summary, 'age_group', {'mean','median','min','max'}, 'n_conditions');
    end

    if all(ismember({'subject','condition'}, T.Properties.VariableNames))
        subj_cond = unique(T(:, {'subject','condition'}));
        R.by_condition = rename_groupcount_table(groupcounts(subj_cond, 'condition'), 'n_participants');
    end

    if all(ismember({'subject','age_group','condition'}, T.Properties.VariableNames))
        subj_age_cond = unique(T(:, {'subject','age_group','condition'}));
        R.by_age_condition = rename_groupcount_table(groupcounts(subj_age_cond, {'age_group','condition'}), 'n_participants');
    end
end

function R = init_empty_participant_recap()

    R = struct();
    R.n_total = 0;
    R.summary = table();
    R.by_age = table();
    R.by_condition = table();
    R.by_age_condition = table();
    R.signals_per_participant_by_age = table();
    R.conditions_per_participant_by_age = table();
end