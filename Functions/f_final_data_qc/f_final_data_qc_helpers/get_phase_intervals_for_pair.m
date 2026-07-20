function phaseIntervals_sec = get_phase_intervals_for_pair(pairName, cycle_duration_sec, WCQ)
%GET_PHASE_INTERVALS_FOR_PAIR
% Return phase-of-interest interval(s) in seconds for one muscle pair.
%
% INPUTS
%   pairName            string or char
%   cycle_duration_sec  scalar > 0
%   WCQ                 C.f_final_signals.params.wavelet_contamination_qc
%
% OUTPUT
%   phaseIntervals_sec  Nx2 matrix of [start_sec end_sec]
%                       N = 1 for normal interval
%                       N = 2 for wrapped interval across cycle boundary
%
% EXAMPLES
%   If pair window is 0 -> 60 and cycle_duration_sec = 1.0
%       returns [0.00 0.60]
%
%   If pair window is 60 -> 20 and cycle_duration_sec = 1.0
%       returns [0.60 1.00
%                0.00 0.20]

    pairName = char(string(pairName));

    if ~isscalar(cycle_duration_sec) || ~isfinite(cycle_duration_sec) || cycle_duration_sec <= 0
        error('cycle_duration_sec must be a positive finite scalar.');
    end

    if ~isfield(WCQ, 'phase_windows_pct') || ~isstruct(WCQ.phase_windows_pct)
        error('WCQ.phase_windows_pct is missing or invalid.');
    end

    if ~isfield(WCQ.phase_windows_pct, pairName)
        error('No phase window defined in config for pair "%s".', pairName);
    end

    phaseDef = WCQ.phase_windows_pct.(pairName);

    if ~isfield(phaseDef, 'start_pct') || ~isfield(phaseDef, 'end_pct')
        error('Phase window for pair "%s" must contain start_pct and end_pct.', pairName);
    end

    start_pct = double(phaseDef.start_pct);
    end_pct   = double(phaseDef.end_pct);

    if ~isfinite(start_pct) || ~isfinite(end_pct)
        error('start_pct and end_pct must be finite for pair "%s".', pairName);
    end

    if start_pct < 0 || start_pct > 100 || end_pct < 0 || end_pct > 100
        error('start_pct and end_pct must both be within [0, 100] for pair "%s".', pairName);
    end

    start_sec = cycle_duration_sec * start_pct / 100;
    end_sec   = cycle_duration_sec * end_pct   / 100;

    % Case 1: normal interval, e.g. 0 -> 60
    if start_pct < end_pct
        phaseIntervals_sec = [start_sec, end_sec];

    % Case 2: wrapped interval, e.g. 60 -> 20
    elseif start_pct > end_pct
        phaseIntervals_sec = [ ...
            start_sec,         cycle_duration_sec; ...
            0,                 end_sec ...
            ];

    % Case 3: start == end
    % Interpret as full cycle by default
    else
        phaseIntervals_sec = [0, cycle_duration_sec];
    end
end
