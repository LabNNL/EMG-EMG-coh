% tour_one_pair.m
% Follows one muscle pair of one participant through the pipeline and shows
% what each stage did to it, in one figure:
%   1. raw vs band-passed EMG (stages a, b)
%   2. activation envelope and bursts, good or bad (stages c-e)
%   3. which gait cycles were kept for this band, and why not (stage f)
%   4. wavelet power of the kept cycles (stage g)
%   5. the coherence map over the gait cycle, with the phase of interest (stage g)
%   6. the number that goes into the statistics (stages g, h)
%
% Reads existing outputs only (nothing is recomputed except the wavelet in
% panel 4). Loading the band files takes about a minute.
% See docs/overview.md for the terms, docs/data_structures.md for the files.

clear; close all;

% ---------- choose ----------
subjID   = 'CTL_01';
cond     = 'Flat';           % Flat | Medium | High
leg      = 'left';           % left | right
pairName = 'TAprox_TAdist';  % TAprox_TAdist | SOL_GM
band     = 'Gamma';          % a band of C.shared_wavelet.FreqBands

C = config_emg();
addpath(genpath(C.paths.helpers.coherence));
addpath(genpath(C.paths.toolboxes.wtc));
DATASET = upper(band);

% ---------- stage f: the pair ----------
fprintf('\nLoading stage f output for %s (band file %s)...\n', pairName, DATASET);
Lf = load(C.f_final_signals.io.out_mat_band.(band));
Sf = Lf.(['FINAL_PAIRED_SIGNALS_' DATASET]);
clear Lf
P = Sf.(subjID).(cond).(leg).(pairName);
clear Sf
mus = erase(string(P.muscles), ["EMG_", "_Concat"]);
fs = P.fs;
Tseg = P.final_cycle_segments_table;

fprintf('%s | %s | %s | %s = %s + %s\n', subjID, cond, leg, pairName, mus(1), mus(2));
fprintf('Stage a found %d gait cycles in %d trials for this leg.\n', P.n_cycles_total, numel(unique(P.cycle_trial_id)));
fprintf('Stage f kept %d of them for %s (needs >= %d): %s.\n', P.n_valid_cycles, band, P.min_cycles_required, ...
    string(ifelse(P.included_after_crosstalk, "included", "excluded: " + P.exclusion_reason)));

% ---------- stages a-c: the muscle-level signal ----------
Lc = load(fullfile(C.paths.bursts_dir, sprintf('%s_EMG_BURSTS.mat', subjID)), 'BURSTS_DET');
E1 = Lc.BURSTS_DET.(subjID).(cond).(leg).(char(P.muscles{1}));
clear Lc

% first run of consecutive cycles, to keep the plots readable
firstRun = find(P.cycle_run_id == P.cycle_run_id(1));
s0 = P.cycle_starts(firstRun(1));
s1 = P.cycle_ends(firstRun(end));
t = ((s0:s1) - s0) / fs;

fig = figure('Color', 'w', 'Position', [60 60 1500 900], 'Name', 'Tour of one pair');
tl = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('%s | %s | %s | %s | %s', subjID, cond, leg, pairName, band), 'Interpreter', 'none');

% 1. raw vs band-passed
ax = nexttile(tl);
plot(ax, t, E1.signal_raw(s0:s1) * 1e3, 'Color', [0.75 0.75 0.75]); hold(ax, 'on');
plot(ax, t, E1.signal(s0:s1) * 1e3, 'k');
xline(ax, (P.cycle_starts(firstRun) - s0) / fs, ':', 'Color', [0.3 0.3 0.8]);
xlim(ax, [0 t(end)]);
title(ax, sprintf('1. %s, first trial: raw (grey) under band-passed (black); dotted = heel strike', mus(1)));
xlabel(ax, 'time in the trial (s)'); ylabel(ax, 'EMG (mV)');

% 2. envelope and bursts
ax = nexttile(tl);
plot(ax, t, E1.envelope(s0:s1), 'k'); hold(ax, 'on');
B = P.muscle1_bursts_idx; keepB = P.muscle1_burst_keep_mask;
yl = max(E1.envelope(s0:s1));
for k = 1:size(B, 1)
    if B(k,2) < s0 || B(k,1) > s1, continue; end
    col = [0.2 0.7 0.3]; if ~keepB(k), col = [0.85 0.2 0.2]; end
    patch(ax, ([B(k,1) B(k,2) B(k,2) B(k,1)] - s0) / fs, [0 0 yl yl] * 1.05, col, 'FaceAlpha', 0.25, 'EdgeColor', 'none');
end
xlim(ax, [0 t(end)]);
title(ax, '2. envelope and bursts (stage c), green = good, red = bad (stages d-e)');
xlabel(ax, 'time in the trial (s)');
fprintf('%s has %d bursts, %d judged bad.\n', mus(1), size(B,1), sum(~keepB));

% 3. kept vs rejected cycles
ax = nexttile(tl);
keep = P.pair_cycle_keep_mask;
b = bar(ax, 1:numel(keep), ones(size(keep)), 1, 'FaceColor', 'flat', 'EdgeColor', 'w');
b.CData = repmat([0.2 0.7 0.3], numel(keep), 1); b.CData(~keep, :) = repmat([0.85 0.2 0.2], sum(~keep), 1);
hold(ax, 'on');
runEdges = find(diff(P.cycle_run_id) ~= 0) + 0.5;
xline(ax, runEdges, 'k-', 'LineWidth', 1.5);
ylim(ax, [0 1.4]); yticks(ax, []);
xlabel(ax, 'cycle number (black lines: new trial or gap)');
title(ax, sprintf('3. cycles kept for %s (green) or rejected (red), stage f', band));
reasons = P.pair_cycle_reason(~keep);
if ~isempty(reasons)
    [u, ~, j] = unique(reasons);
    fprintf('Rejected cycles, by reason:\n'); for k = 1:numel(u), fprintf('  %2d x %s\n', sum(j == k), u(k)); end
end

% 4. wavelet power of the first kept cycles (stage g, recomputed the way g does)
W = C.g_coherence.params;
DS = get_dataset_specific_coherence_settings(DATASET, W, C.g_coherence.group_plot);
Args = WaveletParameters(DS.FreqMin_this, DS.FreqMax_this, W.Resolution, W.WaveNumber, fs);
x1 = P.final_concatenated_signal_1(:); x2 = P.final_concatenated_signal_2(:);
[TFR1, ~, ~, ~, period, ~, ~, tinfo] = compute_pair_tfr(x1, x2, Tseg, P, W, Args);
Freq = 1 ./ period;
nShow = min(3, height(Tseg));
idx = Tseg.final_concat_start_idx_signal1(1):Tseg.final_concat_end_idx_signal1(nShow);
ax = nexttile(tl);
imagesc(ax, (idx - idx(1)) / fs, Freq, log10(abs(TFR1(:, idx)).^2)); axis(ax, 'xy'); colorbar(ax);
xline(ax, (Tseg.final_concat_start_idx_signal1(2:nShow) - idx(1)) / fs, 'w-');
title(ax, sprintf('4. %s wavelet power, first %d kept cycles (log); %d stretches transformed separately', mus(1), nShow, tinfo.n_segments));
xlabel(ax, 'time in the rebuilt signal (s)'); ylabel(ax, 'Hz');

% ---------- stage g: coherence ----------
fprintf('Loading stage g output (%s)...\n', DATASET);
Lg = load(C.h_stats.io.coh_mat_band.(band), 'COHERENCE_RESULTS');
R = Lg.COHERENCE_RESULTS.(subjID).(cond).(leg).(pairName);
clear Lg

ax = nexttile(tl);
imagesc(ax, R.Time_percent, R.Freq, R.Coherence_equalized); axis(ax, 'xy'); colorbar(ax); clim(ax, [0 1]);
hold(ax, 'on');
% grey out what is outside the phase of interest (it can wrap through 100% -> 0%)
poi = R.POI;
outside = true(1, numel(R.Time_percent)); outside(poi.indices) = false;
fr = [R.Freq(1) R.Freq(end)];
for seg = find_runs(outside)'
    x = R.Time_percent(seg');
    patch(ax, [x(1) x(2) x(2) x(1)], [fr(1) fr(1) fr(2) fr(2)], 'k', 'FaceAlpha', 0.55, 'EdgeColor', 'none');
end
title(ax, sprintf('5. coherence from %d evenly spaced cycles (equalized); bright = phase of interest (%g%% -> %g%%)', ...
    R.cycle_equalization.N_common, poi.start_pct, poi.end_pct));
xlabel(ax, '% of the gait cycle'); ylabel(ax, 'Hz');

% 6. the number used by the statistics
val = R.Metrics.equalized.poi.auc_norm.(band);
ax = nexttile(tl); axis(ax, 'off');
txt = {sprintf('6. %s_AUC_norm (POI, equalized) = %.3f', band, val), '', ...
    'Stage h averages it with the other leg and fits, per pair and band,', ...
    '   AUC_norm ~ AgeYears_z * condition + (1|subject)', '', ...
    'Results: Results/h_coherence_stats_pair_phase_main/tables/', ...
    '   CONTINUOUS_AGE_LME_TABLE.csv'};
text(ax, 0, 0.9, txt, 'VerticalAlignment', 'top', 'FontSize', 11, 'Interpreter', 'none');
fprintf('Coherence used: %d of %d valid cycles (N_common). %s_AUC_norm in the POI = %.3f\n', ...
    numel(R.equalized_cycle_numbers), R.n_cycles_used, band, val);

function r = find_runs(mask)
% [first last] index of each run of true values
    d = diff([false, mask(:)', false]);
    r = [find(d == 1)', find(d == -1)' - 1];
end

function out = ifelse(cond, a, b)
    if cond, out = a; else, out = b; end
end
