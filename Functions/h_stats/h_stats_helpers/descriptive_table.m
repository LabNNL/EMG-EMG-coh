function Td = descriptive_table(T, dvName, groupVars)

    groupingCols = cell(1, numel(groupVars));
    for i = 1:numel(groupVars)
        groupingCols{i} = T.(groupVars{i});
    end

    [G, outCols{1:numel(groupVars)}] = findgroups(groupingCols{:}); %#ok<AGROW>

    meanVals = splitapply(@(x) mean(x, 'omitnan'), T.(dvName), G);
    stdVals  = splitapply(@(x) std(x, 'omitnan'),  T.(dvName), G);
    medVals  = splitapply(@(x) median(x, 'omitnan'), T.(dvName), G);
    nVals    = splitapply(@(x) sum(~isnan(x)), T.(dvName), G);

    Td = table();
    for i = 1:numel(groupVars)
        Td.(groupVars{i}) = outCols{i};
    end
    Td.mean_value = meanVals;
    Td.std_value  = stdVals;
    Td.median_value = medVals;
    Td.n = nVals;
end