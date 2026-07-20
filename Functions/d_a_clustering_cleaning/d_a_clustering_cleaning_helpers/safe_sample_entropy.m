function y = safe_sample_entropy(x, m, r)
    try
        y = sample_entropy(x, m, r);
    catch
        y = NaN;
    end
end
