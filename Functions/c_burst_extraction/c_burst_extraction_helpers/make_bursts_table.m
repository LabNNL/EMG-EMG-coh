function bursts_table = make_bursts_table( ...
    subjID, cond, leg, mf, fs, burst_list_all, x_env, cycle_starts, cycle_ends)

    nBursts = size(burst_list_all, 1);

    if nBursts == 0
        bursts_table = table( ...
            strings(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
            zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
            zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
            zeros(0,1), zeros(0,1), false(0,1), ...
            'VariableNames', { ...
                'burst_id','subject','condition','leg','muscle', ...
                'burst_number','start_idx','end_idx','center_idx','duration_samples','duration_s', ...
                'start_time_s','end_time_s','mean_envelope','peak_envelope', ...
                'cycle_idx_start','cycle_idx_end','burst_in_single_cycle'});
        return;
    end

    burst_id         = strings(nBursts,1);
    subject          = repmat(string(subjID), nBursts, 1);
    condition        = repmat(string(cond),   nBursts, 1);
    leg_col          = repmat(string(leg),    nBursts, 1);
    muscle           = repmat(string(mf),     nBursts, 1);
    burst_number     = (1:nBursts).';

    start_idx        = burst_list_all(:,1);
    end_idx          = burst_list_all(:,2);
    center_idx       = round((start_idx + end_idx)/2);
    duration_samples = end_idx - start_idx + 1;
    duration_s       = duration_samples ./ fs;
    start_time_s     = (start_idx - 1) ./ fs;
    end_time_s       = (end_idx - 1) ./ fs;

    mean_envelope    = nan(nBursts,1);
    peak_envelope    = nan(nBursts,1);

    cycle_idx_start  = nan(nBursts,1);
    cycle_idx_end    = nan(nBursts,1);
    burst_in_single_cycle = false(nBursts,1);

    for iB = 1:nBursts
        idx1 = start_idx(iB);
        idx2 = end_idx(iB);

        seg = x_env(idx1:idx2);
        mean_envelope(iB) = mean(seg, 'omitnan');
        peak_envelope(iB) = max(seg, [], 'omitnan');

        % unique ID
        burst_id(iB) = sprintf('%s__%s__%s__%s__%04d', ...
            subjID, cond, leg, mf, iB);

        % cycle linkage
        c1 = find(idx1 >= cycle_starts & idx1 <= cycle_ends, 1, 'first');
        c2 = find(idx2 >= cycle_starts & idx2 <= cycle_ends, 1, 'first');

        if ~isempty(c1), cycle_idx_start(iB) = c1; end
        if ~isempty(c2), cycle_idx_end(iB)   = c2; end

        burst_in_single_cycle(iB) = ~isnan(cycle_idx_start(iB)) && ...
                                    ~isnan(cycle_idx_end(iB))   && ...
                                    cycle_idx_start(iB) == cycle_idx_end(iB);
    end

    bursts_table = table( ...
        burst_id, subject, condition, leg_col, muscle, ...
        burst_number, start_idx, end_idx, center_idx, duration_samples, duration_s, ...
        start_time_s, end_time_s, mean_envelope, peak_envelope, ...
        cycle_idx_start, cycle_idx_end, burst_in_single_cycle, ...
        'VariableNames', { ...
            'burst_id','subject','condition','leg','muscle', ...
            'burst_number','start_idx','end_idx','center_idx','duration_samples','duration_s', ...
            'start_time_s','end_time_s','mean_envelope','peak_envelope', ...
            'cycle_idx_start','cycle_idx_end','burst_in_single_cycle'});
end