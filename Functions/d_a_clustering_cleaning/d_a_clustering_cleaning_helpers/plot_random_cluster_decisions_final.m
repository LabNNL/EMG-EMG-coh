function plot_random_cluster_decisions_final(T, inDir, QC, outDir)

    assert(ismember('cluster_valid', T.Properties.VariableNames), ...
        'cluster_valid column not found in BURST_FEATURES_CLUSTERED.');
    assert(ismember('cluster_good', T.Properties.VariableNames), ...
        'cluster_good column not found in BURST_FEATURES_CLUSTERED.');

    % Keep only bursts that were actually clustered
    T = T(T.cluster_valid == true, :);
    if isempty(T)
        warning('No clustered bursts available for QC plotting.');
        return;
    end

    % Build one row per signal
    signalKeys = strcat(T.subject, "||", T.condition, "||", T.leg, "||", T.muscle);
    [uniqueKeys, ia] = unique(signalKeys, 'stable');
    Tsignals = T(ia, :);
    Tsignals.signal_key = uniqueKeys;

    nAvail = height(Tsignals);
    nPlot  = min(QC.n_random_signals, nAvail);

    if nPlot == 0
        warning('No signals available for QC plotting.');
        return;
    end

    if isfield(QC, 'delete_old_png') && QC.delete_old_png
        oldPng = dir(fullfile(outDir, '*.png'));
        for i = 1:numel(oldPng)
            delete(fullfile(oldPng(i).folder, oldPng(i).name));
        end
    end

    if isfield(QC, 'random_seed') && ~isempty(QC.random_seed)
        rng(QC.random_seed);
    else
        rng('shuffle');
    end

    idxSel = randperm(nAvail, nPlot);

    fileCache = containers.Map('KeyType','char', 'ValueType','any');

    fprintf('\n=== Random cluster-decision QC plots ===\n');
    fprintf('Selected %d / %d signals\n', nPlot, nAvail);

    C = config_emg();

    for i = 1:numel(idxSel)
        row0 = Tsignals(idxSel(i), :);

        subjID = char(row0.subject);
        cond   = char(row0.condition);
        leg    = char(row0.leg);
        mf     = char(row0.muscle);

        idxSignal = T.subject == row0.subject & ...
                    T.condition == row0.condition & ...
                    T.leg == row0.leg & ...
                    T.muscle == row0.muscle;

        Tsig = T(idxSignal, :);
        Tsig = sortrows(Tsig, 'burst_number');

        % Final keep/reject decision comes directly from clustering output
        burst_keep = logical(Tsig.cluster_good);

        if ismember('cluster_decision_reason', Tsig.Properties.VariableNames)
            burst_reason = string(Tsig.cluster_decision_reason);
        else
            burst_reason = strings(height(Tsig),1);
            burst_reason(burst_keep)  = "cluster_good";
            burst_reason(~burst_keep) = "cluster_bad";
        end

        % Always load the actual bursts file from IN_DIR
        source_path = fullfile(inDir, sprintf('%s_EMG_BURSTS.mat', subjID));
        if ~isfile(source_path)
            warning('Could not find burst file for %s at %s', subjID, source_path);
            continue;
        end

        if isKey(fileCache, source_path)
            S = fileCache(source_path);
        else
            S = load(source_path);
            fileCache(source_path) = S;
        end

        if ~isfield(S, 'BURSTS_DET')
            warning('File does not contain BURSTS_DET: %s', source_path);
            continue;
        end

        if ~isfield(S.BURSTS_DET, subjID) || ...
           ~isfield(S.BURSTS_DET.(subjID), cond) || ...
           ~isfield(S.BURSTS_DET.(subjID).(cond), leg) || ...
           ~isfield(S.BURSTS_DET.(subjID).(cond).(leg), mf)
            warning('Signal not found in BURSTS_DET for %s | %s | %s | %s', subjID, cond, leg, mf);
            continue;
        end

        entry = S.BURSTS_DET.(subjID).(cond).(leg).(mf);

        if ~isfield(entry, 'signal') || ~isfield(entry, 'bursts_idx')
            warning('Missing signal or bursts_idx in source entry for %s | %s | %s | %s', subjID, cond, leg, mf);
            continue;
        end

        x = entry.signal(:);

        if isfield(entry, 'envelope') && ~isempty(entry.envelope)
            x_env = entry.envelope(:);
        else
            x_env = [];
        end

        fs = get_fs_from_entry_or_config(entry, C);
        bursts_idx = entry.bursts_idx;

        % Align by burst_number if needed
        if height(Tsig) ~= size(bursts_idx,1)
            warning(['Mismatch between clustered table and bursts_idx for %s | %s | %s | %s ' ...
                     '(%d table rows vs %d bursts). Trying alignment by burst_number.'], ...
                     subjID, cond, leg, mf, height(Tsig), size(bursts_idx,1));

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

        plot_burst_qc_signal_cluster_final( ...
            subjID, cond, leg, mf, fs, x, x_env, bursts_idx, ...
            burst_keep, burst_reason, outDir, C);

        fprintf('  Saved QC plot: %s | %s | %s | %s\n', subjID, cond, leg, mf);
    end
end