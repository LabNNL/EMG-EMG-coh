function Tout = build_master_signal_recap_by_pair_band(T, bandLabel)

    if isempty(T)
        Tout = table();
        return;
    end

    groupSets = { ...
        {'pair_name'}, ...
        {'pair_name','age_group'}, ...
        {'pair_name','condition'}, ...
        {'pair_name','age_group','condition'}};

    levelNames = { ...
        "pair_all_age_all_condition", ...
        "pair_age_all_condition", ...
        "pair_all_age_condition", ...
        "pair_age_condition"};

    rows = {};

    for iG = 1:numel(groupSets)
        groupVars = groupSets{iG};
        levelName = levelNames{iG};

        G = groupcounts(T, groupVars);
        G.Properties.VariableNames{'GroupCount'} = 'n_signals';

        U = unique(T(:, [{'subject'}, groupVars]));
        Gsub = groupcounts(U, groupVars);
        Gsub.Properties.VariableNames{'GroupCount'} = 'n_participants';

        G = outerjoin(G, Gsub, ...
            'Keys', groupVars, ...
            'MergeKeys', true, ...
            'Type', 'left');

        if ~ismember('age_group', G.Properties.VariableNames)
            G.age_group = repmat("ALL", height(G), 1);
        end

        if ~ismember('condition', G.Properties.VariableNames)
            G.condition = repmat("ALL", height(G), 1);
        end

        G.band = repmat(string(bandLabel), height(G), 1);
        G.recap_family = repmat("signal", height(G), 1);
        G.recap_level = repmat(levelName, height(G), 1);

        G.percent_of_band_signals = 100 * G.n_signals ./ height(T);

        G = movevars(G, ...
            {'band','recap_family','recap_level','pair_name','age_group','condition'}, ...
            'Before', 1);

        rows{end+1,1} = G; %#ok<AGROW>
    end

    Tout = vertcat_fill_missing(rows{:});
end
