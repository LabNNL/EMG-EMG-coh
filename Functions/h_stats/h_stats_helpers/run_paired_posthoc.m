function [p, testUsed, nUsed] = run_paired_posthoc(y1, y2, cfg)

    p = NaN;
    testUsed = "NA";
    nUsed = NaN;

    y1 = y1(:);
    y2 = y2(:);

    valid = ~isnan(y1) & ~isnan(y2);
    y1 = y1(valid);
    y2 = y2(valid);

    d = y1 - y2;
    nUsed = numel(d);

    if nUsed < 2
        return;
    end

    switch lower(cfg.mode)

        case 'parametric'
            [~, p] = ttest(y1, y2);
            testUsed = "paired t-test";

        case 'nonparametric'
            p = signrank(y1, y2);
            testUsed = "Wilcoxon signed-rank";

        otherwise
            useParam = should_use_parametric_paired(d, cfg);
            if useParam
                try
                    [~, p] = ttest(y1, y2);
                    testUsed = "paired t-test";
                catch
                    p = signrank(y1, y2);
                    testUsed = "Wilcoxon signed-rank";
                end
            else
                try
                    p = signrank(y1, y2);
                    testUsed = "Wilcoxon signed-rank";
                catch
                    [~, p] = ttest(y1, y2);
                    testUsed = "paired t-test";
                end
            end
    end
end

function tf = should_use_parametric_paired(d, cfg)

    tf = true;

    if numel(d) < cfg.min_n_parametric
        tf = false;
        return;
    end

    if has_extreme_outliers(d, cfg.outlier_z_thresh)
        tf = false;
        return;
    end

    if cfg.use_normality_test
        pNorm = try_lilliefors_test(d);
        if ~isnan(pNorm) && pNorm < cfg.normality_alpha
            tf = false;
            return;
        end
    end
end