function [status, reasons, M] = flag_nan_and_empty(x, Q)
reasons = strings(0,1); status="PASS"; M=struct();
nan_frac = mean(isnan(x));
M.nan_frac = nan_frac;

x0 = x(~isnan(x));
if isempty(x0)
    status="FAIL"; reasons="all_nan"; return;
end
if nan_frac > Q.max_nan_frac
    status="FAIL"; reasons="nan_frac";
end
end