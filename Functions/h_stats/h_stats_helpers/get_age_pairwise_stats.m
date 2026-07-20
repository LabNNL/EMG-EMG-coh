function pairwiseStats = get_age_pairwise_stats(T, dvName, PH)
% Pairwise age-group comparisons across all available subjects
% Uses independent tests

    PH = fill_posthoc_defaults(PH);

    pairwiseStats = struct('g1', {}, 'g2', {}, 'p', {}, 'test_used', {}, 'n', {});

    if ~ismember(dvName, T.Properties.VariableNames)
        return;
    end

    T = T(~isnan(T.(dvName)), :);
    if isempty(T)
        return;
    end

    if iscategorical(T.age_group)
        T.age_group = removecats(T.age_group);
    end

    ageLevels = categories(T.age_group);
    if numel(ageLevels) < 2
        return;
    end

    k = 0;

    for i = 1:numel(ageLevels)-1
        for j = i+1:numel(ageLevels)
            a1 = ageLevels{i};
            a2 = ageLevels{j};

            y1 = T.(dvName)(T.age_group == a1);
            y2 = T.(dvName)(T.age_group == a2);

            p = NaN; testUsed = "NA"; nUsed = [NaN NaN];
            if numel(y1(~isnan(y1))) >= 2 && numel(y2(~isnan(y2))) >= 2
                [p, testUsed, nUsed] = run_independent_posthoc(y1, y2, PH);
            end

            k = k + 1;
            pairwiseStats(k).g1 = a1;
            pairwiseStats(k).g2 = a2;
            pairwiseStats(k).p = p;
            pairwiseStats(k).test_used = testUsed;
            pairwiseStats(k).n = nUsed;
        end
    end
end