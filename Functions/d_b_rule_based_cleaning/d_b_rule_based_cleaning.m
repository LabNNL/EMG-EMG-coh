%% d_b_rule_based_cleaning.m
% Burst-level QC after burst extraction
%
% INPUT:
%   *_EMG_PREPROC.mat
%   *_EMG_BURSTS.mat
%
% OUTPUT:
%   QC_bursts_summary.csv   -> one row per burst
%   QC_bursts.mat           -> hierarchical struct with signal + burst QC
%
% Logic:
%   1) reject whole concatenated signals only if fundamentally unusable
%   2) otherwise classify each detected burst independently as keep/reject
function d_b_rule_based_cleaning()

    C = config_emg();

    IO = C.d_rule_based.io;
    Q  = C.d_rule_based.params;
    R  = C.d_rule_based.qc;

    addpath(genpath(C.paths.helpers.general));
    addpath(genpath(C.paths.helpers.rule_based_cleaning));

    if ~exist(IO.out_dir,'dir'), mkdir(IO.out_dir); end
    if ~exist(IO.csv_dir,'dir'), mkdir(IO.csv_dir); end
    if ~exist(IO.plot_dir,'dir')
        mkdir(IO.plot_dir);
    elseif R.delete_old_plots
        delete(fullfile(IO.plot_dir, '*.png'));
    end
    if ~exist(IO.signal_fail_plot_dir,'dir')
        mkdir(IO.signal_fail_plot_dir);
    elseif R.delete_old_plots
        delete(fullfile(IO.signal_fail_plot_dir, '*.png'));
    end
    Participants = C.participants.all;
    Conditions   = C.design.conditions;
    Legs         = C.design.legs;
    MuscleFields = C.design.muscleFields;

    %% ===================== MAP INPUT FILES =====================
    preprocFiles = dir(fullfile(IO.preproc_dir, IO.preproc_pattern));
    preprocMap = containers.Map('KeyType','char','ValueType','char');
    for k = 1:numel(preprocFiles)
        tok = regexp(preprocFiles(k).name, '^(.*)_EMG_PREPROC\.mat$', 'tokens', 'once');
        if ~isempty(tok)
            preprocMap(tok{1}) = fullfile(preprocFiles(k).folder, preprocFiles(k).name);
        end
    end

    burstFiles = dir(fullfile(IO.bursts_dir, IO.bursts_pattern));
    burstMap = containers.Map('KeyType','char','ValueType','char');
    for k = 1:numel(burstFiles)
        tok = regexp(burstFiles(k).name, '^(.*)_EMG_BURSTS\.mat$', 'tokens', 'once');
        if ~isempty(tok)
            burstMap(tok{1}) = fullfile(burstFiles(k).folder, burstFiles(k).name);
        end
    end

    assert(~isempty(preprocFiles), 'No preproc files found.');
    assert(~isempty(burstFiles),   'No burst files found.');

    %% ===================== SETTINGS =====================
    plotCount = 0;

    BURST_QC = struct();
    rows = {};
    ri = 0;

    %% ===================== MAIN LOOP =====================
    plotCandidates = {};
    pc = 0;
    i = 0;  % flag for first iteration to print cycle info

    signalFailCandidates = {};
    sfc = 0;

    fprintf('\nStarting burst-level QC across all participants and conditions...\n');
    fprintf('Recap of important parameters (what is enabled and what is disabled):\n');
    fprintf('  - Duration too short enabled: %d\n', Q.burst.duration.too_short_enable);
    fprintf('  - Duration too long enabled: %d\n', Q.burst.duration.too_long_enable);
    fprintf('  - Spike detection enabled: %d\n', Q.burst.spike.enable);
    fprintf('  - Plateau detection enabled: %d\n', Q.burst.plateau.enable);
    fprintf('  - Spectrum analysis enabled: %d\n', Q.burst.spec.enable);
    fprintf('  - Median frequency check enabled: %d\n', Q.burst.medfreq.enable);
    fprintf('  - Absolute amplitude check enabled: %d\n', Q.burst.abs.enable);


    for iP = 1:numel(Participants)
        subjID = Participants{iP};
        fprintf('\n=== Burst QC: %s ===\n', subjID);

        if ~isKey(preprocMap, subjID) || ~isKey(burstMap, subjID)
            fprintf('  Missing preproc or burst file.\n');
            continue;
        end

        Lp = load(preprocMap(subjID));
        Lb = load(burstMap(subjID));

        if ~isfield(Lp,'EMG_PREPROC') || ~isfield(Lp.EMG_PREPROC, subjID)
            fprintf('  Missing EMG_PREPROC struct.\n');
            continue;
        end
        if ~isfield(Lb,'BURSTS_DET') || ~isfield(Lb.BURSTS_DET, subjID)
            fprintf('  Missing BURSTS_DET struct.\n');
            continue;
        end

        for ic = 1:numel(Conditions)
            cond = Conditions{ic};
            if ~isfield(Lp.EMG_PREPROC.(subjID), cond), continue; end
            if ~isfield(Lb.BURSTS_DET.(subjID), cond), continue; end

            for il = 1:numel(Legs)
                leg = Legs{il};
                if ~isfield(Lp.EMG_PREPROC.(subjID).(cond), leg), continue; end
                if ~isfield(Lb.BURSTS_DET.(subjID).(cond), leg), continue; end

                for im = 1:numel(MuscleFields)
                    mf = MuscleFields{im};

                    hasPreproc = isfield(Lp.EMG_PREPROC.(subjID).(cond).(leg), mf) && isfield(Lp.EMG_PREPROC.(subjID).(cond).(leg).(mf), 'signal') && ~isempty(Lp.EMG_PREPROC.(subjID).(cond).(leg).(mf).signal);

                    hasBurst = isfield(Lb.BURSTS_DET.(subjID).(cond).(leg), mf) && isfield(Lb.BURSTS_DET.(subjID).(cond).(leg).(mf), 'bursts_idx');

                    if ~hasPreproc
                        continue;
                    end

                    S = Lp.EMG_PREPROC.(subjID).(cond).(leg).(mf);
                    x = S.signal(:);

                    % Keep original preproc metadata
                    BURST_QC.(subjID).(cond).(leg).(mf).preproc_source = S;

                    if isfield(Lb.BURSTS_DET.(subjID).(cond).(leg).(mf), 'envelope')
                        x_env = Lb.BURSTS_DET.(subjID).(cond).(leg).(mf).envelope(:);
                    else
                        x_env = [];
                    end

                    fs = get_fs_from_entry_or_config(S, C);
                    n = numel(x);
                    dur_sec = n / fs;

                    if hasBurst
                        bursts_idx = Lb.BURSTS_DET.(subjID).(cond).(leg).(mf).bursts_idx;
                        Bsrc = Lb.BURSTS_DET.(subjID).(cond).(leg).(mf);
                        BURST_QC.(subjID).(cond).(leg).(mf).burst_source = Bsrc;
                    else
                        bursts_idx = zeros(0,2);
                        BURST_QC.(subjID).(cond).(leg).(mf).burst_source = struct();
                    end

                    % -------- whole-signal hard QC only --------
                    [sig_status, sig_reasons, Msig] = flag_bad_signal_burst_runner(x, fs, Q);
                    sig_reason = strjoin(sig_reasons, "+");

                    if sig_status == "FAIL"
                        sfc = sfc + 1;
                        signalFailCandidates(sfc,:) = {subjID, cond, leg, mf, fs, x, x_env, sig_reason, Msig};
                    end

                    BURST_QC = ensure_burst_qc_fields(BURST_QC, subjID, cond, leg);

                    BURST_QC.(subjID).(cond).(leg).(mf).signal_status = sig_status;
                    BURST_QC.(subjID).(cond).(leg).(mf).signal_reason = sig_reason;
                    BURST_QC.(subjID).(cond).(leg).(mf).signal_metrics = Msig;
                    BURST_QC.(subjID).(cond).(leg).(mf).n_samples = n;
                    BURST_QC.(subjID).(cond).(leg).(mf).duration_s = dur_sec;
                    BURST_QC.(subjID).(cond).(leg).(mf).fs = fs;

                    % If whole signal is fundamentally bad: reject all bursts
                    if sig_status == "FAIL"
                        nB = size(bursts_idx,1);
                        burst_keep = false(nB,1);
                        burst_reason = repmat("signal_fail", nB, 1);
                        Mb = empty_burst_metrics(nB);

                    else
                        [burst_keep, burst_reason, Mb] = flag_artifacts_by_burst(x, fs, bursts_idx, Q);
                    end

                    % Save burst-level outputs
                    BURST_QC.(subjID).(cond).(leg).(mf).bursts_idx = bursts_idx;
                    BURST_QC.(subjID).(cond).(leg).(mf).burst_keep_mask = burst_keep;
                    BURST_QC.(subjID).(cond).(leg).(mf).bad_bursts_idx = find(~burst_keep);
                    BURST_QC.(subjID).(cond).(leg).(mf).burst_reason = burst_reason;
                    BURST_QC.(subjID).(cond).(leg).(mf).burst_metrics = Mb;

                    % Collect candidate for later random plotting
                    if any(~burst_keep)
                        pc = pc + 1;
                        plotCandidates(pc,:) = {subjID, cond, leg, mf, fs, x, x_env, bursts_idx, burst_keep, burst_reason};
                    end


                    % Build per-signal burst table
                    T = make_burst_qc_table(subjID, cond, leg, mf, fs, bursts_idx, burst_keep, burst_reason, Mb, x_env);

                    BURST_QC.(subjID).(cond).(leg).(mf).bursts_table_qc = T;

                    % Append flat rows
                    for r = 1:height(T)
                        ri = ri + 1;
                        rows(ri,:) = burst_table_row_to_cell(T(r,:));
                    end

                    fprintf('  %s | %s | %s -> %d bursts, kept %d\n', cond, leg, mf, size(bursts_idx,1), sum(burst_keep));
                end
            end
        end
    end

    %% ===================== SAVE =====================
    fprintf('\nSaving burst QC outputs...\n');
    if ~isempty(rows)
        qcT = cell2table(rows, 'VariableNames', burst_qc_headers());
    else
        qcT = cell2table(cell(0,numel(burst_qc_headers())), 'VariableNames', burst_qc_headers());
    end

    fprintf('Saving csv... ');
    outCsv = fullfile(IO.csv_dir, 'QC_bursts_summary.csv');
    writetable(qcT, outCsv);

    fprintf('Saving mat... ');
    outMat = fullfile(IO.out_dir, 'QC_bursts.mat');
    save(outMat, 'BURST_QC', '-v7.3');

    fprintf('\nSaved burst QC table: %s\n', outCsv);
    fprintf('Saved burst QC struct: %s\n', outMat);

    if ~isempty(qcT)
        disp(groupcounts(qcT,"keep_label"));
    end

    if R.inspect_saved_table
        T = readtable(fullfile(IO.csv_dir, IO.output_csv));
        disp(groupcounts(T, 'burst_reason'));
    end

    function plot_specific_rule_based_qc(subject, condition, leg, muscle, C, IO, BURST_QC)
    % Plot one specific signal's rule-based burst QC result.
    %
    % Usage:
    %   C  = config_emg();
    %   IO = C.d_rule_based.io;
    %   plot_specific_rule_based_qc('CTL_79','Plat','right','EMG_TAdist_Concat', C, IO)
    %
    % Optional:
    %   If BURST_QC is already in workspace, pass it as 3rd input after IO.
    %   Otherwise the function will load QC_bursts.mat automatically.

        if nargin < 5 || isempty(C)
            C = config_emg();
        end
        if nargin < 6 || isempty(IO)
            IO = C.d_rule_based.io;
        end

        % ---------- Load BURST_QC if not provided ----------
        if nargin < 7 || isempty(BURST_QC)
            qcMat = fullfile(IO.out_dir, 'QC_bursts.mat');
            if ~isfile(qcMat)
                error('QC_bursts.mat not found: %s', qcMat);
            end
            disp(qcMat)
            disp(IO.out_dir)
            S = load(qcMat, 'BURST_QC');
            if ~isfield(S, 'BURST_QC')
                error('BURST_QC not found in %s', qcMat);
            end
            BURST_QC = S.BURST_QC;
        end

        % ---------- Check entry exists ----------
        if ~isfield(BURST_QC, subject)
            error('Subject not found in BURST_QC: %s', subject);
        end
        if ~isfield(BURST_QC.(subject), condition)
            fprintf('Available conditions for %s: %s\n', subject, strjoin(fieldnames(BURST_QC.(subject)), ", "));
            error('Condition not found for %s: %s', subject, condition);
        end
        if ~isfield(BURST_QC.(subject).(condition), leg)
            error('Leg not found for %s | %s: %s', subject, condition, leg);
        end
        if ~isfield(BURST_QC.(subject).(condition).(leg), muscle)
            error('Muscle not found for %s | %s | %s: %s', subject, condition, leg, muscle);
        end

        E = BURST_QC.(subject).(condition).(leg).(muscle);

        % ---------- Pull saved QC outputs ----------
        if ~isfield(E, 'bursts_idx') || isempty(E.bursts_idx)
            error('No bursts_idx saved for %s | %s | %s | %s.', subject, condition, leg, muscle);
        end
        if ~isfield(E, 'burst_keep_mask') || isempty(E.burst_keep_mask)
            error('No burst_keep_mask saved for %s | %s | %s | %s.', subject, condition, leg, muscle);
        end
        if ~isfield(E, 'burst_reason') || isempty(E.burst_reason)
            error('No burst_reason saved for %s | %s | %s | %s.', subject, condition, leg, muscle);
        end
        if ~isfield(E, 'fs') || isempty(E.fs)
            error('No fs saved for %s | %s | %s | %s.', subject, condition, leg, muscle);
        end

        fs = E.fs;
        bursts_idx   = E.bursts_idx;
        burst_keep   = E.burst_keep_mask;
        burst_reason = E.burst_reason;

        % ---------- Get signal from saved source if possible ----------
        x = [];
        if isfield(E, 'preproc_source') && isstruct(E.preproc_source) && isfield(E.preproc_source, 'signal') && ~isempty(E.preproc_source.signal)
            x = E.preproc_source.signal(:);
        end

        % ---------- Get envelope from saved source if possible ----------
        x_env = [];
        if isfield(E, 'burst_source') && isstruct(E.burst_source) && isfield(E.burst_source, 'envelope') && ~isempty(E.burst_source.envelope)
            x_env = E.burst_source.envelope(:);
        end

        % ---------- Fallback: reload burst file if envelope missing ----------
        if isempty(x_env)
            burstFile = fullfile(IO.bursts_dir, sprintf('%s_EMG_BURSTS.mat', subject));
            if isfile(burstFile)
                Sb = load(burstFile, 'BURSTS_DET');
                if isfield(Sb, 'BURSTS_DET') && isfield(Sb.BURSTS_DET, subject) && isfield(Sb.BURSTS_DET.(subject), condition) && isfield(Sb.BURSTS_DET.(subject).(condition), leg) && isfield(Sb.BURSTS_DET.(subject).(condition).(leg), muscle)

                    Bentry = Sb.BURSTS_DET.(subject).(condition).(leg).(muscle);
                    if isfield(Bentry, 'envelope') && ~isempty(Bentry.envelope)
                        x_env = Bentry.envelope(:);
                    end
                    if isempty(x) && isfield(Bentry, 'signal') && ~isempty(Bentry.signal)
                        x = Bentry.signal(:);
                    end
                end
            end
        end

        % ---------- Last fallback: reload preproc signal if needed ----------
        if isempty(x)
            preprocFile = fullfile(IO.preproc_dir, sprintf('%s_EMG_PREPROC.mat', subject));
            if ~isfile(preprocFile)
                error('Could not recover signal. Missing preproc file: %s', preprocFile);
            end

            Sp = load(preprocFile, 'EMG_PREPROC');
            if ~isfield(Sp, 'EMG_PREPROC') || ~isfield(Sp.EMG_PREPROC, subject) || ~isfield(Sp.EMG_PREPROC.(subject), condition) || ~isfield(Sp.EMG_PREPROC.(subject).(condition), leg) || ~isfield(Sp.EMG_PREPROC.(subject).(condition).(leg), muscle) || ~isfield(Sp.EMG_PREPROC.(subject).(condition).(leg).(muscle), 'signal')
                error('Could not recover signal from preproc file for %s | %s | %s | %s.', subject, condition, leg, muscle);
            end

            x = Sp.EMG_PREPROC.(subject).(condition).(leg).(muscle).signal(:);
        end

        % ---------- Plot ----------
        plot_burst_qc_signal(subject, condition, leg, muscle, fs, x, x_env, bursts_idx, burst_keep, burst_reason, IO.plot_dir, C);

        fprintf('Plotted: %s | %s | %s | %s\n', subject, condition, leg, muscle);
    end


    %% ===================== RANDOM QC PLOTS =====================
    if ~isempty(plotCandidates)
        fprintf('\nGenerating random burst QC plots for signals with at least one rejected burst...\n');
        if isempty(R.random_seed)
            rng('shuffle');
        else
            rng(R.random_seed);
        end
        nAvail = size(plotCandidates, 1);
        nPlot  = min(R.max_plot_signals, nAvail);

        idxPlot = randperm(nAvail, nPlot);

        for i = 1:numel(idxPlot)
            fprintf('  Plotting candidate %d/%d (row %d in plotCandidates)...\n', i, nPlot, idxPlot(i));
            row = idxPlot(i);

            subjID      = plotCandidates{row,1};
            cond        = plotCandidates{row,2};
            leg         = plotCandidates{row,3};
            mf          = plotCandidates{row,4};
            fs          = plotCandidates{row,5};
            x           = plotCandidates{row,6};
            x_env       = plotCandidates{row,7};
            bursts_idx  = plotCandidates{row,8};
            burst_keep  = plotCandidates{row,9};
            burst_reason= plotCandidates{row,10};

            plot_burst_qc_signal(subjID, cond, leg, mf, fs, x, x_env, bursts_idx, burst_keep, burst_reason, IO.plot_dir, C);
        end
    end

    %% ===================== SPECIFIC PLOT EXAMPLE =====================

    subject   = 'CTL_47';
    condition = 'Flat';
    leg       = 'right';
    muscle    = 'EMG_SOL_Concat';

    % Optional single-signal example. The plot helper validates the entry and
    % errors if this participant is not in the processed set, and this sits at
    % the end of the stage, so an absent participant would otherwise throw away
    % a completed run. Warn and carry on instead.
    try
        plot_specific_rule_based_qc(subject, condition, leg, muscle, C, IO, BURST_QC);
    catch ME
        warning('Example QC plot skipped (%s | %s | %s | %s): %s', ...
            subject, condition, leg, muscle, ME.message);
    end

    %% ===================== PLOTS: ALL signal_fail =====================
    if R.plot_signal_fails && ~isempty(signalFailCandidates)
        fprintf('\nGenerating signal fail QC plots for all candidates that failed the whole-signal QC...\n');
        for i = 1:size(signalFailCandidates,1)
            fprintf('\nGenerating signal fail plot for candidate %d/%d...\n', i, size(signalFailCandidates,1));
            subjID     = signalFailCandidates{i,1};
            cond       = signalFailCandidates{i,2};
            leg        = signalFailCandidates{i,3};
            mf         = signalFailCandidates{i,4};
            fs         = signalFailCandidates{i,5};
            x          = signalFailCandidates{i,6};
            x_env      = signalFailCandidates{i,7};
            sig_reason = signalFailCandidates{i,8};
            Msig       = signalFailCandidates{i,9};

            plot_signal_fail_qc(subjID, cond, leg, mf, fs, x, x_env, sig_reason, Msig, IO.signal_fail_plot_dir, C);
        end
    elseif R.plot_signal_fails
        fprintf('\nNo signal fail candidates to plot.\n');
    else
        fprintf('\nPlotting of signal fail candidates is disabled.\n');
    end
end