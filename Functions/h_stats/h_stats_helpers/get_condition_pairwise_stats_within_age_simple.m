function statsStruct = get_condition_pairwise_stats_within_age_simple(T, dvName, PH)

    PH = fill_posthoc_defaults(PH);

    statsStruct = struct('group', {}, 'g1', {}, 'g2', {}, 'p', {}, 'test_used', {}, 'n', {});
    ageLevels = categories(removecats(T.age_group));
    condLevels = categories(removecats(T.condition));

    k = 0;

    for ia = 1:numel(ageLevels)
        ageName = ageLevels{ia};
        Ta = T(T.age_group == ageName, :);

        for i = 1:numel(condLevels)-1
            for j = i+1:numel(condLevels)
                c1 = condLevels{i};
                c2 = condLevels{j};

                T1 = Ta(Ta.condition == c1, {'subject', dvName});
                T2 = Ta(Ta.condition == c2, {'subject', dvName});
                T1.Properties.VariableNames{2} = 'y1';
                T2.Properties.VariableNames{2} = 'y2';

                Tpair = innerjoin(T1, T2, 'Keys', 'subject');

                p = NaN; testUsed = "NA"; nUsed = NaN;
                if height(Tpair) >= 2
                    [p, testUsed, nUsed] = run_paired_posthoc(Tpair.y1, Tpair.y2, PH);
                end

                k = k + 1;
                statsStruct(k).group = ageName;
                statsStruct(k).g1 = c1;
                statsStruct(k).g2 = c2;
                statsStruct(k).p = p;
                statsStruct(k).test_used = testUsed;
                statsStruct(k).n = nUsed;
            end
        end
    end
end