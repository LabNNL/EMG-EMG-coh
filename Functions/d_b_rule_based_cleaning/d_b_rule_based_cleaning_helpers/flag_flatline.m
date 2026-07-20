function [status, reasons, M] = flag_flatline(x, fs, Q)
reasons = strings(0,1);
status  = "PASS";
M = struct();

x0 = x(~isnan(x));
if numel(x0) < 10
    status = "FAIL"; reasons = "too_few_samples"; 
    M.flatline_frac = NaN;
    return;
end

blockN = max(10, round(Q.flatline_block_sec * fs));
nb = floor(numel(x0) / blockN);

if nb < 2
    M.flatline_frac = NaN;
    return;
end

bstd = zeros(nb,1);
for b = 1:nb
    seg = x0((b-1)*blockN + (1:blockN));
    bstd(b) = std(seg);
end
medstd = median(bstd);

if medstd <= 0
    flat_frac = 1;
else
    flat_frac = mean(bstd < Q.flatline_std_frac * medstd);
end

M.flatline_frac = flat_frac;
% Only call it "flatline" if amplitude is small (true dropout), not huge contamination
rmsv = sqrt(mean(x0.^2));
p2p  = max(x0) - min(x0);

is_low_amp = (p2p < Q.flatline_p2p_max) || (rmsv < Q.flatline_rms_max);
M.p2p = p2p;
M.rms = rmsv;
M.is_low_amp = is_low_amp;

if is_low_amp
    if flat_frac > Q.max_flatline_frac_fail
        status = "FAIL"; reasons = "flatline";
    elseif flat_frac > Q.max_flatline_frac_warn
        status = "WARN"; reasons = "flatline_warn";
    end
end