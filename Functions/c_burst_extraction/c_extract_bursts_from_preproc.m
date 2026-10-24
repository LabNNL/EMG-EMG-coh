%% c_extract_bursts_from_preproc
% Burst detection configuration from preprocessed concatenated EMG signals.
%
% GENERAL PRINCIPLE
% -------------------------------------------------------------------------
% This step detects candidate EMG bursts on each concatenated preprocessed
% signal (subject × condition × leg × muscle).
%
% The detection pipeline is:
%   1) compute the envelope as low-pass(abs(signal))
%   2) compute a percentile-based threshold within each time window
%   3) build a binary burst mask from the thresholded envelope
%   4) optionally remove flat / near-flat regions
%   5) optionally clean the mask by removing short runs, filling short gaps,
%      removing very short bursts again, or removing very long bursts
%   6) convert the final mask into burst start/end indices
%
% INPUT / OUTPUT
% -------------------------------------------------------------------------
% Input:
%   - *_EMG_PREPROC.mat files from the preprocessing step
%
% Output:
%   - *_EMG_BURSTS.mat files containing:
%       * original useful signal metadata copied from EMG_PREPROC
%       * envelope used for detection
%       * burst mask
%       * burst start/end indices
%       * burst-level metadata table
%       * threshold values and detection parameters
%
% MAIN PARAMETERS THAT CONTROL BEHAVIOR
% -------------------------------------------------------------------------
% Envelope computation:
%   - C.c_bursts.params.env_lowpass_hz
%   - C.c_bursts.params.env_lowpass_order
%
% Flatline / low-variance rejection:
%   - C.c_bursts.params.flat_global_std_thr
%   - C.c_bursts.params.flat_local_std_thr
%   - C.c_bursts.params.local_std_window_sec
%
% Thresholding:
%   - C.c_bursts.params.window_minutes
%   - C.c_bursts.params.threshold_prctile
%
% Burst-mask cleanup:
%   - C.c_bursts.params.min_run_1
%   - C.c_bursts.params.fill_zero_gap
%   - C.c_bursts.params.min_run_2
%   - C.c_bursts.params.max_run
%
% Toggle cleanup steps on / off:
%   - C.c_bursts.params.apply_remove_short_1
%   - C.c_bursts.params.apply_fill_short_zeros
%   - C.c_bursts.params.apply_remove_short_2
%   - C.c_bursts.params.apply_remove_long_runs
%
% QC / visualization:
%   - C.c_bursts.qc.save_png
%   - C.c_bursts.qc.max_png_per_subject
%   - C.c_bursts.qc.save_random_burst_plots
%   - C.c_bursts.qc.n_random_burst_plots
%   - C.c_bursts.qc.random_seed
%   - C.c_bursts.qc.delete_old_png
%
% CURRENT CHOICE
% -------------------------------------------------------------------------
% The current settings are intentionally rather inclusive, to avoid removing
% too many candidate bursts at this stage. Stricter settings can be applied
% later through QC, feature-based cleaning, clustering, or by increasing the
% duration constraints in the config.

function c_extract_bursts_from_preproc()

    %% ===================== CONFIG =====================
    C = config_emg();

    IO = C.c_bursts.io;
    B  = C.c_bursts.params;
    Q  = C.c_bursts.qc;
    I  = C.c_bursts.inspect;

    if ~exist(IO.out_dir, 'dir')
        mkdir(IO.out_dir);
    end

    addpath(genpath(C.paths.helpers.burst_extraction));
    addpath(genpath(C.paths.helpers.general));

    files = dir(fullfile(IO.in_dir, IO.input_pattern));
    fprintf('Found %d preprocessed files.\n', numel(files));

    plotCandidates = {};
    pc = 0;

    %% ===================== MAIN LOOP =====================

    for f = 1:numel(files)
        inFile = fullfile(files(f).folder, files(f).name);
        S = load(inFile);

        if ~isfield(S, 'EMG_PREPROC')
            warning('Skipping %s: EMG_PREPROC not found.', files(f).name);
            continue;
        end

        EMG_PREPROC = S.EMG_PREPROC;
        subjFields = fieldnames(EMG_PREPROC);
        if numel(subjFields) ~= 1
            warning('Expected one subject field in %s. Using first one.', files(f).name);
        end
        subjID = subjFields{1};

        fprintf('\n=== Burst extraction: %s ===\n', subjID);

        BURSTS_DET = struct();
        BURSTS_DET.meta.source_file = inFile;
        BURSTS_DET.meta.subject     = subjID;
        BURSTS_DET.meta.created_on  = char(datetime('now'));
        BURSTS_DET.meta.params      = B;
        BURSTS_DET.(subjID).meta = EMG_PREPROC.(subjID).meta;
        BURSTS_SUMMARY = table();


        pngCount = 0;
        i = 0;
        conds = fieldnames(EMG_PREPROC.(subjID));
        for ic = 1:numel(conds)
            cond = conds{ic};
            if strcmp(cond, 'meta'), continue; end
            if ~isstruct(EMG_PREPROC.(subjID).(cond)), continue; end

            legs = fieldnames(EMG_PREPROC.(subjID).(cond));
            for il = 1:numel(legs)
                leg = legs{il};
                if ~isstruct(EMG_PREPROC.(subjID).(cond).(leg)), continue; end

                musFields = fieldnames(EMG_PREPROC.(subjID).(cond).(leg));
                for im = 1:numel(musFields)
                    mf = musFields{im};

                    % Keep same convention as preprocessing: only *_Concat
                    if ~endsWith(mf, '_Concat')
                        continue;
                    end

                    entry = EMG_PREPROC.(subjID).(cond).(leg).(mf);

                    if ~isfield(entry, 'signal') || isempty(entry.signal)
                        continue;
                    end

                    x = entry.signal(:);

                    % Sampling rate: prefer stored field if available, otherwise config
                    fs = get_fs_from_entry_or_config(entry, C);

                    % Envelope filter
                    [b, a] = butter(B.env_lowpass_order, 2*B.env_lowpass_hz/fs, 'low');

                    % Match old code logic
                    x_env = filtfilt(b, a, abs(x));

                    win_samples = round(fs * 60 * B.window_minutes);
                    n = numel(x);

                    % Initialize outputs
                    thr_values      = [];
                    thr_start_idx   = [];
                    thr_end_idx     = [];
                    burst_mask_full = false(n,1);
                    burst_list_all  = [];

                    minute = 1;
                    for iStart = 1:win_samples:n
                        iEnd = min(iStart + win_samples - 1, n);

                        x_win     = x(iStart:iEnd);
                        x_env_win = x_env(iStart:iEnd);

                        if std(x_env_win, 'omitnan') < B.flat_global_std_thr || max(x_env_win) <= 0
                            thr = NaN;
                            burst_mask = false(numel(x_env_win),1);

                            fprintf(['In subject %s, cond %s, leg %s, muscle %s, minute %d: ' 'Envelope is flat or zero. Marking no bursts.\n'], subjID, cond, leg, mf, minute);

                        else
                            thr = prctile(x_env_win, B.threshold_prctile);

                            % strict thresholding
                            burst_mask = x_env_win > thr;

                            % local flatline rejection
                            local_std = movstd(x_env_win, round(B.local_std_window_sec * fs), 'omitnan');
                            flat_mask = local_std < B.flat_local_std_thr;
                            if any(flat_mask)
                                fprintf(['In subject %s, cond %s, leg %s, muscle %s, minute %d: ' 'Found flatline segments. Removing from bursts.\n'], subjID, cond, leg, mf, minute);
                            end
                            burst_mask(flat_mask) = false;

                            % Options to clean the burst mask by removing short runs, filling short gaps, or removing very long runs
                            if B.apply_remove_short_1
                                burst_mask = remove_short_runs_local(burst_mask, B.min_run_1);
                            end

                            if B.apply_fill_short_zeros
                                burst_mask = fill_short_zeros_local(burst_mask, B.fill_zero_gap);
                            end

                            if B.apply_remove_short_2
                                burst_mask = remove_short_runs_local(burst_mask, B.min_run_2);
                            end

                            if B.apply_remove_long_runs
                                burst_mask = remove_long_runs_local(burst_mask, B.max_run);
                            end
                        end

                        % Convert local mask to local bursts
                        bursts_local = logical_to_runs_local(burst_mask);

                        % Convert to concatenated/global indices
                        if ~isempty(bursts_local)
                            bursts_global = bursts_local + (iStart - 1);
                        else
                            bursts_global = zeros(0,2);
                        end

                        burst_mask_full(iStart:iEnd) = burst_mask;
                        burst_list_all = [burst_list_all; bursts_global];

                        thr_values(minute,1)    = thr;
                        thr_start_idx(minute,1) = iStart;
                        thr_end_idx(minute,1)   = iEnd;

                        % Optional diagnostic plot
                        if Q.save_png && pngCount < Q.max_png_per_subject
                            pngCount = pngCount + 1;
                            save_burst_plot(IO.png_dir, subjID, cond, leg, mf, minute, x_win, x_env_win, thr, bursts_local, fs);
                        end

                        minute = minute + 1;
                    end
                    BURSTS_DET = ensure_fields(BURSTS_DET, subjID, cond, leg);

                    % keep only useful metadata from preproc entry
                    BURSTS_DET.(subjID).(cond).(leg).(mf).signal        = entry.signal;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).signal_raw    = entry.signal_raw;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).n_cycles      = entry.n_cycles;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).cycle_lengths = entry.cycle_lengths;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).cycle_starts  = entry.cycle_starts;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).cycle_ends    = entry.cycle_ends;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).toe_off_concat= entry.toe_off_concat;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).toe_off_in_cycle= entry.toe_off_in_cycle;

                    BURSTS_DET.(subjID).(cond).(leg).(mf).trial_id      = entry.trial_id;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).orig_start    = entry.orig_start;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).orig_end      = entry.orig_end;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).fs            = fs;

                    % build burst table with cycle linkage
                    bursts_table = make_bursts_table( subjID, cond, leg, mf, fs, burst_list_all, x_env, entry.cycle_starts, entry.cycle_ends);

                    % burst outputs
                    BURSTS_DET.(subjID).(cond).(leg).(mf).envelope = x_env;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).burst_mask = burst_mask_full;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).bursts_idx = burst_list_all;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).bursts_table = bursts_table;

                    BURSTS_DET.(subjID).(cond).(leg).(mf).thresholds.values = thr_values;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).thresholds.start_idx = thr_start_idx;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).thresholds.end_idx = thr_end_idx;
                    BURSTS_DET.(subjID).(cond).(leg).(mf).thresholds.window_minutes = B.window_minutes;

                    BURSTS_DET.(subjID).(cond).(leg).(mf).burst_params = B;

                    BURSTS_SUMMARY = [BURSTS_SUMMARY; bursts_table];

                    if Q.save_random_burst_plots
                        pc = pc + 1;
                        plotCandidates(pc,:) = { subjID, cond, leg, mf, fs, x, x_env, burst_mask_full, burst_list_all, thr_values, thr_start_idx, thr_end_idx};
                    end
                end
            end
        end

        outFile = fullfile(IO.out_dir, sprintf('%s_EMG_BURSTS.mat', subjID));
        save(outFile, 'BURSTS_DET', 'BURSTS_SUMMARY', '-v7.3');
        % fprintf('Saved: %s\n', outFile);

    end

    fprintf('\nDone with burst extraction.\n');

    %% ===================== Optional random burst plots =====================

    if Q.save_random_burst_plots && ~isempty(plotCandidates)
        fprintf('\nSaving random burst detection plots...\n');
        rng(Q.random_seed);
        nAvail = size(plotCandidates,1);
        nPlot  = min(Q.n_random_burst_plots, nAvail);

        idx = randperm(nAvail, nPlot);

        BURST_PLOT_DIR = IO.png_dir;
        if ~exist(BURST_PLOT_DIR, 'dir')
            mkdir(BURST_PLOT_DIR);
        elseif Q.delete_old_png
            delete(fullfile(BURST_PLOT_DIR, '*.png'));
        end

        for i = 1:numel(idx)
            fprintf('  Plotting candidate %d/%d (row %d in plotCandidates)...\n', i, nPlot, idx(i));
            row = idx(i);

            subjID        = plotCandidates{row,1};
            cond          = plotCandidates{row,2};
            leg           = plotCandidates{row,3};
            mf            = plotCandidates{row,4};
            fs            = plotCandidates{row,5};
            x             = plotCandidates{row,6};
            x_env         = plotCandidates{row,7};
            burst_mask    = plotCandidates{row,8};
            bursts_idx    = plotCandidates{row,9};
            thr_values    = plotCandidates{row,10};
            thr_start_idx = plotCandidates{row,11};
            thr_end_idx   = plotCandidates{row,12};

            plot_burst_detection_full_signal( BURST_PLOT_DIR, subjID, cond, leg, mf, fs, x, x_env, burst_mask, bursts_idx, thr_values, thr_start_idx, thr_end_idx);
        end
    end

    %% ===================== Optional: plot one selected burst signal =====================
    C = config_emg();

    subject   = 'CTL_79';
    condition = 'Flat';
    leg       = 'right';
    muscle    = 'EMG_TAdist_Concat';

    plot_one_saved_burst_detection(C, subject, condition, leg, muscle);

    %% ===================== Inspecting saved burst files =====================

    if I.inspect_one_output
        % Explore .mat saved with disp_tree
        qc_files = dir(fullfile(IO.out_dir, ['*' IO.output_suffix]));
        if ~isempty(qc_files)
            sample_file = fullfile(qc_files(1).folder, qc_files(1).name);
            fprintf("\nInspecting structure of a sample bursts file:\n%s\n", sample_file);
            S = load(sample_file);
            if isfield(S, 'BURSTS_DET')
                disp_tree(S.BURSTS_DET, I.inspect_depth);
            end
        end
    end
end