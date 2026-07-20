%% diagnostic_plot_heel_marker_axes.m
% Visual check of Vicon marker axes using heel trajectories.
%
% Goal:
%   Inspect X/Y/Z evolution of the heel marker over the exact gait cycles
%   used for coherence, or over all raw extracted cycles.
%
% Put this script at the root of EMG_GAIT_ANALYSIS and run it after script a_
% and preferably after script f_ if you want coherence-kept cycles only.

clc; close all;

C = config_emg();
addpath(genpath(fullfile(C.paths.code_dir, 'Functions')));

%% ===================== USER SETTINGS =====================
subjID = 'CTL_01';
leg = 'left';                      % 'left' or 'right'
pairName = 'TAprox_TAdist';         % 'TAprox_TAdist' or 'SOL_GM'
band = 'OVERALL';                  % 'OVERALL', 'Alpha', 'Beta', 'Gamma'
conditions_to_plot = {'Flat','Medium','High'};

use_coherence_kept_cycles = true;   % true = exact cycles used in coherence after f_
max_cycles_to_plot = 25;            % avoid unreadable spaghetti plots
center_each_cycle = true;           % true = show each cycle relative to its own HS position
plot_raw_trial_trace = true;        % plot full trial trajectories with selected cycle boundaries
plot_3d_path = true;                % plot X/Y/Z path for selected cycles

% Marker units from BTK/Vicon are commonly mm. Keep mm for axis diagnostics.
marker_units_label = 'mm';

out_dir = fullfile(C.kinematics_coherence.io.out_dir , 'heel_marker_axis_diagnostics');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

%% ===================== LOAD DATA =====================
raw_file = fullfile(C.paths.raw_dir, sprintf('%s_RAW_CYCLES_CONCAT.mat', subjID));
assert(isfile(raw_file), 'Raw cycle file not found: %s', raw_file);
R = load(raw_file, 'CYCLES_SIGNAL_RAW', 'RAW_MARKERS');
assert(isfield(R, 'CYCLES_SIGNAL_RAW') && isfield(R, 'RAW_MARKERS'), ...
    'File must contain CYCLES_SIGNAL_RAW and RAW_MARKERS.');

FPS = struct();
if use_coherence_kept_cycles
    final_file = C.f_final_signals.io.out_mat;
    assert(isfile(final_file), 'FINAL_PAIRED_SIGNALS not found: %s', final_file);
    L = load(final_file, 'FINAL_PAIRED_SIGNALS');
    FPS = L.FINAL_PAIRED_SIGNALS;
end

all_summary_rows = {};
ri = 0;

%% ===================== MAIN LOOP =====================
for iCond = 1:numel(conditions_to_plot)
    cond = conditions_to_plot{iCond};

    fprintf('\n=== %s | %s | %s | %s | %s ===\n', subjID, cond, leg, pairName, band);

    rawEntry = get_raw_cycle_entry_for_pair(R.CYCLES_SIGNAL_RAW, subjID, cond, leg, pairName);
    if isempty(rawEntry)
        warning('No raw cycle metadata found for %s | %s | %s | %s', subjID, cond, leg, pairName);
        continue;
    end

    if use_coherence_kept_cycles
        keepCycles = get_kept_cycles_from_final(FPS, subjID, cond, leg, pairName, band);
    else
        keepCycles = 1:numel(rawEntry.orig_start);
    end

    keepCycles = keepCycles(:)';
    keepCycles = keepCycles(keepCycles <= numel(rawEntry.orig_start));

    if isempty(keepCycles)
        warning('No cycles selected for %s | %s | %s | %s | %s', subjID, cond, leg, pairName, band);
        continue;
    end

    % Downsample cycles only for plotting. Summaries below are computed on the plotted subset,
    % because the goal here is visual diagnosis, not statistical analysis.
    if numel(keepCycles) > max_cycles_to_plot
        idx = round(linspace(1, numel(keepCycles), max_cycles_to_plot));
        plotCycles = keepCycles(idx);
    else
        plotCycles = keepCycles;
    end

    fsEmg = get_fs_emg_default(C);
    contraLeg = opposite_leg(leg);

    cycleData = struct([]);
    ci = 0;

    for c = plotCycles
        trialID = string(rawEntry.trial_id{c});
        i0 = double(rawEntry.orig_start(c));
        i1 = double(rawEntry.orig_end(c));

        Mipsi = get_marker_trial_struct(R.RAW_MARKERS, subjID, cond, leg, trialID);
        Mcontra = get_marker_trial_struct(R.RAW_MARKERS, subjID, cond, contraLeg, trialID);

        if isempty(Mipsi) || ~isfield(Mipsi, 'heel_xyz') || isempty(Mipsi.heel_xyz)
            fprintf('  Skip cycle %d trial %s: ipsilateral heel missing.\n', c, trialID);
            continue;
        end

        fsMarker = get_marker_fs(Mipsi, C);
        f0 = analog_sample_to_marker_frame(i0, fsEmg, fsMarker);
        f1 = analog_sample_to_marker_frame(i1, fsEmg, fsMarker);

        heel = double(Mipsi.heel_xyz);
        if f1 > size(heel,1) || f0 < 1 || f1 <= f0
            fprintf('  Skip cycle %d trial %s: marker frame bounds invalid.\n', c, trialID);
            continue;
        end

        seg = heel(f0:f1, 1:3);
        if any(isnan(seg(:)))
            fprintf('  Cycle %d trial %s contains NaNs in heel trajectory. Keeping for plot.\n', c, trialID);
        end

        interheel = [NaN NaN NaN];
        if ~isempty(Mcontra) && isfield(Mcontra, 'heel_xyz') && ~isempty(Mcontra.heel_xyz)
            heelContra = double(Mcontra.heel_xyz);
            if f0 <= size(heelContra,1)
                interheel = heel(f0,1:3) - heelContra(f0,1:3);
            end
        end

        ci = ci + 1;
        cycleData(ci).cycle_number = c;
        cycleData(ci).trial_id = trialID;
        cycleData(ci).orig_start = i0;
        cycleData(ci).orig_end = i1;
        cycleData(ci).frame_start = f0;
        cycleData(ci).frame_end = f1;
        cycleData(ci).fs_marker = fsMarker;
        cycleData(ci).heel_xyz = seg;
        cycleData(ci).heel_start = seg(1,:);
        cycleData(ci).heel_end = seg(end,:);
        cycleData(ci).start_to_end_delta = seg(end,:) - seg(1,:);
        cycleData(ci).within_cycle_range = max(seg,[],1,'omitnan') - min(seg,[],1,'omitnan');
        cycleData(ci).interheel_at_ipsi_hs = interheel;
    end

    if isempty(cycleData)
        warning('No plottable cycles for %s | %s | %s', subjID, cond, leg);
        continue;
    end

    nPlot = numel(cycleData);
    axisNames = {'X','Y','Z'};

    % Print diagnostic summary to command window.
    deltas = vertcat(cycleData.start_to_end_delta);
    ranges = vertcat(cycleData.within_cycle_range);
    interheel = vertcat(cycleData.interheel_at_ipsi_hs);

    fprintf('Plotted cycles: %d / selected cycles: %d\n', nPlot, numel(keepCycles));
    fprintf('Axis diagnostics in %s:\n', marker_units_label);
    fprintf('  Axis | median HS-to-next-HS delta | median within-cycle range | median abs inter-heel at ipsi HS\n');
    for ax = 1:3
        fprintf('   %s   | %9.2f                  | %9.2f                 | %9.2f\n', ...
            axisNames{ax}, ...
            median(deltas(:,ax), 'omitnan'), ...
            median(ranges(:,ax), 'omitnan'), ...
            median(abs(interheel(:,ax)), 'omitnan'));

        ri = ri + 1;
        all_summary_rows(ri,:) = {string(subjID), string(cond), string(leg), string(pairName), ...
            string(band), string(axisNames{ax}), nPlot, ...
            median(deltas(:,ax),'omitnan'), median(ranges(:,ax),'omitnan'), ...
            median(abs(interheel(:,ax)),'omitnan')}; %#ok<SAGROW>
    end

    %% ---------- FIGURE 1: normalized cycles, axis by axis ----------
    fig = figure('Color','w', 'Position', [100 100 1300 850]);
    tiledlayout(3,1, 'TileSpacing','compact', 'Padding','compact');

    for ax = 1:3
        nexttile; hold on;

        for k = 1:nPlot
            seg = cycleData(k).heel_xyz;
            if center_each_cycle
                seg = seg - seg(1,:);
            end

            xOld = linspace(0, 100, size(seg,1));
            xNew = linspace(0, 100, 201);
            yNew = interp1(xOld, seg(:,ax), xNew, 'linear', 'extrap');
            plot(xNew, yNew, 'LineWidth', 1.0);
        end

        yline(0, ':');
        xlabel('Gait cycle (%)');
        if center_each_cycle
            ylabel(sprintf('%s heel %s - value at HS (%s)', leg, axisNames{ax}, marker_units_label));
        else
            ylabel(sprintf('%s heel %s (%s)', leg, axisNames{ax}, marker_units_label));
        end
        title(sprintf('%s axis', axisNames{ax}));
        grid on;
    end

    sgtitle(sprintf('%s | %s | %s heel | %s | %s | n cycles=%d', ...
        subjID, cond, leg, pairName, band, nPlot), 'Interpreter','none');

    fname1 = fullfile(out_dir, sprintf('%s_%s_%s_%s_%s_normalized_axes.png', ...
        subjID, cond, leg, pairName, band));
    exportgraphics(fig, fname1, 'Resolution', 200);

    %% ---------- FIGURE 2: raw trial traces with cycle windows ----------
    if plot_raw_trial_trace
        uniqueTrials = unique(string({cycleData.trial_id}));
        for it = 1:numel(uniqueTrials)
            trialID = uniqueTrials(it);
            Mtrial = get_marker_trial_struct(R.RAW_MARKERS, subjID, cond, leg, trialID);
            if isempty(Mtrial) || ~isfield(Mtrial, 'heel_xyz') || isempty(Mtrial.heel_xyz)
                continue;
            end

            heelTrial = double(Mtrial.heel_xyz(:,1:3));
            fsMarker = get_marker_fs(Mtrial, C);
            t = (0:size(heelTrial,1)-1) / fsMarker;

            fig2 = figure('Color','w', 'Position', [100 100 1300 850]);
            tiledlayout(3,1, 'TileSpacing','compact', 'Padding','compact');

            for ax = 1:3
                nexttile; hold on;
                plot(t, heelTrial(:,ax), 'k-', 'LineWidth', 1.0);

                for k = 1:nPlot
                    if string(cycleData(k).trial_id) ~= trialID
                        continue;
                    end
                    t0 = (cycleData(k).frame_start - 1) / fsMarker;
                    t1 = (cycleData(k).frame_end - 1) / fsMarker;
                    xline(t0, '-', 'LineWidth', 0.8);
                    xline(t1, ':', 'LineWidth', 0.8);
                end

                xlabel('Time in C3D trial (s)');
                ylabel(sprintf('%s heel %s (%s)', leg, axisNames{ax}, marker_units_label));
                title(sprintf('%s axis', axisNames{ax}));
                grid on;
            end

            sgtitle(sprintf('%s | %s | trial %s | %s heel raw marker traces | selected cycles marked', ...
                subjID, cond, trialID, leg), 'Interpreter','none');

            fname2 = fullfile(out_dir, sprintf('%s_%s_%s_trial_%s_%s_raw_trace_axes.png', ...
                subjID, cond, leg, trialID, band));
            exportgraphics(fig2, fname2, 'Resolution', 200);
        end
    end

    %% ---------- FIGURE 3: 3D heel path ----------
    if plot_3d_path
        fig3 = figure('Color','w', 'Position', [100 100 900 800]);
        hold on;
        for k = 1:nPlot
            seg = cycleData(k).heel_xyz;
            if center_each_cycle
                seg = seg - seg(1,:);
            end
            plot3(seg(:,1), seg(:,2), seg(:,3), 'LineWidth', 1.0);
            scatter3(seg(1,1), seg(1,2), seg(1,3), 30, 'filled');
        end
        xlabel(sprintf('X (%s)', marker_units_label));
        ylabel(sprintf('Y (%s)', marker_units_label));
        zlabel(sprintf('Z (%s)', marker_units_label));
        title(sprintf('%s | %s | %s heel 3D path | %s | %s', subjID, cond, leg, pairName, band), ...
            'Interpreter','none');
        grid on; axis equal; view(3);

        fname3 = fullfile(out_dir, sprintf('%s_%s_%s_%s_%s_3d_heel_path.png', ...
            subjID, cond, leg, pairName, band));
        exportgraphics(fig3, fname3, 'Resolution', 200);
    end
end

%% ===================== SAVE SUMMARY TABLE =====================
if ~isempty(all_summary_rows)
    AXIS_DIAGNOSTIC_SUMMARY = cell2table(all_summary_rows, 'VariableNames', { ...
        'subject','condition','leg','pair_name','band','axis','n_cycles_plotted', ...
        'median_hs_to_next_hs_delta', ...
        'median_within_cycle_range', ...
        'median_abs_interheel_at_ipsi_hs'});

    out_xlsx = fullfile(out_dir, sprintf('%s_%s_%s_%s_AXIS_DIAGNOSTIC_SUMMARY.xlsx', ...
        subjID, leg, pairName, band));
    writetable(AXIS_DIAGNOSTIC_SUMMARY, out_xlsx);
    fprintf('\nSaved summary table:\n  %s\n', out_xlsx);
end

fprintf('\nFigures saved in:\n  %s\n', out_dir);

%% ===================== LOCAL FUNCTIONS =====================
function rawEntry = get_raw_cycle_entry_for_pair(CYCLES_SIGNAL_RAW, subjID, cond, leg, pairName)
    rawEntry = [];
    if ~isfield(CYCLES_SIGNAL_RAW, subjID) || ...
       ~isfield(CYCLES_SIGNAL_RAW.(subjID), cond) || ...
       ~isfield(CYCLES_SIGNAL_RAW.(subjID).(cond), leg)
        return;
    end

    switch string(pairName)
        case "TAprox_TAdist"
            candidates = {'EMG_TAprox_Concat','EMG_TAdist_Concat'};
        case "SOL_GM"
            candidates = {'EMG_SOL_Concat','EMG_GM_Concat'};
        otherwise
            candidates = fieldnames(CYCLES_SIGNAL_RAW.(subjID).(cond).(leg));
    end

    for i = 1:numel(candidates)
        f = candidates{i};
        if isfield(CYCLES_SIGNAL_RAW.(subjID).(cond).(leg), f)
            E = CYCLES_SIGNAL_RAW.(subjID).(cond).(leg).(f);
            if isfield(E, 'orig_start') && isfield(E, 'orig_end') && isfield(E, 'trial_id')
                rawEntry = E;
                return;
            end
        end
    end
end

function keepCycles = get_kept_cycles_from_final(FPS, subjID, cond, leg, pairName, band)
    keepCycles = [];
    if ~isfield(FPS, subjID) || ~isfield(FPS.(subjID), cond) || ...
       ~isfield(FPS.(subjID).(cond), leg) || ~isfield(FPS.(subjID).(cond).(leg), pairName)
        return;
    end

    P = FPS.(subjID).(cond).(leg).(pairName);

    if strcmpi(band, 'OVERALL')
        if isfield(P, 'pair_cycle_keep_mask')
            keepCycles = find(P.pair_cycle_keep_mask(:));
        end
    else
        if isfield(P, 'band_specific') && isfield(P.band_specific, band) && ...
           isfield(P.band_specific.(band), 'pair_cycle_keep_mask')
            keepCycles = find(P.band_specific.(band).pair_cycle_keep_mask(:));
        end
    end
end

function M = get_marker_trial_struct(RAW_MARKERS, subjID, cond, leg, trialID)
    M = [];
    if ~isfield(RAW_MARKERS, subjID) || ~isfield(RAW_MARKERS.(subjID), cond) || ...
       ~isfield(RAW_MARKERS.(subjID).(cond), leg)
        return;
    end

    root = RAW_MARKERS.(subjID).(cond).(leg);
    trialField = matlab.lang.makeValidName(sprintf('trial_%s', char(trialID)));

    if isfield(root, trialField)
        M = root.(trialField);
        return;
    end

    % Fallbacks in case trial fields were saved with a slightly different convention.
    candidates = unique([string(trialID), "trial_" + string(trialID), "Trial_" + string(trialID), ...
        "trial" + string(trialID), "Trial" + string(trialID)]);
    for i = 1:numel(candidates)
        f = matlab.lang.makeValidName(char(candidates(i)));
        if isfield(root, f)
            M = root.(f);
            return;
        end
    end
end

function fs = get_marker_fs(M, C)
    if isfield(M, 'fs_marker') && ~isempty(M.fs_marker)
        fs = double(M.fs_marker(1));
    else
        fs = double(C.general.fs_vicon);
    end
end

function fs = get_fs_emg_default(C)
    if isfield(C, 'general') && isfield(C.general, 'fs_emg')
        fs = double(C.general.fs_emg);
    else
        fs = 2000;
    end
end

function frame = analog_sample_to_marker_frame(sampleIdx, fsAnalog, fsMarker)
    frame = round((double(sampleIdx) - 1) / double(fsAnalog) * double(fsMarker)) + 1;
    frame = max(1, frame);
end

function other = opposite_leg(leg)
    if strcmpi(leg, 'left')
        other = 'right';
    else
        other = 'left';
    end
end
