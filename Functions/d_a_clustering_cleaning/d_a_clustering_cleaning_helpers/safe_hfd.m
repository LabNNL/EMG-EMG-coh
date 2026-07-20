function y = safe_hfd(x, kmax)
    try
        y = Higuchi_FD(x, kmax);
    catch
        y = NaN;
    end
end