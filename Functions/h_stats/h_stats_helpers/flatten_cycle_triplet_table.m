function Tflat = flatten_cycle_triplet_table(T)

    if isempty(T)
        Tflat = table();
        return;
    end

    rows = {};
    ri = 0;

    for i = 1:height(T)

        tvec = unwrap_table_vector_entry(T.Time_percent, i);
        a    = unwrap_table_vector_entry(T.Alpha_curve, i);
        b    = unwrap_table_vector_entry(T.Beta_curve, i);
        g    = unwrap_table_vector_entry(T.Gamma_curve, i);

        if isempty(tvec) || isempty(a) || isempty(b) || isempty(g)
            continue;
        end

        tvec = tvec(:);
        a = a(:);
        b = b(:);
        g = g(:);

        n = min([numel(tvec), numel(a), numel(b), numel(g)]);
        if n == 0
            continue;
        end

        tvec = tvec(1:n);
        a = a(1:n);
        b = b(1:n);
        g = g(1:n);

        for k = 1:n
            ri = ri + 1;
            rows(ri,:) = { string(T.subject(i)), string(T.age_group(i)), string(T.condition(i)), string(T.pair_name(i)), tvec(k), a(k), b(k), g(k), T.POI_StartPercent(i), T.POI_EndPercent(i) };
        end
    end

    if isempty(rows)
        Tflat = table();
        return;
    end

    Tflat = cell2table(rows, 'VariableNames', { 'subject','age_group','condition','pair_name','time_percent', 'Alpha','Beta','Gamma','POI_StartPercent','POI_EndPercent'});
end