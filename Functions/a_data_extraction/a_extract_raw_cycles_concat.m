%% a_extract_raw_cycles_concat
% Extract and concatenate raw EMG gait cycles from .c3d files
%
% -------------------------------------------------------------------------
% OVERVIEW
% -------------------------------------------------------------------------
% This script is the FIRST step of the EMG processing pipeline.
%
% It reads raw motion capture files (.c3d), extracts EMG signals,
% detects gait cycles based on gait events (Heel Strike / Toe Off),
% and builds concatenated EMG signals per:
%     - participant
%     - condition
%     - leg
%     - muscle
%
% The goal is to produce a standardized output format that can be used
% by all downstream scripts (preprocessing, burst detection, coherence, etc.)
%
% IMPORTANT:
% The script is designed to be ROBUST and GENERIC:
%     - supports different file naming conventions (via regex)
%     - supports different EMG channel organizations
%     - handles missing data with fallbacks (logged)
%     - always produces the SAME output structure
%
% -------------------------------------------------------------------------
% MAIN PROCESSING STEPS
% -------------------------------------------------------------------------
% 1) FILE DISCOVERY
%    - recursively scans DATA_DIR for .c3d files
%    - identifies participants using filename regex
%
% 2) FILE MATCHING
%    - matches files to (participant × condition × trial)
%    - supports multiple candidates (e.g. _NEW versions)
%    - selection logic controlled via config
%
% 3) EMG CHANNEL MAPPING
%    - maps EMG channels to muscles for each leg
%    - multiple modes available:
%         * association_script (manual mapping per subject)
%         * fixed_names (same mapping for all subjects)
%         * auto detection (keyword-based)
%
% 4) EVENT EXTRACTION (GAIT SEGMENTATION)
%    - extracts Heel Strikes (HS) and Toe Off (TO)
%    - supports multiple naming conventions via config
%    - fallback:
%         * if TO missing → estimated at % of gait cycle (default 60%)
%
% 5) CYCLE EXTRACTION
%    - cuts EMG signal between consecutive HS
%    - stores each cycle as a segment
%
% 6) CONCATENATION
%    - concatenates all valid cycles into one signal per:
%         participant × condition × leg × muscle
%    - stores metadata (cycle boundaries, TO timing, provenance)
%
% 7) LOGGING + QUALITY CONTROL
%    - all issues are logged (missing files, channels, events, etc.)
%    - optional example plots for sanity check
%
% -------------------------------------------------------------------------
% EXPECTED INPUT
% -------------------------------------------------------------------------
% .c3d files containing:
%   - analog EMG signals
%   - gait events (HS / TO) OR enough info to infer them
%
% No strict file naming is required IF regex is correctly configured.
%
% -------------------------------------------------------------------------
% MAIN OUTPUT
% -------------------------------------------------------------------------
% For each participant:
%
%   *_RAW_CYCLES_CONCAT.mat
%
% Structure:
%   CYCLES_SIGNAL_RAW.(subjID).(condition).(leg).(muscle_Concat)
%
% Each signal contains:
%   - signal              : concatenated EMG
%   - n_cycles            : number of cycles used
%   - segments            : individual cycles (cell array)
%   - cycle_starts/ends   : indices in concatenated signal
%   - toe_off_in_cycle    : TO position within each cycle
%   - toe_off_concat      : TO position in concatenated signal
%   - trial_id            : origin trial
%   - orig_start/end      : original indices in raw signal
%
% IMPORTANT:
% → This structure MUST remain unchanged (used by all downstream scripts)
%
% -------------------------------------------------------------------------
% CONFIGURATION (VERY IMPORTANT)
% -------------------------------------------------------------------------
% All parameters are controlled via config_emg()
%
% Key sections to configure:
%
% 1) PATHS
%   C.paths.data_dir              → where .c3d files are
%   C.paths.raw_dir               → where outputs are saved
%
% 2) FILE NAMING
%   C.a_extract_raw.input.filename_regex
%       → must capture:
%           - subjID
%           - cond
%           - ess (trial)
%
%   Example:
%       '^(?<subjID>[^_]+_[^_]+)_(?<cond>Plat|Medium|High)_(?<ess>\d{2})'
%
% 3) PARTICIPANT SELECTION
%   C.a_extract_raw.participant_mode:
%       - 'auto'             → detect from filenames
%       - 'manual_name'      → use provided IDs
%       - 'from_file_dialog' → interactive selection
%
% 4) EMG CHANNEL MAPPING
%   C.a_extract_raw.mapping.mode:
%       - 'association_script'
%       - 'fixed_names'
%       - 'auto'
%
%   → MUST match your dataset organization
%
% 5) EVENT DETECTION
%   C.a_extract_raw.events.hs.left_candidates
%   C.a_extract_raw.events.hs.right_candidates
%   C.a_extract_raw.events.to.left_candidates
%   C.a_extract_raw.events.to.right_candidates
%
%   C.a_extract_raw.events.allow_missing_to = true
%   C.a_extract_raw.events.to_fallback_ratio = 0.6
%
% 6) DATA VALIDATION
%   C.a_extract_raw.missing.min_cycles_per_muscle
%       → minimum number of cycles required to keep a signal
%
% 7) OPTIONAL FEATURES
%   C.a_extract_raw.input.generate_example_figures
%
% -------------------------------------------------------------------------
% IMPORTANT DESIGN PRINCIPLES
% -------------------------------------------------------------------------
% - NEVER crash on missing data → log + skip or fallback
% - ALWAYS produce consistent output format
% - CONFIG > HARD-CODED LOGIC
% - Easy to adapt to new datasets without modifying the script
% -------------------------------------------------------------------------
function a_extract_raw_cycles_concat()

    %% ===================== CONFIGURATION & SÉLECTION ========================
    C = config_emg();  % Load config, everything should be set in config_emg.m (paths, design, parameters)

    PARTICIPANT_MODE = C.a_extract_raw.participant_mode;  % <-- adjust as needed in config_emg.m
    MANUAL_subjID = C.a_extract_raw.manual_subjID;  % <-- used if PARTICIPANT_MODE = 'manual_name'

    PROJECT_DATA_ROOT = C.paths.project_data_root;

    % --- Adapt these subfolders to your real structure ---
    CODE_DIR = C.paths.code_dir;
    DATA_DIR = C.paths.data_dir; % where to look for .c3d files
    OUT_DIR  = C.paths.raw_dir;  % where to save .mat results
    PNG_DIR  = C.a_extract_raw.plot_dir;
    RESULTS_DIR = C.a_extract_raw.results_dir;

    RCP = C.a_extract_raw.files;  % Reusable file paths for results (e.g. CSV summaries)

    % Paramètres expérimentaux
    Essai       = C.design.trials;  % {'01','02','03','04', '05','06','07','08','09','10'};
    muscles     = C.design.muscles; % {'EMG_TAprox','EMG_TAdist','EMG_SOL','EMG_GM','EMG_VL','EMG_RF','EMG_ST','EMG_GMED'};
    Conditions  = C.a_extract_raw.design.conditions;  % {'Plat','Medium','High'};
    jambes      = C.design.legs;        % {'left','right'};
    FreqVicon   = C.general.fs_vicon; % Fréquence d'acquisition vidéo (Hz)

    %% ===================== LOGGING =========================
    log_rows = {};

    log_event = @(severity, event_type, subj, cond, trial, leg, mus, file_name, file_path, reason, details) assignin('caller', 'log_rows', [evalin('caller', 'log_rows'); {string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), string(severity), string(event_type), string(subj), string(cond), string(trial), string(leg), string(mus), string(file_name), string(file_path), string(reason), string(details)}]);

    log_headers = {'timestamp','severity','event_type','participant','condition', 'trial','leg','muscle','file_name','file_path','reason','details'};

    trial_rows = {};
    trial_headers = {'participant','condition','trial','expected_file','actual_file_used', 'file_status','left_hs_count','right_hs_count', 'left_muscles_with_data','right_muscles_with_data','main_issue'};

    %% ===================== PRÉPARATION DU WORKSPACE =========================

    % The project path is set up by startup.m; config_emg() also genpaths
    % Functions/, which covers the helpers and the bundled BTK bridge.

    % Vérification et création des dossiers de sortie
    if ~exist(DATA_DIR, 'dir'), error('DATA_DIR inexistant: %s', DATA_DIR); end
    if ~exist(OUT_DIR, 'dir'), mkdir(OUT_DIR); end
    if ~exist(PNG_DIR, 'dir'), mkdir(PNG_DIR); end
    if ~exist(RESULTS_DIR, 'dir'), mkdir(RESULTS_DIR); end

    % Identification des fichiers disponibles
    allc3d = dir(fullfile(DATA_DIR, '**', '*.c3d'));
    names = {allc3d.name};
    folders = {allc3d.folder};
    % --- Fast filename -> index lookup (much faster than find(strcmp(...)) each time)
    fileMap = containers.Map(names, 1:numel(names));
    % Check that there are no duplicate filenames (keys in the map must be unique)
    if numel(unique(names)) < numel(names)
        % log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
        %     'ERROR','DUPLICATE_FILENAMES', '', '', '', '', '', ...
        %     '', '', 'Duplicate filenames detected in DATA_DIR', ''};
        error('Duplicate filenames detected in DATA_DIR. Please ensure all .c3d files have unique names. This is required for correct file mapping.');
    end

    if isempty(allc3d)
        error('Aucun fichier .c3d trouvé.');
    else
        fprintf('Fichiers .c3d trouvés: %d\n', numel(allc3d));
    end

    % Pattern de nommage : subjID_Condition_Essai.c3d
    % Accepts also _NEW suffix (e.g. for reprocessed files) and captures subjID, condition, essai
    subjID_re = C.a_extract_raw.input.filename_regex;

    %% ===================== SÉLECTION DES PARTICIPANTS =======================

    switch lower(PARTICIPANT_MODE)
        case 'auto'
            subjID_set = {};
            for k = 1:numel(allc3d)
                this_name = allc3d(k).name;
                this_path = fullfile(allc3d(k).folder, allc3d(k).name);
                tok = regexp(this_name, subjID_re, 'names');

                if ~isempty(tok) && isfield(tok, 'subjID')
                    subjID_set{end+1} = tok.subjID;
                else
                    if ~C.a_extract_raw.input.ignore_unmatched_files
                        error('Filename does not match expected pattern: %s', this_name);
                    end

                    log_rows = append_log(log_rows, 'WARN','FILENAME_PATTERN_MISMATCH','','','','','', this_name, this_path, 'Filename does not match expected pattern', subjID_re);
                end
            end
            Participants = unique(subjID_set);
        case 'manual_name'
            Participants = MANUAL_subjID;
        case 'from_file_dialog'
            [f, p] = uigetfile(fullfile(DATA_DIR, '*.c3d'), 'Sélectionner un fichier');

            if isequal(f,0) || isequal(p,0)
                log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'WARN','FILE_DIALOG_CANCELLED','','','','','', '','', 'User cancelled file selection dialog',''};
                warning('Sélection de fichier annulée par l utilisateur.');
                Participants = {};
            else
                selected_path = fullfile(p, f);
                tok = regexp(f, subjID_re, 'names');

                if isempty(tok)
                    log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'ERROR','FILENAME_PATTERN_MISMATCH','','','','','', f, selected_path, 'Selected file does not match expected naming pattern', sprintf('Regex used: %s', subjID_re)};
                    warning('Le fichier sélectionné ne respecte pas le pattern attendu : %s', f);
                    Participants = {};
                else
                    Participants = {tok.subjID};
                end
            end
    end

    fprintf('Participants à traiter (%d): %s\n', numel(Participants), strjoin(Participants, ', '));
    % Count files whose name starts with "<Participant>_"
    n_to_process = sum(startsWith(names, strcat(string(Participants), "_")));
    fprintf('Nombre de fichiers .c3d à traiter pour ces participants: %d\n', n_to_process)

    %% ===================== BOUCLE DE TRAITEMENT PRINCIPALE ==================
    example_fig_done = false;
    EXAMPLE_DIR = fullfile(PNG_DIR, 'Examples');
    if ~exist(EXAMPLE_DIR, 'dir')
        mkdir(EXAMPLE_DIR);
    end

    for iP = 1:numel(Participants)
        participant_output_count = 0;

        subjID = Participants{iP};
        fprintf('\n=== Traitement : %s ===\n', subjID);
        %fprintf('Example expected file: %s\n', fullfile(DATA_DIR, sprintf('%s_%s_%s.c3d', subjID, Conditions{1}, Essai{1})));
        % fprintf('Example expected file (name): %s\n', sprintf('%s_%s_%s.c3d', subjID, Conditions{1}, Essai{1}));

        % --- Avoid printing the same missing file message many times (muscles x legs)
        missing_cache = containers.Map('KeyType','char','ValueType','logical');

        % Chargement du mapping spécifique au participant (via Association.m)
        Participant = {subjID};
        clear sensor_association_left sensor_association_right

        % Structure de données finale pour le participant
        CYCLES_SIGNAL_RAW = struct();
        CYCLES_SIGNAL_RAW.(subjID) = struct();

        RAW_MARKERS = struct();
        RAW_MARKERS.(subjID) = struct();

        for iC = 1:numel(Conditions)
            condition_output_count = 0;

            % Name used in raw .c3d filenames
            cond_file = Conditions{iC};   % e.g. 'Plat'

            % Name used in outputs / structures / tables
            cond_out = cond_file;
            if strcmp(cond_file, 'Plat')
                cond_out = 'Flat';
            end

            % --- Accumulators: store segments as cells (much faster than repeated concat) ---
            acc = struct();  % acc.(leg).(mus).segs (cell), acc.(leg).(mus).n (count)
            for j = 1:numel(jambes)
                leg = jambes{j};
                acc.(leg) = struct();
            end

            % --- Loop trials ONCE, load C3D once, then extract all legs/muscles from it ---
            for iE = 1:numel(Essai)
                trial_id = Essai{iE};
                expected_file = sprintf('%s_%s_%s.c3d', subjID, cond_file, trial_id);

                actual_file_used = "";
                file_status = "";
                left_hs_count = NaN;
                right_hs_count = NaN;
                left_muscles_with_data = 0;
                right_muscles_with_data = 0;
                main_issue = "";

                % Find all files matching this subject + condition + trial
                matching_idx = [];

                for k = 1:numel(names)
                    tok = regexp(names{k}, subjID_re, 'names');

                    if isempty(tok), continue; end

                    if strcmp(tok.subjID, subjID) && strcmp(tok.cond, cond_file) && strcmp(tok.ess, trial_id)

                        matching_idx(end+1) = k;
                    end
                end

                if isempty(matching_idx)
                    file_status = "MISSING";
                    main_issue = "Missing file";

                    trial_rows = append_trial_recap(trial_rows, subjID, cond_out, trial_id, expected_file, "", file_status, left_hs_count, right_hs_count, left_muscles_with_data, right_muscles_with_data, main_issue);

                    continue;
                end

                % If multiple matches → prefer non-_NEW if config says so
                selected_idx = matching_idx(1);

                if numel(matching_idx) > 1 && C.a_extract_raw.input.prefer_standard_over_new
                    for ii = matching_idx
                        if ~contains(names{ii}, '_NEW')
                            selected_idx = ii;
                            break;
                        end
                    end
                elseif numel(matching_idx) > 1 && ~C.a_extract_raw.input.prefer_standard_over_new
                    for ii = matching_idx
                        if contains(names{ii}, '_NEW')
                            selected_idx = ii;
                            break;
                        end
                    end
                end

                c3dname = names{selected_idx};
                actual_file_used = c3dname;
                fullpth = fullfile(folders{selected_idx}, c3dname);

                file_status = "FOUND";

                try
                    % Read file ONCE
                    acq     = btkReadAcquisition(fullpth);
                    analogs = btkGetAnalogs(acq);
                    [RAW_MARKERS, log_rows] = extract_raw_markers_lr( acq, C, RAW_MARKERS, subjID, cond_out, trial_id, c3dname, fullpth, log_rows);
                    [sensor_map, log_rows] = resolve_emg_channel_mapping(analogs, C, subjID, cond_file, Essai{iE}, log_rows);
                    if isempty(fieldnames(sensor_map.left)) && isempty(fieldnames(sensor_map.right))
                        error('Mapping failed completely for %s %s %s', subjID, cond_file, Essai{iE});
                    elseif isempty(fieldnames(sensor_map.left))
                        warning('No LEFT channels mapped for %s %s %s', subjID, cond_file, Essai{iE});
                    elseif isempty(fieldnames(sensor_map.right))
                        warning('No RIGHT channels mapped for %s %s %s', subjID, cond_file, Essai{iE});
                    else
                        fprintf('EMG channel mapping resolved for %s %s %s\n', subjID, cond_file, Essai{iE});
                    end
                    FreqS   = btkGetAnalogFrequency(acq);
                    fprintf('Processing file: %s (FreqS: %.2f Hz)\n', c3dname, FreqS);

                    missing_muscles = struct();  % track missing muscles for logging at the end of the trial

                    % Load participant-specific mapping ONCE (already loaded above)
                    for j = 1:numel(jambes)
                        leg = jambes{j};

                        if strcmpi(leg,'left')
                            sensor_association = sensor_map.left;
                        else
                            sensor_association = sensor_map.right;
                        end

                        % ---- Choose a reference EMG channel to compute HS ONCE per leg per trial ----
                        ref_sensor_name = '';
                        for mm = 1:numel(muscles)
                            mus_try = muscles{mm};
                            if isfield(sensor_association, mus_try)
                                cand = sensor_association.(mus_try);
                                if isfield(analogs, cand)
                                    ref_sensor_name = cand;
                                    break;
                                end
                            end
                        end

                        if isempty(ref_sensor_name)
                            if strlength(main_issue) == 0
                                main_issue = sprintf('%s ref channel missing', leg);
                            end
                            log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'ERROR','REF_CHANNEL_NOT_FOUND',subjID,cond_out,Essai{iE},leg,'', c3dname,fullpth,'No mapped EMG reference channel found for this leg',''};
                            continue;
                        end

                        EMG_ref = analogs.(ref_sensor_name);

                        % ===================== EVENT EXTRACTION (HS / TO) =====================
                        try
                            if strcmpi(leg,'left')
                                HS = get_event_indices(acq, FreqS, FreqVicon, EMG_ref, C.a_extract_raw.events.hs.left_candidates);
                                TO = get_event_indices(acq, FreqS, FreqVicon, EMG_ref, C.a_extract_raw.events.to.left_candidates);
                            else
                                HS = get_event_indices(acq, FreqS, FreqVicon, EMG_ref, C.a_extract_raw.events.hs.right_candidates);
                                TO = get_event_indices(acq, FreqS, FreqVicon, EMG_ref, C.a_extract_raw.events.to.right_candidates);
                            end

                        catch ME
                            % --- Inspect available event fields ---
                            event_fields_str = '';
                            try
                                events_tmp = btkGetEvents(acq);
                                ev_names = fieldnames(events_tmp);
                                if ~isempty(ev_names)
                                    event_fields_str = strjoin(ev_names, ' | ');
                                else
                                    event_fields_str = 'No event fields found';
                                end
                            catch
                                event_fields_str = 'Could not read event fields';
                            end

                            if strlength(main_issue) == 0
                                main_issue = sprintf('%s event extraction error', leg);
                            end

                            log_rows = append_log(log_rows, 'ERROR','EVENT_EXTRACTION_ERROR',subjID,cond_out,Essai{iE},leg,'', c3dname,fullpth,ME.identifier, sprintf('%s | Available events: %s', ME.message, event_fields_str));

                            continue;
                        end

                        % ===================== HS VALIDATION =====================
                        if isempty(HS)
                            log_rows = append_log(log_rows, 'ERROR','HS_EVENT_MISSING',subjID,cond_out,Essai{iE},leg,'', c3dname,fullpth,'No HS event found → cannot build cycles','');

                            continue;
                        end

                        if strcmpi(leg,'left')
                            left_hs_count = numel(HS);
                        else
                            right_hs_count = numel(HS);
                        end

                        % ===================== TO VALIDATION =====================
                        if isempty(TO)
                            if ~C.a_extract_raw.events.allow_missing_to
                                if strlength(main_issue) == 0
                                    main_issue = sprintf('%s TO missing', leg);
                                end

                                log_rows = append_log(log_rows, 'ERROR','TO_EVENT_MISSING',subjID,cond_out,Essai{iE},leg,'', c3dname,fullpth,'No TO event found','');

                                TO = NaN(size(HS));  % keep pipeline running but no TO info
                            else
                                log_rows = append_log(log_rows, 'WARN','TO_EVENT_MISSING',subjID,cond_out,Essai{iE},leg,'', c3dname,fullpth,'No TO event found → using 60% gait cycle fallback','');

                                % --- Create synthetic TO from HS ---
                                TO = NaN(size(HS));

                                for kk = 1:(numel(HS)-1)
                                    cycle_start = HS(kk);
                                    cycle_end   = HS(kk+1);

                                    cycle_length = cycle_end - cycle_start;

                                    % 60% of gait cycle
                                    ratio = C.a_extract_raw.events.to_fallback_ratio;
                                    TO(kk) = round(cycle_start + ratio * cycle_length);
                                end

                                % Last cycle → undefined
                                TO(end) = NaN;
                            end
                        end

                        % ===================== HS MINIMUM CHECK =====================
                        if numel(HS) < 2
                            if strlength(main_issue) == 0
                                main_issue = sprintf('%s HS<2', leg);
                            end

                            log_rows = append_log(log_rows, 'WARN','HS_TOO_FEW',subjID,cond_out,Essai{iE},leg,'', c3dname,fullpth,'Less than 2 heel strikes detected', sprintf('HS count = %d', numel(HS)));

                            continue;
                        end

                        if ~example_fig_done && C.a_extract_raw.output.generate_example_figures
                            % Choose one representative muscle available for this leg
                            example_mus = '';
                            for mm = 1:numel(muscles)
                                mus_try = muscles{mm};
                                if isfield(sensor_association, mus_try)
                                    cand = sensor_association.(mus_try);
                                    if isfield(analogs, cand)
                                        example_mus = mus_try;
                                        break;
                                    end
                                end
                            end

                            if ~isempty(example_mus)
                                sensor_name_ex = sensor_association.(example_mus);
                                EMG_example = analogs.(sensor_name_ex);

                                % Build extracted cycle segments for illustration only
                                ex_segs = {};
                                for kk = 1:(numel(HS)-1)
                                    ex_start = max(1, floor(HS(kk)));
                                    ex_end   = min(numel(EMG_example), ceil(HS(kk+1)));
                                    if ex_end > ex_start
                                        ex_segs{end+1,1} = EMG_example(ex_start:ex_end); %#ok<AGROW>
                                    end
                                end

                                if ~isempty(ex_segs)
                                    ex_concat = vertcat(ex_segs{:});
                                    ex_lengths = cellfun(@numel, ex_segs);
                                    ex_cycle_starts = [1; cumsum(ex_lengths(1:end-1)) + 1];

                                    fig = figure('Visible','off','Color','w','Position',[100 100 1100 700]);

                                    % --- Top panel: raw trial with heel strikes
                                    subplot(2,1,1);
                                    plot(EMG_example, 'k', 'LineWidth', 0.7); hold on;
                                    for kk = 1:numel(HS)
                                        xline(HS(kk), '--', 'Color', [0.85 0.2 0.2], 'LineWidth', 1);
                                    end
                                    for kk = 1:numel(TO)
                                        xline(TO(kk), '--b');
                                    end
                                    hold off;
                                    title(sprintf('Raw EMG trial with heel strikes | %s | %s | %s | %s | trial %s', subjID, cond_out, leg, example_mus, Essai{iE}), 'Interpreter', 'none');
                                    xlabel('Samples');
                                    ylabel('Amplitude');

                                    % --- Bottom panel: concatenated extracted cycles
                                    subplot(2,1,2);
                                    plot(ex_concat, 'k', 'LineWidth', 0.7); hold on;
                                    for kk = 1:numel(ex_cycle_starts)
                                        xline(ex_cycle_starts(kk), '--', 'Color', [0.65 0.65 0.65], 'LineWidth', 0.8);
                                    end
                                    hold off;
                                    title('Concatenated extracted gait cycles', 'Interpreter', 'none');
                                    xlabel('Samples');
                                    ylabel('Amplitude');

                                    fprintf('Saving example figure for %s %s %s %s trial %s\n', subjID, cond_out, leg, example_mus, Essai{iE});
                                    saveas(fig, fullfile(EXAMPLE_DIR, sprintf('example_cycle_extraction_%s_%s_%s_%s_%s.png', subjID, cond_out, leg, example_mus, Essai{iE})));
                                    fprintf('Example figure saved: %s\n', fullfile(EXAMPLE_DIR, sprintf('example_cycle_extraction_%s_%s_%s_%s_%s.png', subjID, cond_out, leg, example_mus, Essai{iE})));
                                    close(fig);

                                    example_fig_done = true;
                                end
                            end
                        end


                        % ---- Extract ALL muscles using the SAME HS ----
                        for m = 1:numel(muscles)
                            muscle_got_data_this_trial = false;
                            mus = muscles{m};

                            if ~isfield(sensor_association, mus)
                                if ~isfield(missing_muscles, leg)
                                    missing_muscles.(leg) = {};
                                end

                                missing_muscles.(leg){end+1} = mus;

                                log_rows = append_log(log_rows, 'WARN','MUSCLE_NOT_FOUND',subjID,cond_out,Essai{iE},leg,mus, c3dname,fullpth,'Muscle missing from mapping','');

                                continue;
                            end

                            sensor_name = sensor_association.(mus);
                            if ~isfield(analogs, sensor_name)
                                log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'WARN','MAPPED_CHANNEL_NOT_FOUND',subjID,cond_out,Essai{iE},leg,mus, c3dname,fullpth,'Mapped analog channel absent in file',sensor_name};
                                continue;
                            end

                            EMG_signal = analogs.(sensor_name);

                            % Init accumulator for this muscle if needed
                            if ~isfield(acc.(leg), mus)
                                acc.(leg).(mus).segs = {};
                                acc.(leg).(mus).n    = 0;
                                acc.(leg).(mus).trial_id = {};
                                acc.(leg).(mus).orig_start = [];
                                acc.(leg).(mus).orig_end = [];
                                acc.(leg).(mus).toe_off_in_cycle = [];
                                acc.(leg).(mus).toe_off_concat = [];
                            end

                            % Cut cycles & store segments as cells (fast)
                            for k = 1:(numel(HS)-1)
                                i_start = max(1, floor(HS(k)));
                                i_end   = min(numel(EMG_signal), ceil(HS(k+1)));

                                if i_end > i_start
                                    muscle_got_data_this_trial = true;

                                    % Save signal segment
                                    acc.(leg).(mus).segs{end+1,1} = EMG_signal(i_start:i_end);
                                    acc.(leg).(mus).n = acc.(leg).(mus).n + 1;

                                    % Save provenance
                                    acc.(leg).(mus).trial_id{end+1,1} = Essai{iE};
                                    acc.(leg).(mus).orig_start(end+1,1) = i_start;
                                    acc.(leg).(mus).orig_end(end+1,1) = i_end;

                                    % Find Toe Off that belongs to this gait cycle
                                    TO = TO(~isnan(TO));
                                    to_idx = TO(TO > i_start & TO < i_end);

                                    if isempty(to_idx)
                                        acc.(leg).(mus).toe_off_in_cycle(end+1,1) = NaN;
                                        acc.(leg).(mus).toe_off_concat(end+1,1) = NaN;
                                    else
                                        % If multiple TO events fall in the interval, keep the first one
                                        to_abs = to_idx(1);

                                        % Position inside the cycle
                                        to_rel = to_abs - i_start + 1;
                                        acc.(leg).(mus).toe_off_in_cycle(end+1,1) = to_rel;

                                        % Placeholder for now; true concat position computed later
                                        acc.(leg).(mus).toe_off_concat(end+1,1) = NaN;
                                    end

                                else
                                    log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'WARN','INVALID_CYCLE_BOUNDS',subjID,cond_out,Essai{iE},leg,mus, c3dname,fullpth,'Cycle bounds invalid',sprintf('start=%d end=%d', i_start, i_end)};
                                end
                            end

                            if muscle_got_data_this_trial
                                if strcmpi(leg,'left')
                                    left_muscles_with_data = left_muscles_with_data + 1;
                                else
                                    right_muscles_with_data = right_muscles_with_data + 1;
                                end
                            end
                        end % muscles
                    end % legs

                catch ME
                    % Say exactly where this came from. This block used to
                    % swallow programming errors as "file read error", which
                    % silently dropped every trial.
                    fprintf(2, ['\n[%s] FAILED while processing %s\n' ...
                                '      %s (%s)\n'], ...
                        mfilename, c3dname, ME.message, ME.identifier);
                    if ~isempty(ME.stack)
                        fprintf(2, '      at %s line %d\n', ...
                            ME.stack(1).name, ME.stack(1).line);
                    end
                    if strlength(main_issue) == 0
                        main_issue = "File read error";
                    end
                    if contains(ME.message, 'Left_Foot_Strike') || contains(ME.message, 'Right_Foot_Strike')
                        log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'ERROR','HS_EVENT_MISSING',subjID,cond_out,Essai{iE},'', '', c3dname,fullpth,ME.identifier,ME.message};
                    else
                        log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'ERROR','FILE_READ_ERROR',subjID,cond_out,Essai{iE},'', '', c3dname,fullpth,ME.identifier,ME.message};
                    end
                end
                if strlength(main_issue) == 0
                    main_issue = "OK";
                end

                if strlength(file_status) == 0
                    file_status = "UNKNOWN";
                end

                trial_rows = append_trial_recap(trial_rows, subjID, cond_out, trial_id, expected_file, actual_file_used, file_status, left_hs_count, right_hs_count, left_muscles_with_data, right_muscles_with_data, main_issue);
            end % trials

            % --- After all trials: build the final concatenated signals, save + QC plots ---
            for j = 1:numel(jambes)
                leg = jambes{j};
                leg_output_count = 0;

                % Ensure struct fields exist
                if ~isfield(CYCLES_SIGNAL_RAW.(subjID), cond_out)
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out) = struct();
                end
                if ~isfield(CYCLES_SIGNAL_RAW.(subjID).(cond_out), leg)
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg) = struct();
                end

                for m = 1:numel(muscles)
                    mus = muscles{m};

                    if ~isfield(acc.(leg), mus)
                        log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'WARN','NO_DATA_FOR_MUSCLE',subjID,cond_out,'',leg,mus, '','', 'No data accumulated for this muscle in this condition/leg',''};
                        continue;
                    end

                    n_cycles_total = acc.(leg).(mus).n;

                    if n_cycles_total < C.a_extract_raw.missing.min_cycles_per_muscle

                        log_rows = append_log(log_rows, 'WARN','TOO_FEW_CYCLES_MUSCLE',subjID,cond_out,'',leg,mus, '','', sprintf('Too few cycles: %d < %d', n_cycles_total, C.a_extract_raw.missing.min_cycles_per_muscle),'');

                        continue;
                    end
                    concat_sig = vertcat(acc.(leg).(mus).segs{:});

                    catField = [mus '_Concat'];
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).signal   = concat_sig;
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).n_cycles = n_cycles_total;

                    seg_lengths = cellfun(@numel, acc.(leg).(mus).segs(:));
                    cycle_ends = cumsum(seg_lengths);
                    cycle_starts = [1; cycle_ends(1:end-1) + 1];

                    toe_off_in_cycle = acc.(leg).(mus).toe_off_in_cycle;
                    toe_off_concat = NaN(size(toe_off_in_cycle));

                    valid_to = ~isnan(toe_off_in_cycle);
                    toe_off_concat(valid_to) = cycle_starts(valid_to) + toe_off_in_cycle(valid_to) - 1;

                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).segments      = acc.(leg).(mus).segs;
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).cycle_lengths = seg_lengths;
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).cycle_starts  = cycle_starts;
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).cycle_ends    = cycle_ends;
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).toe_off_concat= toe_off_concat;
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).toe_off_in_cycle = toe_off_in_cycle;
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).trial_id   = acc.(leg).(mus).trial_id;
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).orig_start = acc.(leg).(mus).orig_start;
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).orig_end   = acc.(leg).(mus).orig_end;
                    CYCLES_SIGNAL_RAW.(subjID).(cond_out).(leg).(catField).fs = FreqS;

                    leg_output_count = leg_output_count + 1;
                    condition_output_count = condition_output_count + 1;
                    participant_output_count = participant_output_count + 1;

                    %log_rows = save_concat_qc_plot(log_rows, concat_sig, acc.(leg).(mus).segs, subjID, cond, leg, mus, PNG_DIR);

                    if isfield(missing_muscles, leg) && ~isempty(missing_muscles.(leg))
                        log_rows = append_log(log_rows, 'INFO','MISSING_MUSCLE_SUMMARY',subjID,cond_out,'',leg,'', '', '', 'Missing muscles in this trial', strjoin(missing_muscles.(leg), ','));
                    end

                end % muscles

                if leg_output_count == 0
                    log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'ERROR','LEG_EMPTY_OUTPUT',subjID,cond_out,'',leg,'', '','', 'No valid concatenated output saved for this leg in this condition',''};
                end

            end % legs

            if condition_output_count == 0
                log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'ERROR','CONDITION_EMPTY_OUTPUT',subjID,cond_out,'','','', '','', 'No valid concatenated output saved for this condition',''};
            end

        end % conditions

        if participant_output_count == 0
            log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'ERROR','PARTICIPANT_EMPTY_OUTPUT',subjID,'','','','', '','', 'No valid concatenated output saved for this participant',''};
        end

        % Sauvegarde physique du fichier .mat pour le participant
        try
            save_file = fullfile(OUT_DIR, sprintf('%s_RAW_CYCLES_CONCAT.mat', subjID));
            save(save_file, 'CYCLES_SIGNAL_RAW', 'RAW_MARKERS', '-v7.3');
            fprintf('Fichier sauvegardé: %s\n', save_file);
            log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'INFO','FILE_SAVED',subjID,'', '', '', '', sprintf('%s_RAW_CYCLES_CONCAT.mat', subjID), save_file, 'File saved successfully',''};
        catch ME
            log_rows(end+1,:) = {char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), 'ERROR','FILE_SAVE_ERROR',subjID,'', '', '', '', sprintf('%s_RAW_CYCLES_CONCAT.mat', subjID), '', ME.identifier, ME.message};
            warning('Erreur lors de la sauvegarde pour %s : %s', subjID, ME.message);
        end
    end

    fprintf('\n=== END OF EXTRACTION ===\n');

    %% ===================== RECAPS =====================
    if C.a_extract_raw.save_recaps
        %---------------------- RECAP RAW SIGNALS ----------------------

        RAW = build_raw_signal_recap(Participants, OUT_DIR, RESULTS_DIR, RCP, C);
        MARKER_RECAP = build_marker_recap(Participants, OUT_DIR, RESULTS_DIR);
        RAW_SIGNAL_SUMMARY = RAW.RAW_SIGNAL_SUMMARY;
        if isempty(RAW_SIGNAL_SUMMARY) || height(RAW_SIGNAL_SUMMARY) == 0
            warning('RAW_SIGNAL_SUMMARY is empty. Check whether .mat files were saved correctly in OUT_DIR: %s', OUT_DIR);
        end

        RAW_SIGNAL_SUMMARY = RAW.RAW_SIGNAL_SUMMARY;
        RAW_PARTICIPANT_SUMMARY = RAW.RAW_PARTICIPANT_SUMMARY;

        %---------------------- COHERENCE-READY RECAP ----------------------

        COH = build_coherence_ready_recap(RAW_SIGNAL_SUMMARY, C);

        COHERENCE_SUMMARY = COH.COHERENCE_SUMMARY;
        COHERENCE_READY = COH.COHERENCE_READY;

        COH_THEORETICAL_BY_PAIR = COH.COH_THEORETICAL_BY_PAIR;

        COH_RECAP_BY_PAIR = COH.COH_RECAP_BY_PAIR;
        COH_RECAP_BY_PAIR_CONDITION = COH.COH_RECAP_BY_PAIR_CONDITION;
        COH_RECAP_BY_PAIR_AGE = COH.COH_RECAP_BY_PAIR_AGE;
        COH_RECAP_BY_PAIR_AGE_CONDITION = COH.COH_RECAP_BY_PAIR_AGE_CONDITION;

        COH_PARTICIPANT_SUMMARY = COH.COH_PARTICIPANT_SUMMARY;
        COH_RECAP_PARTICIPANTS_BY_AGE = COH.COH_RECAP_PARTICIPANTS_BY_AGE;
        COH_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = COH.COH_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE;

        %---------------------- SAVE AND DISPLAY RECAPS ----------------------

        RECAP = save_and_display_recaps( log_rows, trial_rows, trial_headers, OUT_DIR, RESULTS_DIR, COHERENCE_READY, COHERENCE_SUMMARY, COH_THEORETICAL_BY_PAIR, COH_RECAP_BY_PAIR, COH_RECAP_BY_PAIR_CONDITION, COH_RECAP_BY_PAIR_AGE, COH_RECAP_BY_PAIR_AGE_CONDITION, COH_PARTICIPANT_SUMMARY, COH_RECAP_PARTICIPANTS_BY_AGE, COH_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE);

        LOG = RECAP.LOG;
        LOG_ISSUES = RECAP.LOG_ISSUES;
        TRIAL_RECAP = RECAP.TRIAL_RECAP;
        mat_files = RECAP.MAT_FILES;

        %---------------------- INSPECTING MAT FILES STRUCTURE ----------------------

        % Find one random mat file to inspect its structure
        if ~isempty(mat_files)
            sample_file = fullfile(mat_files(1).folder, mat_files(1).name);
            fprintf('\n--- Inspecting a generated .mat file ---\n');
            fprintf('File inspected: %s\n', sample_file);
            sample_data = load(sample_file);
            disp_tree(sample_data,3);
        else
            fprintf('No .mat files to inspect.\n');
        end
    end

    conds_saved = fieldnames(CYCLES_SIGNAL_RAW.(subjID));

    if any(strcmp(conds_saved, 'Plat'))
        warning('Condition Plat still exists in output structure for %s.', subjID);
    end

    if any(strcmp(conds_saved, 'Flat'))
        fprintf('OK: Flat found in output structure for %s.\n', subjID);
    end
end