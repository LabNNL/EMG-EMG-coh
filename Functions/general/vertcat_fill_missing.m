function Tout = vertcat_fill_missing(varargin)

    tables = varargin;
    tables = tables(~cellfun(@isempty, tables));

    if isempty(tables)
        Tout = table();
        return;
    end

    allVars = {};
    for i = 1:numel(tables)
        allVars = union(allVars, tables{i}.Properties.VariableNames, 'stable');
    end

    for i = 1:numel(tables)
        T = tables{i};
        missingVars = setdiff(allVars, T.Properties.VariableNames, 'stable');

        for j = 1:numel(missingVars)
            v = missingVars{j};
            T.(v) = repmat(missing, height(T), 1);
        end

        tables{i} = T(:, allVars);
    end

    Tout = vertcat(tables{:});
end