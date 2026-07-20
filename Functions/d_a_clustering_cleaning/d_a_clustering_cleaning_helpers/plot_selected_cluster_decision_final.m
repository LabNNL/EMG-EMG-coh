function plot_selected_cluster_decision_final(subject, condition, leg, muscle, ...
    burstsDir, clusterDir, clusterResultsMat, outDir)

    C = config_emg();

    % ---------- Load BURST_FEATURES_CLUSTERED if not already in workspace ----------
    if evalin('base', 'exist(''BURST_FEATURES_CLUSTERED'', ''var'')')
        T = evalin('base', 'BURST_FEATURES_CLUSTERED');
        fprintf('Using BURST_FEATURES_CLUSTERED from workspace.\n');
    else
        clusterPath = fullfile(clusterDir, clusterResultsMat);
        if ~isfile(clusterPath)
            error('Cluster results file not found: %s', clusterPath);
        end

        S = load(clusterPath, 'BURST_FEATURES_CLUSTERED');
        if ~isfield(S, 'BURST_FEATURES_CLUSTERED')
            error('The file %s does not contain BURST_FEATURES_CLUSTERED.', clusterPath);
        end
        T = S.BURST_FEATURES_CLUSTERED;
        fprintf('Loaded BURST_FEATURES_CLUSTERED from:\n%s\n', clusterPath);
    end

    % ---------- Basic checks ----------
    assert(ismember('cluster_valid', T.Properties.VariableNames), ...
        'cluster_valid column not found in BURST_FEATURES_CLUSTERED.');
    assert(ismember('cluster_good', T.Properties.VariableNames), ...
        'cluster_good column not found in BURST_FEATURES_CLUSTERED.');

    subject   = string(subject);
    condition = string(condition);
    leg       = lower(string(leg));
    muscle    = string(muscle);

    T.subject   = string(T.subject);
    T.condition = string(T.condition);
    T.leg       = lower(string(T.leg));
    T.muscle    = string(T.muscle);

    idxSignal = T.subject == subject & ...
                T.condition == condition & ...
                T.leg == leg & ...
                T.muscle == muscle;

    Tsig = T(idxSignal, :);

    if isempty(Tsig)
        error('No clustered bursts found for %s | %s | %s | %s.', ...
            subject, condition, leg, muscle);
    end

    Tsig = Tsig(Tsig.cluster_valid == true, :);
    if isempty(Tsig)
        error('Signal found, but no valid clustered bursts for %s | %s | %s | %s.', ...
            subject, condition, leg, muscle);
    end

    Tsig = sortrows(Tsig, 'burst_number');

    burst_keep = logical(Tsig.cluster_good);

    if ismember('cluster_decision_reason', Tsig.Properties.VariableNames)
        burst_reason = string(Tsig.cluster_decision_reason);
    else
        burst_reason = strings(height(Tsig),1);
        burst_reason(burst_keep)  = "cluster_good";
        burst_reason(~burst_keep) = "cluster_bad";
    end

    % ---------- Load the corresponding BURSTS_DET file ----------
    source_path = fullfile(burstsDir, sprintf('%s_EMG_BURSTS.mat', subject));
    if ~isfile(source_path)
        error('Could not find burst file for %s at %s', subject, source_path);
    end

    S = load(source_path);
    if ~isfield(S, 'BURSTS_DET')
        error('File does not contain BURSTS_DET: %s', source_path);
    end

    subjChar = char(subject);
    condChar = char(condition);
    legChar  = char(leg);
    musChar  = char(muscle);

    if ~isfield(S.BURSTS_DET, subjChar) || ...
       ~isfield(S.BURSTS_DET.(subjChar), condChar) || ...
       ~isfield(S.BURSTS_DET.(subjChar).(condChar), legChar) || ...
       ~isfield(S.BURSTS_DET.(subjChar).(condChar).(legChar), musChar)
        error('Signal not found in BURSTS_DET for %s | %s | %s | %s', ...
            subject, condition, leg, muscle);
    end

    entry = S.BURSTS_DET.(subjChar).(condChar).(legChar).(musChar);

    if ~isfield(entry, 'signal') || ~isfield(entry, 'bursts_idx')
        error('Missing signal or bursts_idx in source entry for %s | %s | %s | %s', ...
            subject, condition, leg, muscle);
    end

    x = entry.signal(:);

    if isfield(entry, 'envelope') && ~isempty(entry.envelope)
        x_env = entry.envelope(:);
    else
        x_env = [];
    end

    fs = get_fs_from_entry_or_config(entry, C);
    bursts_idx = entry.bursts_idx;

    % ---------- Align by burst_number if needed ----------
    if height(Tsig) ~= size(bursts_idx,1)
        warning(['Mismatch between clustered table and bursts_idx for %s | %s | %s | %s ' ...
                 '(%d table rows vs %d bursts). Trying alignment by burst_number.'], ...
                 subject, condition, leg, muscle, height(Tsig), size(bursts_idx,1));

        burst_keep_full   = false(size(bursts_idx,1),1);
        burst_reason_full = strings(size(bursts_idx,1),1);
        burst_reason_full(:) = "not_clustered";

        validBN = Tsig.burst_number >= 1 & Tsig.burst_number <= size(bursts_idx,1);
        bn = Tsig.burst_number(validBN);

        burst_keep_full(bn)   = burst_keep(validBN);
        burst_reason_full(bn) = burst_reason(validBN);

        burst_keep   = burst_keep_full;
        burst_reason = burst_reason_full;
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    plot_burst_qc_signal_cluster_final( ...
        char(subject), char(condition), char(leg), char(muscle), ...
        fs, x, x_env, bursts_idx, burst_keep, burst_reason, outDir, C);

    fprintf('Saved selected QC plot for %s | %s | %s | %s\n', ...
        subject, condition, leg, muscle);
end