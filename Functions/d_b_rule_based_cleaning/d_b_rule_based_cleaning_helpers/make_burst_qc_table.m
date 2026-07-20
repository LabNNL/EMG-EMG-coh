function T = make_burst_qc_table(subjID, cond, leg, mf, fs, bursts_idx, burst_keep, burst_reason, M, x_env)

nB = size(bursts_idx,1);

if nB == 0
    T = table( ...
        'Size', [0 25], ...
        'VariableTypes', { ...
            'string','string','string','string','string', ...   % burst_id, subject, condition, leg, muscle
            'double','double','double','double','double', ...   % burst_number, start_idx, end_idx, duration_samples, duration_s
            'logical','string','string', ...                    % is_valid_burst, keep_label, burst_reason
            'double','double','double','double','double','double', ... % duration_ms, spike_zmax, spike_global_z, deriv_zmax, plateau_frac, rail_frac
            'double','double','double','double', ...            % low_over_mid, high_over_mid, p2p_mV, rms_mV
            'double','double' ...                               % mean_envelope, peak_envelope
        }, ...
        'VariableNames', burst_qc_headers());
    return;
end

burst_id         = strings(nB,1);
subject          = repmat(string(subjID), nB, 1);
condition        = repmat(string(cond),   nB, 1);
leg_col          = repmat(string(leg),    nB, 1);
muscle           = repmat(string(mf),     nB, 1);
burst_number     = (1:nB).';
start_idx        = bursts_idx(:,1);
end_idx          = bursts_idx(:,2);
duration_samples = end_idx - start_idx + 1;
duration_s       = duration_samples ./ fs;

mean_envelope = nan(nB,1);
peak_envelope = nan(nB,1);
if ~isempty(x_env)
    for i = 1:nB
        seg = x_env(start_idx(i):end_idx(i));
        mean_envelope(i) = mean(seg,'omitnan');
        peak_envelope(i) = max(seg,[],'omitnan');
    end
end

for i = 1:nB
    burst_id(i) = sprintf('%s__%s__%s__%s__%04d', subjID, cond, leg, mf, i);
end

keep_label = repmat("reject", nB, 1);
keep_label(burst_keep) = "keep";

T = table( ...
    burst_id, subject, condition, leg_col, muscle, ...
    burst_number, start_idx, end_idx, duration_samples, duration_s, ...
    burst_keep, keep_label, burst_reason, ...
    M.duration_ms, M.spike_zmax, M.spike_global_z, M.deriv_zmax, M.plateau_frac, M.rail_frac, ...
    M.low_over_mid, M.high_over_mid, M.p2p_mV, M.rms_mV, ...
    mean_envelope, peak_envelope, ...
    'VariableNames', burst_qc_headers());
end