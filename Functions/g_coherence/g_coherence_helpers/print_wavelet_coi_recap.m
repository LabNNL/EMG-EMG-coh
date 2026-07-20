function print_wavelet_coi_recap(W)

    fprintf('\n====================================================\n');
    fprintf('WAVELET / COI RECAP\n');
    fprintf('====================================================\n');

    fprintf('Freq range     : %.2f to %.2f Hz\n', W.FreqMin, W.FreqMax);
    fprintf('Resolution     : %.3f\n', W.Resolution);
    fprintf('Wave number    : %.3f\n', W.WaveNumber);

    % Use a dummy signal only to recover the actual COI returned by the
    % current wavelet implementation with the current parameters.
    fs_dummy = 1000;              % arbitrary high-enough fs for recap
    dur_dummy_s = 20;             % long enough to see stable COI behaviour
    x_dummy = zeros(round(fs_dummy * dur_dummy_s), 1);

    Args = WaveletParameters(W.FreqMin, W.FreqMax, W.Resolution, W.WaveNumber, fs_dummy);
    [~, period, ~, coi] = wavelet( ...
        x_dummy, Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);

    Freq = 1 ./ period;

    % COI returned by the transform is in period units along time.
    % At the very edge, the COI is smallest; moving inward it increases.
    % A practical recap is to report the maximum edge-affected duration
    % for representative frequencies using the relation:
    % edge-affected zone extends until coi >= target period.
    t = (0:numel(coi)-1) / fs_dummy;
    t_from_left = t - t(1);
    t_from_right = t(end) - t;

    report_one_freq(W.FreqMin, 'FreqMin', coi, t_from_left, t_from_right);
    report_one_freq(W.FreqMax, 'FreqMax', coi, t_from_left, t_from_right);

    if isfield(W, 'FreqBands')
        bandNames = fieldnames(W.FreqBands);
        for i = 1:numel(bandNames)
            band = bandNames{i};
            f_low = W.FreqBands.(band)(1);
            report_one_freq(f_low, sprintf('%s low edge', band), coi, t_from_left, t_from_right);
        end
    end

    fprintf('Interpretation : lower frequencies have larger COI / wider edge-affected zones.\n');
    fprintf('                Values above are approximate durations per signal edge.\n');
    fprintf('====================================================\n\n');
end

function report_one_freq(freq_hz, label, coi, t_from_left, t_from_right)

    target_period = 1 / freq_hz;

    idx_left = find(coi >= target_period, 1, 'first');
    idx_right = find(flipud(coi(:)) >= target_period, 1, 'first');

    if isempty(idx_left)
        left_s = NaN;
    else
        left_s = t_from_left(idx_left);
    end

    if isempty(idx_right)
        right_s = NaN;
    else
        right_s = t_from_right(end - idx_right + 1);
    end

    approx_s = max([left_s, right_s], [], 'omitnan');

    fprintf('%-14s @ %7.2f Hz : edge-affected zone ≈ %.4f s per side', label, freq_hz, approx_s);

    if ~isnan(left_s) && ~isnan(right_s)
        fprintf('  (left %.4f s | right %.4f s)\n', left_s, right_s);
    else
        fprintf('\n');
    end
end
