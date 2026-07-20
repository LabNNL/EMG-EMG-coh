function [x_pad, orig_idx_in_padded, padInfo] = build_padded_signal_for_wavelet(x, Tseg, padCfg, whichSignal)

    x = x(:);
    n = numel(x);

    x_pad = x;
    orig_idx_in_padded = (1:n)';
    padInfo = struct();
    padInfo.mode = "none";
    padInfo.n_pre_samples = 0;
    padInfo.n_post_samples = 0;
    padInfo.pre_cycle_numbers = [];
    padInfo.post_cycle_numbers = [];

    if isempty(Tseg) || height(Tseg) == 0
        return;
    end

    if ~isfield(padCfg, 'mode') || isempty(padCfg.mode) || strcmpi(padCfg.mode, 'zero')
        padInfo.mode = "zero";
        return;
    end

    validModes = {'cycle_wrap', 'mirror'};
    if ~any(strcmpi(padCfg.mode, validModes))
        error('Unknown padding mode: %s', string(padCfg.mode));
    end

    if nargin < 4
        whichSignal = 1;
    end

    if whichSignal == 1
        startField = 'final_concat_start_idx_signal1';
        endField   = 'final_concat_end_idx_signal1';
    else
        startField = 'final_concat_start_idx_signal2';
        endField   = 'final_concat_end_idx_signal2';
    end

    if ~ismember(startField, Tseg.Properties.VariableNames) || ~ismember(endField, Tseg.Properties.VariableNames)
        warning('Tseg does not contain required fields for cycle_wrap padding. Falling back to zero-padding behavior.');
        padInfo.mode = "zero";
        return;
    end

    nCyclesPad = 1;
    if isfield(padCfg, 'n_cycles_each_side') && ~isempty(padCfg.n_cycles_each_side)
        %fprintf('Padding with %d cycles on each side based on padCfg.n_cycles_each_side.\n', round(padCfg.n_cycles_each_side));
        nCyclesPad = max(0, round(padCfg.n_cycles_each_side));
    end

    if nCyclesPad == 0
        %fprintf('n_cycles_each_side is set to 0. Returning original signal without padding.\n');
        padInfo.mode = "cycle_wrap";
        return;
    end

    nCyclesAvailable = height(Tseg);
    nCyclesPad = min(nCyclesPad, nCyclesAvailable);

    % Prepend: last cycles
        pre_idx = (nCyclesAvailable - nCyclesPad + 1):nCyclesAvailable;
    post_idx = 1:nCyclesPad;

    switch lower(string(padCfg.mode))

        case "cycle_wrap"
            % Prepend: last cycles copied as-is
            pre_sig = [];
            for ii = pre_idx
                s = Tseg.(startField)(ii);
                e = Tseg.(endField)(ii);

                if isnan(s) || isnan(e) || e <= s || s < 1 || e > n
                    continue;
                end
                pre_sig = [pre_sig; x(s:e)]; %#ok<AGROW>
            end

            % Append: first cycles copied as-is
            post_sig = [];
            for ii = post_idx
                s = Tseg.(startField)(ii);
                e = Tseg.(endField)(ii);

                if isnan(s) || isnan(e) || e <= s || s < 1 || e > n
                    continue;
                end
                post_sig = [post_sig; x(s:e)]; %#ok<AGROW>
            end

            padInfo.mode = "cycle_wrap";

        case "mirror"
            % Determine how many samples to mirror on each side
            nPreTarget = 0;
            for ii = post_idx
                s = Tseg.(startField)(ii);
                e = Tseg.(endField)(ii);

                if isnan(s) || isnan(e) || e <= s || s < 1 || e > n
                    continue;
                end
                nPreTarget = nPreTarget + (e - s + 1);
            end

            nPostTarget = 0;
            for ii = pre_idx
                s = Tseg.(startField)(ii);
                e = Tseg.(endField)(ii);

                if isnan(s) || isnan(e) || e <= s || s < 1 || e > n
                    continue;
                end
                nPostTarget = nPostTarget + (e - s + 1);
            end

            nPreTarget = min(nPreTarget, n);
            nPostTarget = min(nPostTarget, n);

            % Mirror the beginning of the signal for pre-padding
            pre_source = x(1:nPreTarget);
            pre_sig = flipud(pre_source);

            % Mirror the end of the signal for post-padding
            post_source = x(end-nPostTarget+1:end);
            post_sig = flipud(post_source);

            padInfo.mode = "mirror";

        otherwise
            error('Unknown padding mode: %s', string(padCfg.mode));
    end

    x_pad = [pre_sig; x; post_sig];

    nPre = numel(pre_sig);
    nPost = numel(post_sig);

    orig_idx_in_padded = (nPre + 1):(nPre + n);
    orig_idx_in_padded = orig_idx_in_padded(:);

    padInfo.n_pre_samples = nPre;
    padInfo.n_post_samples = nPost;
    padInfo.pre_cycle_numbers = pre_idx;
    padInfo.post_cycle_numbers = post_idx;
end