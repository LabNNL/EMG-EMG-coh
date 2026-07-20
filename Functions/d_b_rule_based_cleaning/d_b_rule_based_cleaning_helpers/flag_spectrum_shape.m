function [status, reasons, M] = flag_spectrum_shape(x, fs, Q)
reasons = strings(0,1);
status  = "PASS";
M = struct();

x0 = x(~isnan(x));
if numel(x0) < fs
    M.low_over_mid = NaN;
    M.high_over_mid = NaN;
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

bandpow = @(f1,f2) sum(Ppos(fpos>=f1 & fpos<=f2));
Plow  = bandpow(Q.band_low(1),  Q.band_low(2));
Pmid  = bandpow(Q.band_mid(1),  min(Q.band_mid(2), fs/2-1));
Phigh = bandpow(Q.band_high(1), min(Q.band_high(2), fs/2-1));

if Pmid <= 0
    M.low_over_mid = NaN;
    M.high_over_mid = NaN;
    return;
end

low_over_mid  = Plow  / Pmid;
high_over_mid = Phigh / Pmid;

M.low_over_mid  = low_over_mid;
M.high_over_mid = high_over_mid;

if low_over_mid > Q.max_low_over_mid_fail || high_over_mid > Q.max_high_over_mid_fail
    status = Q.spectrum_fail * "FAIL" + (~Q.spectrum_fail) * "WARN"; % (we’ll avoid this trick below)
    if Q.spectrum_fail
        status = "FAIL"; reasons = "weird_spectrum";
    else
        status = "WARN"; reasons = "weird_spectrum_warn";
    end
elseif low_over_mid > Q.max_low_over_mid_warn || high_over_mid > Q.max_high_over_mid_warn
    status = "WARN"; reasons = "weird_spectrum_warn";
end
end