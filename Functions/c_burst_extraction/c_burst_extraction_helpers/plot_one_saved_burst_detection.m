
function plot_one_saved_burst_detection(C, subject, condition, leg, muscle)
%PLOT_ONE_SAVED_BURST_DETECTION Plot one selected burst-detection result.
%
% It first looks for BURSTS_DET in the base workspace.
% If not found, it loads the saved burst file for the requested subject.
%
% Example:
%   C = config_emg();
%   subject   = 'CTL_79';
%   condition = 'Flat';
%   leg       = 'right';
%   muscle    = 'EMG_TAdist_Concat';
%   plot_one_saved_burst_detection(C, subject, condition, leg, muscle)

    if nargin < 1 || isempty(C)
        C = config_emg();
    end

    IO = C.c_bursts.io;

    BURSTS_DET_local = [];

    % -------------------------------------------------
    % 1) Try base workspace first
    % -------------------------------------------------
    if evalin('base', 'exist(''BURSTS_DET'', ''var'')')
        tmp = evalin('base', 'BURSTS_DET');

        if isstruct(tmp) && ...
           isfield(tmp, subject) && ...
           isfield(tmp.(subject), condition) && ...
           isfield(tmp.(subject).(condition), leg) && ...
           isfield(tmp.(subject).(condition).(leg), muscle)

            BURSTS_DET_local = tmp;
            fprintf('Using BURSTS_DET found in base workspace.\n');
        end
    end

    % -------------------------------------------------
    % 2) Otherwise load saved file
    % -------------------------------------------------
    if isempty(BURSTS_DET_local)
        burstFile = fullfile(IO.out_dir, sprintf('%s%s', subject, IO.output_suffix));

        if ~exist(burstFile, 'file')
            error('Burst file not found: %s', burstFile);
        end

        S = load(burstFile, 'BURSTS_DET');

        if ~isfield(S, 'BURSTS_DET')
            error('BURSTS_DET not found in file: %s', burstFile);
        end

        BURSTS_DET_local = S.BURSTS_DET;
        fprintf('Loaded BURSTS_DET from file: %s\n', burstFile);
    end

    % -------------------------------------------------
    % 3) Validate requested entry
    % -------------------------------------------------
    if ~isfield(BURSTS_DET_local, subject)
        error('Subject %s not found in BURSTS_DET.', subject);
    end

    if ~isfield(BURSTS_DET_local.(subject), condition)
        error('Condition %s not found for subject %s.', condition, subject);
    end

    if ~isfield(BURSTS_DET_local.(subject).(condition), leg)
        error('Leg %s not found for %s | %s.', leg, subject, condition);
    end

    if ~isfield(BURSTS_DET_local.(subject).(condition).(leg), muscle)
        error('Muscle %s not found for %s | %s | %s.', muscle, subject, condition, leg);
    end

    entry = BURSTS_DET_local.(subject).(condition).(leg).(muscle);

    requiredFields = {'signal','envelope','burst_mask','bursts_idx','thresholds','fs'};
    for i = 1:numel(requiredFields)
        if ~isfield(entry, requiredFields{i})
            error('Missing field "%s" in saved burst entry.', requiredFields{i});
        end
    end

    % -------------------------------------------------
    % 4) Reuse your plotting function
    % -------------------------------------------------
    plot_burst_detection_full_signal( ...
        IO.png_dir, ...
        subject, condition, leg, muscle, entry.fs, ...
        entry.signal, ...
        entry.envelope, ...
        entry.burst_mask, ...
        entry.bursts_idx, ...
        entry.thresholds.values, ...
        entry.thresholds.start_idx, ...
        entry.thresholds.end_idx);

    fprintf('Plot created for %s | %s | %s | %s\n', subject, condition, leg, muscle);
    fprintf('Saved in: %s\n', IO.png_dir);
end

