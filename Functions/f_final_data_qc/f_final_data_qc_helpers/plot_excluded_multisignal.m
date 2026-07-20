function plot_excluded_multisignal(P, subjID, cond, leg, entityName, outDir, C, varargin)
% Plot original signals with included/excluded cycles highlighted.
%
% GENERAL:
%   - works for any number of signals stored in P
%   - default expected fields:
%         P.original_signals  -> cell array, one vector per signal
%         P.signal_labels     -> cell array of names
%         P.cycle_keep_masks  -> cell array of logical vectors, one per signal
%   - if those fields do not exist, falls back to the legacy pair structure:
%         P.original_signal_1 / P.original_signal_2
%         P.muscles
%         P.muscle1_cycle_qc / P.muscle2_cycle_qc
%
% OPTIONAL NAME-VALUE:
%   'FileTag'        : string used in output filename
%   'FigureTitle'    : custom figure title
%   'TimeUnit'       : 's' (default)
%   'Visible'        : 'off' (default) or 'on'

    ip = inputParser;
    addParameter(ip, 'FileTag', 'excluded_entity', @(x)ischar(x) || isstring(x));
    addParameter(ip, 'FigureTitle', "", @(x)ischar(x) || isstring(x));
    addParameter(ip, 'TimeUnit', 's', @(x)ischar(x) || isstring(x));
    addParameter(ip, 'Visible', 'off', @(x)ischar(x) || isstring(x));
    parse(ip, varargin{:});
    OPT = ip.Results;

    fs = P.fs;
    cycle_starts = P.cycle_starts(:);
    cycle_ends   = P.cycle_ends(:);

    [signals, signalLabels, keepMasks, reasonLists] = get_multisignal_plot_inputs(P);

    nSig = numel(signals);
    if nSig == 0
        warning('plot_excluded_multisignal: no signals found.');
        return;
    end

    fig = figure( ...
        'Visible', char(string(OPT.Visible)), ...
        'Color', 'w', ...
        'Position', [100 100 1700 max(500, 320*nSig)], ...
        'Toolbar', 'none', ...
        'MenuBar', 'none');

    tl = tiledlayout(nSig,1,'TileSpacing','compact','Padding','compact');

    colKeep = C.plotting.colors.include;
    colBad  = C.plotting.colors.exclude;
    cycleLineColor = [0.3 0.3 0.3];

    for iSig = 1:nSig
        x = signals{iSig}(:);
        t = (0:numel(x)-1)/fs;

        ax = nexttile(tl);
        hold(ax,'on');

        plot(ax, t, x, 'k', 'LineWidth', 0.8);
        yL = ylim(ax);

        thisKeep = keepMasks{iSig};
        thisReasons = reasonLists{iSig};

        for iC = 1:numel(cycle_starts)
            xStart = (cycle_starts(iC)-1)/fs;
            xEnd   = (cycle_ends(iC)-1)/fs;

            if thisKeep(iC)
                col = colKeep;
            else
                col = colBad;
            end

            patch(ax, ...
                [xStart xEnd xEnd xStart], ...
                [yL(1) yL(1) yL(2) yL(2)], ...
                col, ...
                'FaceAlpha', C.plotting.AlphaTransparency, ...
                'EdgeColor', 'none');
        end

        plot(ax, t, x, 'k', 'LineWidth', 0.8);

        for iC = 1:numel(cycle_starts)
            xc = (cycle_starts(iC)-1)/fs;
            xline(ax, xc, '--', 'Color', cycleLineColor, 'LineWidth', 0.8);
        end

        invalidIdx = find(~thisKeep);
        for k = 1:numel(invalidIdx)
            iC = invalidIdx(k);
            xc = (cycle_starts(iC)-1)/fs;

            if numel(thisReasons) >= iC
                reasonStr = short_cycle_reason(thisReasons(iC));
            else
                reasonStr = "excluded";
            end

            txt = sprintf('C%d: %s', iC, reasonStr);
            yText = yL(1) + 0.9 * (yL(2)-yL(1));

            text(ax, xc, yText, txt, ...
                'Rotation', 90, ...
                'VerticalAlignment','top', ...
                'HorizontalAlignment','center', ...
                'FontSize', 8, ...
                'FontWeight', 'bold');
        end

        title(ax, sprintf('%s | %s | %s | %s | %s', ...
            subjID, cond, leg, entityName, signalLabels{iSig}), ...
            'Interpreter','none');

        ylabel(ax, 'Amplitude');
        if iSig == nSig
            xlabel(ax, sprintf('Time (%s)', char(string(OPT.TimeUnit))));
        end
        grid(ax,'on');
    end

    if strlength(string(OPT.FigureTitle)) > 0
        figTitle = string(OPT.FigureTitle);
    else
        nValid = getfield_safe(P, 'n_valid_cycles', NaN);
        nTot   = getfield_safe(P, 'n_cycles_total', NaN);
        minReq = getfield_safe(P, 'min_cycles_required', NaN);
        excl   = string(getfield_safe(P, 'exclusion_reason', ""));

        figTitle = sprintf(['Excluded signal set | %s | %s | %s | %s\n' ...
            'Valid cycles: %d / %d | Min required: %d | Reason: %s'], ...
            subjID, cond, leg, entityName, ...
            nValid, nTot, minReq, excl);
    end

    sgtitle(figTitle, 'Interpreter','none');

    runTag = char(string(datetime('now','Format','yyyyMMdd_HHmmss')));
    fname = sprintf('%s__%s__%s__%s__%s__%s.png', ...
        char(string(OPT.FileTag)), subjID, cond, leg, entityName, runTag);

    fpath = fullfile(outDir, fname);

    if isgraphics(fig)
        exportgraphics(fig, fpath, 'Resolution', 150);
        close(fig);
    end
end


function [signals, signalLabels, keepMasks, reasonLists] = get_multisignal_plot_inputs(P)

    % Preferred new generic format
    if isfield(P, 'original_signals') && isfield(P, 'signal_labels') && isfield(P, 'cycle_keep_masks')
        signals = P.original_signals;
        signalLabels = P.signal_labels;
        keepMasks = P.cycle_keep_masks;

        if isfield(P, 'cycle_reason_lists')
            reasonLists = P.cycle_reason_lists;
        else
            reasonLists = cell(size(signals));
            for i = 1:numel(signals)
                reasonLists{i} = strings(numel(keepMasks{i}),1);
            end
        end
        return;
    end

    % Legacy pair fallback
    signals = {P.original_signal_1(:), P.original_signal_2(:)};
    signalLabels = P.muscles;
    keepMasks = {P.muscle1_cycle_qc.cycle_keep_mask(:), P.muscle2_cycle_qc.cycle_keep_mask(:)};
    reasonLists = {P.muscle1_cycle_qc.cycle_reason(:), P.muscle2_cycle_qc.cycle_reason(:)};
end
