function Tflat = flatten_cycle_triplet_table(T)
% One row per time point, one column per band (from the <Band>_curve columns)

    if isempty(T)
        Tflat = table();
        return;
    end

    curveVars = T.Properties.VariableNames(endsWith(T.Properties.VariableNames, '_curve'));
    bandNames = erase(curveVars, '_curve');

    rows = {};
    ri = 0;

    for i = 1:height(T)

        tvec = unwrap_table_vector_entry(T.Time_percent, i);
        curves = cellfun(@(v) unwrap_table_vector_entry(T.(v), i), curveVars, 'UniformOutput', false);

        if isempty(tvec) || any(cellfun(@isempty, curves))
            continue;
        end

        n = min([numel(tvec), cellfun(@numel, curves)]);
        if n == 0
            continue;
        end

        for k = 1:n
            ri = ri + 1;
            rows(ri,:) = [{ string(T.subject(i)), string(T.age_group(i)), string(T.condition(i)), string(T.pair_name(i)), tvec(k)}, ...
                cellfun(@(c) c(k), curves, 'UniformOutput', false), {T.POI_StartPercent(i), T.POI_EndPercent(i)}]; %#ok<AGROW>
        end
    end

    if isempty(rows)
        Tflat = table();
        return;
    end

    Tflat = cell2table(rows, 'VariableNames', [{ 'subject','age_group','condition','pair_name','time_percent'}, bandNames, {'POI_StartPercent','POI_EndPercent'}]);
end
