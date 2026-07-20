function [status, reasons, M] = flag_line_noise(x, fs, Q)
reasons = strings(0,1);
status  = "PASS";
M = struct();

x0 = x(~isnan(x));
if numel(x0) < fs
    M.line_ratio = NaN;
    return;
end

Lsec = min(numel(x0), round(Q.spec_sec * fs));
seg = double(x0(1:Lsec)); seg = seg - mean(seg);

Nfft = 2^nextpow2(numel(seg));
w = 0.5 - 0.5*cos(2*pi*(0:numel(seg)-1)'/(numel(seg)-1));
X = fft(seg .* w, Nfft);
P = (abs(X).^2) / Nfft;
faxis = (0:Nfft-1)'*(fs/Nfft);

half = 1:floor(Nfft/2);
fpos = faxis(half);
Ppos = P(half);

f1 = 10; f2 = min(450, fs/2 - 1);
totalMask = (fpos >= f1 & fpos <= f2);
totalPow = sum(Ppos(totalMask));

if totalPow <= 0
    M.line_ratio = NaN;
    return;
end

worst = 0;
for fhz = Q.line_hz_candidates
    m = (fpos >= (fhz - Q.line_bandwidth_hz) & fpos <= (fhz + Q.line_bandwidth_hz));
    worst = max(worst, sum(Ppos(m)) / totalPow);
end

M.line_ratio = worst;

if worst > Q.max_line_ratio_fail
    status = "FAIL"; reasons = "line_noise";
elseif worst > Q.max_line_ratio_warn
    status = "WARN"; reasons = "line_noise_warn";
end
end