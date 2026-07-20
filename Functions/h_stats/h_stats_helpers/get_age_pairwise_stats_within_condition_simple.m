function statsStruct = get_age_pairwise_stats_within_condition_simple(T, dvName, PH)

    PH = fill_posthoc_defaults(PH);

    statsStruct = struct('group', {}, 'g1', {}, 'g2', {}, 'p', {}, 'test_used', {}, 'n', {});
    ageLevels = categories(removecats(T.age_group));
    condLevels = categories(removecats(T.condition));

    k = 0;

    for ic = 1:numel(condLevels)
        condName = condLevels{ic};
        Tc = T(T.condition == condName, :);

        for i = 1:numel(ageLevels)-1
            for j = i+1:numel(ageLevels)
                a1 = ageLevels{i};
                a2 = ageLevels{j};

                y1 = Tc.(dvName)(Tc.age_group == a1);
                y2 = Tc.(dvName)(Tc.age_group == a2);

                p = NaN; testUsed = "NA"; nUsed = [NaN NaN];
                if numel(y1(~isnan(y1))) >= 2 && numel(y2(~isnan(y2))) >= 2
                    [p, testUsed, nUsed] = run_independent_posthoc(y1, y2, PH);
                end

                k = k + 1;
                statsStruct(k).group = condName;
                statsStruct(k).g1 = a1;
                statsStruct(k).g2 = a2;
                statsStruct(k).p = p;
                statsStruct(k).test_used = testUsed;
                statsStruct(k).n = nUsed;
            end
        end
    end
end
