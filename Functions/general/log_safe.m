function y = log_safe(x)

    x = double(x);
    x(x <= 0) = NaN;
    y = log(x);
end