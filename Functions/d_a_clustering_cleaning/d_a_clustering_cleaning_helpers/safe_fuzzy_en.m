function y = safe_fuzzy_en(x, m, r, n)
    try
        y = FuzzyEn(x, m, r, n);
        if numel(y) > 1
            y = y(1);
        end
    catch
        y = NaN;
    end
end