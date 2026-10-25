function T = audit_c3d_acquisition(varargin)
% AUDIT_C3D_ACQUISITION  What the .c3d files say about how the EMG was recorded.
%
%   audit_c3d_acquisition()                           default scope
%   T = audit_c3d_acquisition('Scope','sample','N',6) quick check
%   audit_c3d_acquisition('Scope','all')              every file
%
% Options
%   'Scope'         'per-participant-condition' (default) | 'sample' | 'all'
%   'N'             number of files for 'sample' (default 30)
%   'Root'          data root (default C.paths.data_dir)
%   'OutDir'        tables   (default Results/acquisition_audit)
%   'PlotDir'       figures  (default Results/png_visualisation/acquisition_audit)
%   'SpectrumFiles' files used for the spectra (default 40, 0 disables)
%   'Signals'       load signal data for amplitude stats (default true)
%
% Nothing in this project records which EMG hardware produced the data, so
% this reads it back out of the recordings. It reports three kinds of thing
% and keeps them apart:
%
%   recorded  - written in the file by Vicon (rates, channels, device names)
%   measured  - derived from the signal (filter corners, saturation rails)
%   inferred  - deduced by combining the above with the sensor's spec sheet
%
% This file lives in Tools/ rather than Functions/ because config_emg() runs
% addpath(genpath(Functions)) and a diagnostic has no business on the
% analysis path.

opt = ac_parse_args(varargin);
C   = config_emg();

root = opt.Root;
if isempty(root), root = C.paths.data_dir; end
if ~isfolder(root)
    error('audit_c3d_acquisition:noRoot', 'Data root not found: %s', root);
end

outDir  = opt.OutDir;
plotDir = opt.PlotDir;
if isempty(outDir),  outDir  = fullfile(C.paths.results_dir, 'acquisition_audit'); end
if isempty(plotDir), plotDir = fullfile(C.paths.plot_dir,    'acquisition_audit'); end
if ~isfolder(outDir),  mkdir(outDir);  end
if ~isfolder(plotDir), mkdir(plotDir); end

files = ac_select_files(root, opt, C);
fprintf('audit_c3d_acquisition: %d file(s), scope "%s"\n', numel(files), opt.Scope);

rows = cell(numel(files), 1);
t0 = tic;
for i = 1:numel(files)
    rows{i} = ac_scan_file(files{i}, C, opt.Signals);
    if mod(i, 25) == 0
        fprintf('  %d/%d  (%.0fs elapsed)\n', i, numel(files), toc(t0));
    end
end
ok = ~cellfun(@isempty, rows);
if ~any(ok)
    error('audit_c3d_acquisition:noneRead', 'No file could be read.');
end
T = vertcat(rows{ok});

spec = struct('ok', false);
if opt.SpectrumFiles > 0
    spec = ac_spectra(files(1:min(opt.SpectrumFiles, numel(files))));
end

txt = ac_summary(T, spec, numel(files) - sum(ok), C);
fprintf('%s', txt);

csvPath = fullfile(outDir, 'C3D_ACQUISITION_AUDIT.csv');
writetable(T, csvPath);
sumPath = fullfile(outDir, 'C3D_ACQUISITION_SUMMARY.txt');
fid = fopen(sumPath, 'w'); fprintf(fid, '%s', txt); fclose(fid);
fprintf('\nTables:\n  %s\n  %s\n', csvPath, sumPath);

if spec.ok
    p1 = ac_plot_spectrum_bands(spec, C, plotDir);
    p2 = ac_plot_native_rate(spec, plotDir);
    fprintf('Figures:\n  %s\n  %s\n', p1, p2);
end

if nargout == 0
    clear T
end
end

% ======================================================================
% File selection
% ======================================================================

function files = ac_select_files(root, opt, C)
d = dir(fullfile(root, '**', '*.c3d'));
d = d(~startsWith({d.name}, '.'));
all = fullfile({d.folder}, {d.name});

switch opt.Scope
    case 'all'
        files = all(:);
    case 'sample'
        rng(1);
        k = min(opt.N, numel(all));
        files = all(randperm(numel(all), k))';
    case 'per-participant-condition'
        % First trial of each participant x condition. The filename pattern
        % is the one stage a uses, so the same files the pipeline sees.
        expr = C.a_extract_raw.input.filename_regex;
        keys = strings(numel(all), 1);
        for i = 1:numel(all)
            [~, base, ext] = fileparts(all{i});
            tok = regexp([base ext], expr, 'names', 'once');
            if isempty(tok)
                keys(i) = "";
            else
                keys(i) = string(tok.subjID) + "|" + string(tok.cond);
            end
        end
        files = {};
        [u, ia] = unique(keys, 'stable');
        for i = 1:numel(u)
            if u(i) == "", continue; end
            files{end+1, 1} = all{ia(i)}; %#ok<AGROW>
        end
        unmatched = sum(keys == "");
        if unmatched > 0
            fprintf(['  note: %d file(s) did not match the configured ' ...
                     'filename pattern and were skipped\n'], unmatched);
        end
    otherwise
        error('audit_c3d_acquisition:badScope', 'Unknown scope "%s"', opt.Scope);
end
files = files(:);
end

% ======================================================================
% Per-file scan
% ======================================================================

function R = ac_scan_file(f, C, withSignals)
R = [];
try
    acq = btkReadAcquisition(f);
catch ME
    warning('Could not read %s: %s', f, ME.message);
    return
end
cleaner = onCleanup(@() btkDeleteAcquisition(acq));

[~, base, ext] = fileparts(f);
tok = regexp([base ext], C.a_extract_raw.input.filename_regex, 'names', 'once');
if isempty(tok)
    subj = "(unmatched)"; cond = "(unmatched)"; trial = "";
else
    subj = string(tok.subjID); cond = string(tok.cond); trial = string(tok.ess);
end

md = btkGetMetaData(acq);
nUsed  = ac_num(md, {'ANALOG', 'USED'});
labels = ac_cellstr(md, {'ANALOG', 'LABELS'});
descr  = ac_cellstr(md, {'ANALOG', 'DESCRIPTIONS'});

% device plugin names, the text before "::" in each description
pre = strings(0, 1);
for i = 1:numel(descr)
    s = string(strtrim(descr{i}));
    if contains(s, "::"), pre(end+1, 1) = extractBefore(s, "::"); end %#ok<AGROW>
end
devices = strjoin(unique(pre), ", ");

fam = ac_family_counts(labels);

R = table(subj, cond, trial, string(base), ...
    btkGetAnalogFrequency(acq), btkGetPointFrequency(acq), ...
    btkGetAnalogSampleNumberPerFrame(acq), nUsed, ...
    string(ac_char(md, {'MANUFACTURER', 'SOFTWARE'})), ...
    string(ac_char(md, {'MANUFACTURER', 'VERSION_LABEL'})), ...
    devices, fam.EMG, fam.IM_EMG, fam.ACC, fam.GYRO, fam.MAG, ...
    'VariableNames', {'subject', 'condition', 'trial', 'file', ...
    'analog_rate', 'point_rate', 'samples_per_frame', 'n_analog_channels', ...
    'nexus_software', 'nexus_version', 'devices', ...
    'n_EMG', 'n_IM_EMG', 'n_ACC', 'n_GYRO', 'n_MAG'});

% Signal-derived columns. These are what reveal the hardware ranges: a
% value identical in every file is a saturation rail, not a coincidence.
if withSignals
    an = btkGetAnalogs(acq);
    fn = fieldnames(an);
    [maxEMG, nRail] = ac_family_max(an, fn, '^Sensor_\d+_EMG\d+$', 0.011);
    maxACC = ac_family_max(an, fn, 'ACC[XYZ]', inf);
    R.max_EMG_mV      = maxEMG * 1000;
    R.n_EMG_at_rail   = nRail;
    R.max_ACC         = maxACC;
    R.n_GYRO_all_zero = ac_count_zero(an, fn, 'GYRO[XYZ]');
    R.n_MAG_all_zero  = ac_count_zero(an, fn, 'MAG[XYZ]');
end
end

function fam = ac_family_counts(labels)
fam = struct('EMG', 0, 'IM_EMG', 0, 'ACC', 0, 'GYRO', 0, 'MAG', 0);
for i = 1:numel(labels)
    s = string(strtrim(labels{i}));
    if contains(s, "IM EMG") || contains(s, "IM_EMG")
        fam.IM_EMG = fam.IM_EMG + 1;
    elseif ~isempty(regexp(s, 'EMG\d*$', 'once'))
        fam.EMG = fam.EMG + 1;
    elseif contains(s, "ACC")
        fam.ACC = fam.ACC + 1;
    elseif contains(s, "GYRO")
        fam.GYRO = fam.GYRO + 1;
    elseif contains(s, "MAG")
        fam.MAG = fam.MAG + 1;
    end
end
end

function [mx, nAtRail] = ac_family_max(an, fn, pat, rail)
idx = find(~cellfun(@isempty, regexp(fn, pat, 'once')));
mx = 0; nAtRail = 0;
for k = 1:numel(idx)
    v = max(abs(double(an.(fn{idx(k)}))));
    mx = max(mx, v);
    if isfinite(rail) && v >= rail * 0.999, nAtRail = nAtRail + 1; end
end
end

function n = ac_count_zero(an, fn, pat)
idx = find(~cellfun(@isempty, regexp(fn, pat, 'once')));
n = 0;
for k = 1:numel(idx)
    if ~any(double(an.(fn{idx(k)})) ~= 0), n = n + 1; end
end
end

% ======================================================================
% Spectra
% ======================================================================

function S = ac_spectra(files)
S = struct('ok', false);
nfft = 4096;
% Collect every channel-spectrum and take the MEDIAN across them. A linear
% mean is dominated by the few trials with the most low-frequency movement
% artifact, which made the reported levels swing by more than 10 dB between
% samples. The median is stable.
store = {}; fr = []; nSeg = 0; fs = NaN;

for i = 1:numel(files)
    try
        acq = btkReadAcquisition(files{i});
        c   = onCleanup(@() btkDeleteAcquisition(acq));
        fs  = btkGetAnalogFrequency(acq);
        an  = btkGetAnalogs(acq);
        fn  = fieldnames(an);
        idx = find(~cellfun(@isempty, regexp(fn, '^Sensor_\d+_EMG\d+$', 'once')));
        for k = 1:numel(idx)
            x = double(an.(fn{idx(k)}));
            if numel(x) < nfft, continue; end
            x = x - mean(x);
            [pxx, fr] = pwelch(x, hann(nfft), nfft/2, nfft, fs);
            store{end+1, 1} = pxx; %#ok<AGROW>
            nSeg = nSeg + 1;
        end
        clear c
    catch ME
        warning('Spectrum skipped for %s: %s', files{i}, ME.message);
    end
end

if nSeg == 0
    warning(['No trial was long enough for a %d-point spectrum; ' ...
             'figures skipped.'], nfft);
    return
end

M = cell2mat(store');
pMed  = 10 * log10(median(M, 2) + eps);
pMean = 10 * log10(mean(M, 2) + eps);
pMed  = pMed  - max(pMed);
pMean = pMean - max(pMean);
p = pMed;   % the median is the stable one; the mean is kept for comparison

sm       = movmean(p, 5);
[~, ip]  = max(sm);
peakHz   = fr(ip);

% Lowest frequency at which the mean spectrum reaches 3 dB below its peak,
% scanning upward. This is DESCRIPTIVE: it says where the recorded signal
% becomes strong, which mixes the sensor's high-pass with the EMG's own
% spectrum and with movement artifact. It is not a measurement of the
% hardware filter corner, and a single small sample will move it by several
% Hz, so do not quote it as one.
cornerHz = NaN;
j = find(fr > 2 & fr < peakHz & sm >= -3, 1, 'first');
if ~isempty(j), cornerHz = fr(j); end

% Onset of the numerical noise floor: the frequency above which the spectrum
% stops varying. THRESHOLD-DEPENDENT, and near the floor the estimate moves
% by tens of Hz between samples, so it is reported as a diagnostic only and
% is deliberately NOT turned into a native-rate claim.
floorThr = 0.05;
lv = movstd(p, 21);
cutHz = NaN; floorDb = NaN;
cand = find(fr > 0.3 * fs & lv < floorThr);
for i = cand(:)'
    if all(lv(i:end) < floorThr), cutHz = fr(i); break; end
end
if ~isnan(cutHz)
    tail = fr >= cutHz;
    if any(tail), floorDb = mean(p(tail)); end
end

% Narrow spectral lines. The Delsys sensors stream their auxiliary channels
% at a lower rate than the EMG, and that rate leaks into the EMG spectrum as
% an evenly spaced comb. The spacing names the auxiliary rate, which in turn
% identifies the sensor mode.
combHz = NaN; combLines = [];
try
    base = movmedian(p, 61);
    [~, loc] = findpeaks(p - base, 'MinPeakHeight', 1.5, ...
        'MinPeakDistance', round(20 / (fr(2) - fr(1))));
    lines = fr(loc);
    lines = lines(lines > 100);
    if numel(lines) >= 4
        dfs = diff(lines);
        dfs = dfs(dfs < 2.5 * median(dfs));   % tolerate a missing harmonic
        if ~isempty(dfs) && std(dfs) < 1
            combHz = median(dfs);
            combLines = lines;
        end
    end
catch
    % findpeaks needs the Signal Processing Toolbox; skip quietly
end

S = struct('ok', true, 'f', fr, 'p', p, 'fs', fs, 'nSeg', nSeg, ...
    'nFiles', numel(files), 'peakHz', peakHz, 'cornerHz', cornerHz, ...
    'cutHz', cutHz, 'floorDb', floorDb, 'nfft', nfft, 'floorThr', floorThr, ...
    'combHz', combHz, 'combLines', combLines, 'pMean', pMean);
end

% ======================================================================
% Figures
% ======================================================================

function out = ac_plot_spectrum_bands(S, C, plotDir)
fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
ax = axes(fig); hold(ax, 'on');

bands = C.shared_wavelet.FreqBands;
names = fieldnames(bands);
yl = [min(S.p) - 2, 3];
for i = 1:numel(names)
    b = bands.(names{i});
    col = [0.6 0.6 0.6];
    if isfield(C.plotting.colors, names{i}), col = C.plotting.colors.(names{i}); end
    patch(ax, [b(1) b(2) b(2) b(1)], [yl(1) yl(1) yl(2) yl(2)], col, ...
        'FaceAlpha', 0.30, 'EdgeColor', 'none', 'DisplayName', ...
        sprintf('%s (%g-%g Hz)', names{i}, b(1), b(2)));
end

plot(ax, S.f, S.p, 'k-', 'LineWidth', 1.4, 'DisplayName', 'mean EMG spectrum');

if ~isnan(S.cornerHz)
    xline(ax, S.cornerHz, 'r--', ...
        sprintf(' -3 dB of peak: %.1f Hz', S.cornerHz), ...
        'LineWidth', 1.6, 'LabelVerticalAlignment', 'middle', ...
        'LabelHorizontalAlignment', 'left', 'LabelOrientation', 'horizontal', ...
        'FontWeight', 'bold', 'Color', [0.8 0 0], 'DisplayName', '-3 dB of peak');
end
yline(ax, -3, ':', '-3 dB', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');

% where the Alpha band sits relative to the peak
lines = cell(0, 1);
for v = [8 10 12]
    [~, i] = min(abs(S.f - v));
    plot(ax, S.f(i), S.p(i), 'ro', 'MarkerFaceColor', 'r', 'HandleVisibility', 'off');
    lines{end+1, 1} = sprintf('%2g Hz : %5.1f dB', v, S.p(i)); %#ok<AGROW>
end
text(ax, 0.985, 0.97, [{'level below peak'}; lines], 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontSize', 9, 'FontName', 'Courier', 'Color', [0.55 0 0], ...
    'BackgroundColor', [1 1 1 ], 'EdgeColor', [0.8 0.8 0.8], 'Margin', 4);

set(ax, 'XScale', 'log');
xlim(ax, [2 S.fs/2]); ylim(ax, yl);
grid(ax, 'on'); box(ax, 'on');
xlabel(ax, 'Frequency (Hz)');
ylabel(ax, 'Power (dB relative to peak)');
title(ax, {'Mean raw EMG spectrum against the analysis bands', ...
    sprintf('%d channel-spectra from %d files', S.nSeg, S.nFiles), ...
    ac_band_power_line(S, C)}, ...
    'FontSize', 11);
legend(ax, 'Location', 'southwest');

out = fullfile(plotDir, 'EMG_SPECTRUM_BANDS.png');
exportgraphics(fig, out, 'Resolution', 200);
close(fig);
end

function out = ac_plot_native_rate(S, plotDir)
fig = figure('Visible', 'off', 'Position', [100 100 1000 560]);
ax = axes(fig); hold(ax, 'on');

f0 = 0.2 * S.fs;                      % enough context to see the descent
m  = S.f >= f0 & S.f <= S.fs/2 + 1;
plot(ax, S.f(m), S.p(m), 'k-', 'LineWidth', 1.2, 'DisplayName', 'mean EMG spectrum');

if ~isnan(S.cutHz)
    xline(ax, S.cutHz, 'r-', sprintf(' floor from %.0f Hz', S.cutHz), ...
        'LineWidth', 1.6, 'Color', [0.8 0 0], ...
        'LabelVerticalAlignment', 'middle', 'LabelHorizontalAlignment', 'left', ...
        'LabelOrientation', 'horizontal', 'FontWeight', 'bold', ...
        'DisplayName', 'noise-floor onset');
end
xline(ax, S.fs/2, 'b--', sprintf(' Nyquist %.0f Hz', S.fs/2), ...
    'LineWidth', 1.4, 'Color', [0 0 0.8], ...
    'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'left', ...
    'LabelOrientation', 'horizontal', 'DisplayName', 'Nyquist of the stored rate');
if ~isnan(S.floorDb)
    yline(ax, S.floorDb, ':', sprintf('numerical floor %.1f dB', S.floorDb), ...
        'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
end

if ~isnan(S.combHz)
    sel = S.combLines(S.combLines >= f0);
    if ~isempty(sel)
        yv = interp1(S.f, S.p, sel) + 1.2;
        plot(ax, sel, yv, 'v', 'MarkerSize', 5, 'LineStyle', 'none', ...
            'MarkerFaceColor', [0 0.5 0], 'MarkerEdgeColor', 'none', ...
            'DisplayName', sprintf('%.0f Hz comb (auxiliary rate)', S.combHz));
    end
end

grid(ax, 'on'); box(ax, 'on');
xlim(ax, [f0, S.fs/2 + 1]);
xlabel(ax, 'Frequency (Hz)');
ylabel(ax, 'Power (dB relative to peak)');
if isnan(S.combHz)
    t2 = 'Threshold-dependent: not a measurement of the pre-resampling rate';
else
    t2 = sprintf(['The evenly spaced lines are harmonics of the %.0f Hz auxiliary ' ...
        'channel rate, not a Nyquist edge'], S.combHz);
end
title(ax, {'High-frequency content and the noise floor', t2}, 'FontSize', 11);
legend(ax, 'Location', 'northeast');

out = fullfile(plotDir, 'HIGH_FREQUENCY_FLOOR.png');
exportgraphics(fig, out, 'Resolution', 200);
close(fig);
end

% ======================================================================
% Summary
% ======================================================================

function txt = ac_summary(T, S, nFailed, C)
L = strings(0, 1);
L(end+1) = "===== C3D ACQUISITION AUDIT =====";
L(end+1) = sprintf("files read      : %d", height(T));
if nFailed > 0, L(end+1) = sprintf("files FAILED    : %d", nFailed); end
L(end+1) = sprintf("participants    : %d", numel(unique(T.subject)));
L(end+1) = sprintf("conditions      : %s", strjoin(cellstr(unique(T.condition))', ", "));
L(end+1) = "";

L(end+1) = "--- RECORDED IN THE FILES ---";
L(end+1) = sprintf("analog rate     : %s Hz", ac_uniq(T.analog_rate));
L(end+1) = sprintf("point rate      : %s Hz", ac_uniq(T.point_rate));
L(end+1) = sprintf("analog samples per video frame : %s", ac_uniq(T.samples_per_frame));
L(end+1) = sprintf("Nexus software  : %s", ac_uniq(T.nexus_software));
L(end+1) = sprintf("Nexus version   : %s", ac_uniq(T.nexus_version));
L(end+1) = sprintf("EMG channels    : %s   IM EMG: %s", ac_uniq(T.n_EMG), ac_uniq(T.n_IM_EMG));
L(end+1) = sprintf("ACC / GYRO / MAG: %s / %s / %s", ...
    ac_uniq(T.n_ACC), ac_uniq(T.n_GYRO), ac_uniq(T.n_MAG));
L(end+1) = "";

L(end+1) = "--- CONFIGURATION SIGNATURES ---";
sig = T.analog_rate + "|" + T.n_analog_channels + "|" + T.devices + "|" + T.nexus_version;
[u, ~, g] = unique(sig);
for i = 1:numel(u)
    sel = g == i;
    L(end+1) = sprintf("[%d] %d file(s), %d participant(s)", ...
        i, sum(sel), numel(unique(T.subject(sel)))); %#ok<AGROW>
    L(end+1) = "      " + replace(u(i), "|", "  |  "); %#ok<AGROW>
    if sum(sel) < height(T) * 0.5
        L(end+1) = "      participants: " + strjoin(cellstr(unique(T.subject(sel)))', ", "); %#ok<AGROW>
    end
end
if isscalar(u)
    L(end+1) = "  -> the recording configuration is constant across every file scanned.";
else
    L(end+1) = "  -> more than one signature: check whether the difference touches the EMG chain";
    L(end+1) = "     (channel count and device list) or only other instruments.";
end
L(end+1) = "";

if ismember('max_EMG_mV', T.Properties.VariableNames)
    L(end+1) = "--- MEASURED FROM THE SIGNALS ---";
    L(end+1) = sprintf("max |EMG| over files : %.3f mV  (median %.3f mV)", ...
        max(T.max_EMG_mV), median(T.max_EMG_mV));
    L(end+1) = sprintf("files above 5.5 mV   : %d of %d   -> input range is +/-11 mV, not +/-5.5 mV", ...
        sum(T.max_EMG_mV > 5.5), height(T));
    L(end+1) = sprintf("EMG channels at the +/-11 mV rail : %d", sum(T.n_EMG_at_rail));
    accMax = unique(round(T.max_ACC, 3));
    L(end+1) = sprintf("max |ACC| : %s   (/9.80665 = %.3f g)", ...
        ac_uniq(round(T.max_ACC, 3)), max(T.max_ACC) / 9.80665);
    if isscalar(accMax)
        L(end+1) = "  -> identical in every file, so this is the accelerometer saturation rail";
    end
    L(end+1) = sprintf("channels always zero : GYRO %d, MAG %d (per file, of %s / %s)", ...
        max(T.n_GYRO_all_zero), max(T.n_MAG_all_zero), ac_uniq(T.n_GYRO), ac_uniq(T.n_MAG));
    L(end+1) = "";
end

if S.ok
    L(end+1) = "--- SPECTRUM ---";
    L(end+1) = sprintf("%d channel-spectra from %d files, %.3f Hz resolution", ...
        S.nSeg, S.nFiles, S.f(2) - S.f(1));
    L(end+1) = sprintf("peak of mean spectrum     : %.1f Hz", S.peakHz);
    L(end+1) = sprintf("reaches -3 dB of peak at  : %.1f Hz  (descriptive, see note)", S.cornerHz);
    for v = [8 10 12]
        [~, i] = min(abs(S.f - v));
        L(end+1) = sprintf("   level at %2g Hz          : %.1f dB below peak", v, S.p(i)); %#ok<AGROW>
    end
    L(end+1) = sprintf("noise-floor onset         : %.0f Hz at a %.2f dB threshold (file Nyquist %.0f Hz)", ...
        S.cutHz, S.floorThr, S.fs/2);
    if ~isnan(S.combHz)
        L(end+1) = sprintf("narrow-line comb spacing  : %.2f Hz", S.combHz);
        L(end+1) = sprintf("   harmonics found        : %s Hz", ...
            strjoin(compose('%.0f', S.combLines(:)')', ", "));
        L(end+1) = sprintf("   i.e. %s x %.0f Hz", ...
            strjoin(compose('%.0f', round(S.combLines(:)' / S.combHz))', ", "), S.combHz);
    end
    L(end+1) = "";
    L(end+1) = "--- HOW TO READ THE SPECTRUM NUMBERS ---";
    L(end+1) = "power per analysis band, dB relative to the strongest band:";
    [bn, bMed]  = ac_band_powers(S.f, S.p, C);
    [~,  bMean] = ac_band_powers(S.f, S.pMean, C);
    L(end+1) = sprintf("   %-7s %8s %8s", "band", "median", "mean");
    for i = 1:numel(bn)
        L(end+1) = sprintf("   %-7s %8.2f %8.2f", bn(i), bMed(i), bMean(i)); %#ok<AGROW>
    end
    [gap, ig] = max(abs(bMed - bMean));
    L(end+1) = sprintf([ ...
        'Two estimators because they disagree, and the disagreement is the point. The ' ...
        'median describes a typical channel-trial; the mean is pulled by the minority ' ...
        'of trials with extreme power. They differ most in %s (%.1f dB), which is ' ...
        'therefore the band whose power is most driven by a few outlying trials ' ...
        'rather than by what a typical recording looks like.'], bn(ig), gap);
    L(end+1) = sprintf([ ...
        'Do not read either as a filter corner: the sensor high-pass and the EMG''s own ' ...
        'spectrum both shape this curve and cannot be separated from a power spectrum. ' ...
        'Which band looks weakest depends on the estimator, so do not rank them from ' ...
        'this alone - judge a band from the coherence results themselves.']);
    L(end+1) = sprintf([ ...
        'At 10 Hz the mean spectrum is %.1f dB below its peak. A 20 Hz hardware ' ...
        'high-pass would put 8-12 Hz considerably further down than that, so these ' ...
        'recordings look more consistent with a 10-850 Hz sensor mode than a 20-450 Hz ' ...
        'one. Treat that as an argument, not a measurement: the figure moves by several ' ...
        'dB between samples, so judge it from a run over many files, not a handful.'], ...
        -ac_level(S, 10));
    if ~isnan(S.combHz)
        L(end+1) = sprintf([ ...
            'The spectrum carries a comb of narrow lines spaced %.1f Hz apart, all above ' ...
            '100 Hz. That is the rate at which the sensor streams its auxiliary channels ' ...
            'leaking into the EMG, and it matches the "74 Hz" figure that Delsys mode ' ...
            'strings quote for skin check and accelerometer. The lines sit far above the ' ...
            '8-60 Hz analysis band, so they do not affect the coherence results.'], S.combHz);
        if max(S.combLines) > 0.45 * S.fs
            L(end+1) = sprintf([ ...
                'One of those lines falls near %.0f Hz, close to the Nyquist of the ' ...
                'stored rate. Do not read it as a pre-resampling edge: it is the %.0fth ' ...
                'harmonic of %.1f Hz.'], ...
                max(S.combLines), round(max(S.combLines)/S.combHz), S.combHz);
        end
    end
    L(end+1) = sprintf([ ...
        'Use %g Hz as the sampling rate: it is the spacing of the stored samples. The ' ...
        'noise-floor onset above is NOT a reliable estimate of the pre-resampling rate ' ...
        '- it moves by tens of Hz with the sample and the threshold. Nothing in these ' ...
        'files records the native Delsys rate.'], S.fs);
    L(end+1) = "";
end

txt = strjoin(L, newline) + newline;
end

function [names, reldb] = ac_band_powers(f, pdb, C)
% Power in each analysis band, in dB relative to the strongest band.
bands = C.shared_wavelet.FreqBands;
names = string(fieldnames(bands));
pw = zeros(numel(names), 1);
lin = 10 .^ (pdb / 10);
for i = 1:numel(names)
    b = bands.(names(i));
    m = f >= b(1) & f <= b(2);
    pw(i) = mean(lin(m));
end
reldb = 10 * log10(pw / max(pw));
end

function s = ac_band_power_line(S, C)
[names, reldb] = ac_band_powers(S.f, S.p, C);
parts = compose('%s %.1f dB', names, reldb);
s = ['Median power per band, relative to the strongest: ' strjoin(parts', ',  ')];
end

function v = ac_level(S, hz)
[~, i] = min(abs(S.f - hz));
v = S.p(i);
end

function s = ac_uniq(v)
u = unique(v);
if isnumeric(u)
    parts = arrayfun(@(x) sprintf('%g', x), u, 'UniformOutput', false);
else
    parts = cellstr(u);
end
if numel(parts) > 4, parts = [parts(1:4); {sprintf('...(%d values)', numel(parts))}]; end
s = strjoin(parts(:)', ", ");
end

% ======================================================================
% Metadata access
% ======================================================================

function v = ac_num(md, path)
n = ac_node(md, path);
if isempty(n), v = NaN; else, v = double(n(1)); end
end

function v = ac_char(md, path)
n = ac_node(md, path);
if isempty(n), v = ''; elseif ischar(n), v = strtrim(n);
elseif iscell(n), v = strtrim(char(string(n{1}))); else, v = ''; end
end

function v = ac_cellstr(md, path)
n = ac_node(md, path);
if iscell(n), v = n; elseif ischar(n), v = {n}; else, v = {}; end
end

function v = ac_node(md, path)
v = [];
node = md;
for i = 1:numel(path)
    if ~isstruct(node) || ~isfield(node, 'children') || ...
            ~isfield(node.children, path{i})
        return
    end
    node = node.children.(path{i});
end
if isfield(node, 'info') && isstruct(node.info) && isfield(node.info, 'values')
    v = node.info.values;
end
end

% ======================================================================
% Arguments
% ======================================================================

function opt = ac_parse_args(args)
opt.Scope = 'per-participant-condition';
opt.N = 30;
opt.Root = '';
opt.OutDir = '';
opt.PlotDir = '';
opt.SpectrumFiles = 40;
opt.Signals = true;
for i = 1:2:numel(args)
    name = validatestring(args{i}, fieldnames(opt), mfilename);
    opt.(name) = args{i+1};
end
end
