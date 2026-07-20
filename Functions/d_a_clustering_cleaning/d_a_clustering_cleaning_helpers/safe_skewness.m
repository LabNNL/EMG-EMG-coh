function y = safe_skewness(x)
    try
        y = skewness(x);
    catch
        y = NaN;
    end
end
