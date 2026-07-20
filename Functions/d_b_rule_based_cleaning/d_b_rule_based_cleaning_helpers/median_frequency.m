function mf = median_frequency(seg, fs)
    mf = NaN;
    seg = seg(:);
    seg = seg(~isnan(seg));

    if numel(seg) < max(64, round(0.03*fs))
        return;
    end

    seg = double(seg);
    seg = seg - mean(seg);

    Nfft = 2^nextpow2(numel(seg));
    w = 0.5 - 0.5*cos(2*pi*(0:numel(seg)-1)'/(numel(seg)-1)); % Hann
    X = fft(seg .* w, Nfft);
    P = abs(X).^2;

    half = 1:floor(Nfft/2);
    f = (half-1)' * (fs/Nfft);
    P = P(half);

    if isempty(P) || all(~isfinite(P)) || sum(P,'omitnan') <= 0
        return;
    end

    cumP = cumsum(P, 'omitnan');
    idx = find(cumP >= cumP(end)/2, 1, 'first');

    if ~isempty(idx)
        mf = f(idx);
    end
end