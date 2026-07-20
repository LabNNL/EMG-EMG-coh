function pairwiseStats = get_condition_pairwise_stats(T, dvName, PH)
% Pairwise condition comparisons across all available subjects
% Uses paired tests because condition is within-subject

    PH = fill_posthoc_defaults(PH);

    pairwiseStats = struct('g1', {}, 'g2', {}, 'p', {}, 'test_used', {}, 'n', {});

    if ~ismember(dvName, T.Properties.VariableNames)
        return;
    end

    T = T(~isnan(T.(dvName)), :);
    if isempty(T)
        return;
    end

    if iscategorical(T.condition)
        T.condition = removecats(T.condition);
    end
    if iscategorical(T.subject)
        T.subject = removecats(T.subject);
    end

    condLevels = categories(T.condition);
    if numel(condLevels) < 2
        return;
    end

    k = 0;

    for i = 1:numel(condLevels)-1
        for j = i+1:numel(condLevels)
            c1 = condLevels{i};
            c2 = condLevels{j};

            T1 = T(T.condition == c1, {'subject', dvName});
            T2 = T(T.condition == c2, {'subject', dvName});

            T1.Properties.VariableNames{2} = 'y1';
            T2.Properties.VariableNames{2} = 'y2';

            Tpair = innerjoin(T1, T2, 'Keys', 'subject');

            p = NaN; testUsed = "NA"; nUsed = NaN;
            if height(Tpair) >= 2
                [p, testUsed, nUsed] = run_paired_posthoc(Tpair.y1, Tpair.y2, PH);
            end

            k = k + 1;
            pairwiseStats(k).g1 = c1;
            pairwiseStats(k).g2 = c2;
            pairwiseStats(k).p = p;
            pairwiseStats(k).test_used = testUsed;
            pairwiseStats(k).n = nUsed;
        end
    end
end
