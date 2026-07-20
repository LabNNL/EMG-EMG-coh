function pNorm = try_lilliefors_test(x)

    pNorm = NaN;
    x = x(~isnan(x));

    if numel(x) < 5
        return;
    end

    try
        [~, pNorm] = lillietest(x);
    catch
        pNorm = NaN;
    end
end