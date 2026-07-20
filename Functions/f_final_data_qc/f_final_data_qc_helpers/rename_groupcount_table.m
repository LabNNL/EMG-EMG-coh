function T = rename_groupcount_table(T, newName)

    if ~isempty(T) && ismember('GroupCount', T.Properties.VariableNames)
        T.Properties.VariableNames{'GroupCount'} = newName;
    end
end
