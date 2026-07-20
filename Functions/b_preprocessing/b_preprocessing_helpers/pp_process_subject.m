function [EMG_PREPROC, plotCandidates, pc] = pp_process_subject( ...
    CYCLES_SIGNAL_RAW, subjID, EMG_PREPROC, P, PNG_DIR, plotCandidates, pc)

conds = fieldnames(CYCLES_SIGNAL_RAW.(subjID));
for ic = 1:numel(conds)
    cond = conds{ic};
    if strcmp(cond,'meta'), continue; end
    if ~isstruct(CYCLES_SIGNAL_RAW.(subjID).(cond)), continue; end

    legs = fieldnames(CYCLES_SIGNAL_RAW.(subjID).(cond));
    for il = 1:numel(legs)
        leg = legs{il};
        if ~isstruct(CYCLES_SIGNAL_RAW.(subjID).(cond).(leg)), continue; end

        musFields = fieldnames(CYCLES_SIGNAL_RAW.(subjID).(cond).(leg));
        for im = 1:numel(musFields)
            mf = musFields{im};
            if ~endsWith(mf,'_Concat'), continue; end

            raw = CYCLES_SIGNAL_RAW.(subjID).(cond).(leg).(mf);

            if ~isfield(raw,'signal') || isempty(raw.signal)
                fprintf("WARNING: Missing or empty raw.signal for %s - %s - %s - %s\n", subjID, cond, leg, mf);
                % log + skip
                p = p + 1;
                PROBLEMS(p,:) = {subjID, cond, leg, mf, "WARN", "Missing or empty raw.signal"};
                nSignalsSkipped = nSignalsSkipped + 1;
                continue;

            end
            if ~isfield(raw,'signal') || isempty(raw.signal), continue; end

            fs = pp_get_fs(P);
            [x, y_filt, y] = pp_preprocess_signal(raw.signal(:), fs, P);

            % continuous time-domain signals from full concatenated EMG
            td = pp_build_time_domain_branch(y_filt, fs, P);

            % store for random QC plots
            if P.plot_random_examples
                pc = pc + 1;
                plotCandidates(pc,:) = {subjID, cond, leg, mf, fs, x, y_filt, y};
            end

            % ensure struct fields exist
            if ~isfield(EMG_PREPROC.(subjID), cond), EMG_PREPROC.(subjID).(cond) = struct(); end
            if ~isfield(EMG_PREPROC.(subjID).(cond), leg), EMG_PREPROC.(subjID).(cond).(leg) = struct(); end

            % copy all raw metadata fields and overwrite signal
            EMG_PREPROC.(subjID).(cond).(leg).(mf) = raw;
            EMG_PREPROC.(subjID).(cond).(leg).(mf).signal_raw = raw.signal;
            EMG_PREPROC.(subjID).(cond).(leg).(mf).signal     = y;

            % useful continuous signals
            EMG_PREPROC.(subjID).(cond).(leg).(mf).signal_bandpassed = y_filt;

            % dedicated branch for time-domain analysis
            EMG_PREPROC.(subjID).(cond).(leg).(mf).time_domain = td;

            % save full-length preproc plot (same naming as raw)
            if isfield(P,'save_preproc_png') && P.save_preproc_png
                pp_save_preproc_concat_plot(PNG_DIR, subjID, cond, leg, mf, y);
            end
            if pc == 0
                warning('No valid EMG signals processed for subject %s', subjID);
            end
        end
    end
end
end

function td = pp_build_time_domain_branch(y_filt, fs, P)
% Build continuous time-domain signals from full concatenated EMG

td = struct();

x_bp = y_filt(:);

if isfield(P, 'time_domain') && isfield(P.time_domain, 'save_bandpassed') && P.time_domain.save_bandpassed
    td.bandpassed = x_bp;
else
    td.bandpassed = [];
end

x_rect = abs(x_bp);
if isfield(P, 'time_domain') && isfield(P.time_domain, 'save_rectified') && P.time_domain.save_rectified
    td.rectified = x_rect;
else
    td.rectified = [];
end

x_env = [];
if isfield(P, 'time_domain') && isfield(P.time_domain, 'envelope') ...
        && isfield(P.time_domain.envelope, 'enable') && P.time_domain.envelope.enable
    x_env = pp_compute_envelope(x_rect, fs, P.time_domain.envelope);

    if isfield(P.time_domain, 'clip_negative_envelope') && P.time_domain.clip_negative_envelope
        x_env(x_env < 0) = 0;
    end
end

if isfield(P, 'time_domain') && isfield(P.time_domain, 'save_envelope') && P.time_domain.save_envelope
    td.envelope = x_env;
else
    td.envelope = [];
end

td.fs = fs;
end

function x_env = pp_compute_envelope(x_rect, fs, Penv)
% Low-pass filtered rectified EMG envelope

d_env = designfilt('lowpassiir', ...
    'FilterOrder', Penv.lowpass_order, ...
    'HalfPowerFrequency', Penv.lowpass_hz, ...
    'SampleRate', fs);

x_env = filtfilt(d_env, x_rect(:));
end