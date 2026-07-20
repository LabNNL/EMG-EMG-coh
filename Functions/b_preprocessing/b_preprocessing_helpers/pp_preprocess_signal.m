function [x, y_filt, y] = pp_preprocess_signal(x, fs, P)
% DC removal
x = x - mean(x, 'omitnan');

% bandpass (zero-phase)
d_bp = designfilt('bandpassiir','FilterOrder',4, ...
    'HalfPowerFrequency1',P.bandpass(1), 'HalfPowerFrequency2',P.bandpass(2), ...
    'SampleRate',fs);
y = filtfilt(d_bp, x);

% optional notch
if P.use_notch
    d_notch = designfilt('bandstopiir','FilterOrder',4, ...
        'HalfPowerFrequency1',P.notch_hz-1,'HalfPowerFrequency2',P.notch_hz+1, ...
        'SampleRate',fs);
    y = filtfilt(d_notch, y);
end

y_filt = y; % store filtered pre-rectification

% rectify
if P.rectify
    y = abs(y);
end

% normalize
switch P.normalize
    case "none"
    case "zscore"
        mu = mean(y,'omitnan');
        sd = std(y,'omitnan');
        if sd > 0, y = (y - mu) / sd; end
    otherwise
        error("Unknown normalization: %s", P.normalize);
end
end