function [p, testUsed, nUsed] = run_independent_posthoc(y1, y2, cfg)

    p = NaN;
    testUsed = "NA";
    nUsed = [NaN NaN];

    y1 = y1(~isnan(y1));
    y2 = y2(~isnan(y2));

    n1 = numel(y1);
    n2 = numel(y2);
    nUsed = [n1 n2];

    if n1 < 2 || n2 < 2
        return;
    end

    switch lower(cfg.mode)

        case 'parametric'
            [~, p] = ttest2(y1, y2, 'Vartype', 'unequal');
            testUsed = "Welch t-test";

        case 'nonparametric'
            p = ranksum(y1, y2);
            testUsed = "Mann-Whitney rank-sum";

        otherwise
            useParam = should_use_parametric_independent(y1, y2, cfg);
            if useParam
                try
                    [~, p] = ttest2(y1, y2, 'Vartype', 'unequal');
                    testUsed = "Welch t-test";
                catch
                    p = ranksum(y1, y2);
                    testUsed = "Mann-Whitney rank-sum";
                end
            else
                try
                    p = ranksum(y1, y2);
                    testUsed = "Mann-Whitney rank-sum";
                catch
                    [~, p] = ttest2(y1, y2, 'Vartype', 'unequal');
                    testUsed = "Welch t-test";
                end
            end
    end
end

function tf = should_use_parametric_independent(y1, y2, cfg)

    tf = true;

    if numel(y1) < cfg.min_n_parametric || numel(y2) < cfg.min_n_parametric
        tf = false;
        return;
    end

    if has_extreme_outliers(y1, cfg.outlier_z_thresh) || has_extreme_outliers(y2, cfg.outlier_z_thresh)
        tf = false;
        return;
    end

    if cfg.use_normality_test
        p1 = try_lilliefors_test(y1);
        p2 = try_lilliefors_test(y2);
        if (~isnan(p1) && p1 < cfg.normality_alpha) || (~isnan(p2) && p2 < cfg.normality_alpha)
            tf = false;
            return;
        end
    end
end
