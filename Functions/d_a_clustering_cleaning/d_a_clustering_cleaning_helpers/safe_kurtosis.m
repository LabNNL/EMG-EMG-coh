function y = safe_kurtosis(x)
    try
        y = kurtosis(x);
    catch
        y = NaN;
    end
end
