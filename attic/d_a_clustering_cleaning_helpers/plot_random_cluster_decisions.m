function plot_random_cluster_decisions(T, clean_clusters, inDir, QC, outDir)

    % Keep only rows that were actually clustered
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

    % cache loaded files so we don't reload the same .mat repeatedly
    fileCache = containers.Map('KeyType','char','ValueType','any');

    fprintf('\n=== Random cluster-decision QC plots ===\n');
    fprintf('Selected %d / %d signals\n', nPlot, nAvail);

    for i = 1:numel(idxSel)
        row0 = Tsignals(idxSel(i), :);

        subjID = char(row0.subject);
        cond   = char(row0.condition);
        leg    = char(row0.leg);
        mf     = char(row0.muscle);

        % rows for this exact signal
        idxSignal = T.subject == row0.subject & ...
                    T.condition == row0.condition & ...
                    T.leg == row0.leg & ...
                    T.muscle == row0.muscle;

        Tsig = T(idxSignal, :);
        Tsig = sortrows(Tsig, 'burst_number');

        % define keep/reject from cluster choice
        burst_keep = ismember(Tsig.cluster_id, clean_clusters);
        burst_reason = strings(height(Tsig),1);
        burst_reason(burst_keep)  = "clean_cluster";
        burst_reason(~burst_keep) = "rejected_cluster";

        % load original bursts file
        source_file = "";
        if ismember('source_file', T.Properties.VariableNames)
            source_file = Tsig.source_file(1);
        end

        % source_path = resolve_source_file(char(source_file), inDir, subjID);
        source_path = resolve_burst_file_path(inDir, subjID, source_file);

        if isempty(source_path) || ~isfile(source_path)
            warning('Could not find source file for %s | %s | %s | %s', subjID, cond, leg, mf);
            continue;
        end

        % load with cache
        if isKey(fileCache, source_path)
            S = fileCache(source_path);
        else
            S = load(source_path, 'BURSTS_DET');
            fileCache(source_path) = S;
        end

        if ~isfield(S, 'BURSTS_DET') || ~isfield(S.BURSTS_DET, subjID) || ...
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

        fs = get_fs_from_entry_or_config(entry, config_emg());

        bursts_idx = entry.bursts_idx;

        % safer alignment check: use burst_number when possible
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

        plot_burst_qc_signal_cluster( ...
            subjID, cond, leg, mf, fs, x, x_env, bursts_idx, ...
            burst_keep, burst_reason, Tsig, clean_clusters, outDir);

        fprintf('  Saved QC plot: %s | %s | %s | %s\n', subjID, cond, leg, mf);
    end
end

function source_path = resolve_burst_file_path(inDir, subjID, source_file)

    source_path = "";

    % 1) First choice: the actual bursts file in IN_DIR
    candidate = fullfile(inDir, sprintf('%s_EMG_BURSTS.mat', subjID));
    if isfile(candidate)
        source_path = string(candidate);
        return;
    end

    % 2) Second choice: basename of stored source_file, but only if it exists
    if ~isempty(source_file)
        [~, name, ext] = fileparts(source_file);
        candidate = fullfile(inDir, [name ext]);
        if isfile(candidate)
            source_path = string(candidate);
            return;
        end
    end

    % 3) Last choice: stored source_file itself, if valid
    if ~isempty(source_file) && isfile(source_file)
        source_path = string(source_file);
        return;
    end
end

% function source_path = resolve_source_file(source_file, inDir, subjID)

%     source_path = "";

%     % 1) use stored path directly if valid
%     if ~isempty(source_file) && isfile(source_file)
%         source_path = string(source_file);
%         return;
%     end

%     % 2) try basename inside current input directory
%     if ~isempty(source_file)
%         [~, name, ext] = fileparts(source_file);
%         candidate = fullfile(inDir, [name ext]);
%         if isfile(candidate)
%             source_path = string(candidate);
%             return;
%         end
%     end

%     % 3) fallback from subject ID
%     candidate = fullfile(inDir, sprintf('%s_EMG_BURSTS.mat', subjID));
%     if isfile(candidate)
%         source_path = string(candidate);
%         return;
%     end
% end


function plot_burst_qc_signal_cluster(subjID, cond, leg, mf, fs, x, x_env, bursts_idx, ...
    burst_keep, burst_reason, Tsig, clean_clusters, outDir)

    fig = figure('Visible','off','Color','w','Position',[100 100 1400 700]);
    t = (0:numel(x)-1)/fs;

    subplot(2,1,1);
    plot(t, x, 'k'); hold on;
    if ~isempty(x_env)
        plot(t, x_env, 'b', 'LineWidth', 1);
    end
    yl = ylim;

    for iB = 1:size(bursts_idx,1)
        x1 = (bursts_idx(iB,1)-1)/fs;
        x2 = (bursts_idx(iB,2)-1)/fs;

        if iB <= numel(burst_keep) && burst_keep(iB)
            fc = [0.85 0.95 0.85]; % green
        else
            fc = [1.00 0.80 0.80]; % red
        end

        patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], fc, ...
            'EdgeColor','none', 'FaceAlpha',0.35);
    end
    uistack(findobj(gca,'Type','line'),'top');

    title(sprintf('%s | %s | %s | %s', subjID, cond, leg, mf), 'Interpreter','none');
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;

    subplot(2,1,2);
    stairs(t, zeros(size(t)), 'w'); hold on;
    ylim([-0.1 1.1]);

    for iB = 1:size(bursts_idx,1)
        x1 = (bursts_idx(iB,1)-1)/fs;
        x2 = (bursts_idx(iB,2)-1)/fs;

        if iB <= numel(burst_keep)
            yv = double(burst_keep(iB));
        else
            yv = 0;
        end

        if yv == 1
            col = [0.10 0.60 0.10];
        else
            col = [0.80 0.10 0.10];
        end

        plot([x1 x2], [yv yv], 'LineWidth', 6, 'Color', col);
    end

    yticks([0 1]);
    yticklabels({'reject','keep'});
    xlabel('Time (s)');
    ylabel('Decision');
    title('Burst-level decision from clustering');
    grid on;

    nReject = sum(~burst_keep);
    nTotal  = numel(burst_keep);

    sgtitle(sprintf('%s | rejected bursts: %d / %d | clean clusters = [%s]', ...
        mf, nReject, nTotal, num2str(clean_clusters)), 'Interpreter','none');

    fname = sprintf('ClusterQC_%s_%s_%s_%s.png', subjID, cond, leg, mf);
    saveas(fig, fullfile(outDir, fname));
    close(fig);
end