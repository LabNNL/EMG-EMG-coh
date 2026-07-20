function plot_original_vs_rebuilt_multisignal(P, subjID, cond, leg, entityName, outDir, C, varargin)
% Plot original vs rebuilt signals for any number of channels/signals.
%
% GENERAL:
%   - default expected fields:
%         P.original_signals
%         P.rebuilt_signals
%         P.signal_labels
%         P.pair_cycle_keep_mask (or custom keep mask passed in)
%         P.final_cycle_segments_table
%
%   - legacy pair structure is also supported automatically.
%
% OPTIONAL NAME-VALUE:
%   'FileTag'        : output prefix
%   'FigureTitle'    : custom title
%   'Visible'        : 'off' or 'on'
%   'CenterRebuilt'  : true/false (default true)

    ip = inputParser;
    addParameter(ip, 'FileTag', 'rebuilt_entity', @(x)ischar(x) || isstring(x));
    addParameter(ip, 'FigureTitle', "", @(x)ischar(x) || isstring(x));
    addParameter(ip, 'Visible', 'off', @(x)ischar(x) || isstring(x));
    addParameter(ip, 'CenterRebuilt', true, @(x)islogical(x) || isnumeric(x));
    parse(ip, varargin{:});
    OPT = ip.Results;

    fs = P.fs;
    colExcluded = C.plotting.colors.exclude;

    [origSignals, rebuiltSignals, signalLabels] = get_original_and_rebuilt_signals(P);

    nSig = numel(origSignals);
    if nSig == 0
        warning('plot_original_vs_rebuilt_multisignal: no signals found.');
        return;
    end

    cycStarts = P.cycle_starts(:);
    cycEnds   = P.cycle_ends(:);
    pairKeep  = P.pair_cycle_keep_mask(:);

    if isfield(P, 'final_cycle_segments_table') && ~isempty(P.final_cycle_segments_table)
        Tseg = P.final_cycle_segments_table;
    else
        Tseg = table();
    end

    if OPT.CenterRebuilt
        for iSig = 1:nSig
            if ~isempty(rebuiltSignals{iSig})
                rebuiltSignals{iSig} = rebuiltSignals{iSig} - mean(rebuiltSignals{iSig}, 'omitnan');
            end
        end
    end

    fig = figure( ...
        'Color','w', ...
        'Position',[100 100 1800 max(650, 260*nSig)], ...
        'Visible', char(string(OPT.Visible)), ...
        'Toolbar','none', ...
        'MenuBar','none');

    tl = tiledlayout(nSig, 2, 'TileSpacing','compact', 'Padding','compact');

    for iSig = 1:nSig
        xOrig = origSignals{iSig}(:);
        xNew  = rebuiltSignals{iSig}(:);

        tOrig = (0:numel(xOrig)-1)/fs;
        tNew  = (0:numel(xNew)-1)/fs;

        yAll = [xOrig; xNew];
        if isempty(yAll), yAll = [0;1]; end
        yL = [min(yAll,[],'omitnan'), max(yAll,[],'omitnan')];
        if yL(1) == yL(2), yL = yL + [-1 1]; end

        % ---------- ORIGINAL ----------
        ax1 = nexttile(tl); hold(ax1,'on');

        for iC = 1:numel(pairKeep)
            if ~pairKeep(iC)
                xStart = (cycStarts(iC)-1)/fs;
                xEnd   = (cycEnds(iC)-1)/fs;

                patch(ax1, [xStart xEnd xEnd xStart], [yL(1) yL(1) yL(2) yL(2)], ...
                    colExcluded, ...
                    'FaceAlpha', C.plotting.AlphaTransparency, ...
                    'EdgeColor', 'none');
            end
        end

        plot(ax1, tOrig, xOrig, 'k', 'LineWidth', 0.8);

        for iC = 1:numel(pairKeep)
            if ~pairKeep(iC)
                xStart = (cycStarts(iC)-1)/fs;
                xEnd   = (cycEnds(iC)-1)/fs;
                xline(ax1, xStart, '-', 'LineWidth', 1.5);
                xline(ax1, xEnd,   '-', 'LineWidth', 1.5);
            end
        end

        ylim(ax1, yL);
        title(ax1, sprintf('%s | original', signalLabels{iSig}), 'Interpreter','none');
        ylabel(ax1, 'Amplitude');
        grid(ax1,'on');

        % ---------- REBUILT ----------
        ax2 = nexttile(tl); hold(ax2,'on');
        plot(ax2, tNew, xNew, 'k', 'LineWidth', 0.8);

        if ~isempty(Tseg) && height(Tseg) >= 2
            startVar = sprintf('final_concat_start_idx_signal%d', iSig);
            if ismember(startVar, Tseg.Properties.VariableNames)
                for i = 2:height(Tseg)
                    prevCycle = Tseg.cycle_number(i-1);
                    currCycle = Tseg.cycle_number(i);

                    if currCycle > prevCycle + 1
                        xCutNew = (Tseg.(startVar)(i)-1)/fs;
                        xline(ax2, xCutNew, '--', 'LineWidth', 1.8);
                    end
                end
            end
        end

        ylim(ax2, yL);
        title(ax2, sprintf('%s | rebuilt', signalLabels{iSig}), 'Interpreter','none');
        xlabel(ax2, 'Time (s)');
        ylabel(ax2, 'Amplitude');
        grid(ax2,'on');
    end

    if strlength(string(OPT.FigureTitle)) > 0
        figTitle = string(OPT.FigureTitle);
    else
        nValid = getfield_safe(P, 'n_valid_cycles', NaN);
        nTot   = getfield_safe(P, 'n_cycles_total', NaN);
        figTitle = sprintf('%s | %s | %s | %s | valid cycles %d / %d', ...
            subjID, cond, leg, entityName, nValid, nTot);
    end

    sgtitle(figTitle, 'Interpreter','none');

    fname = sprintf('%s__%s__%s__%s__%s.png', ...
        char(string(OPT.FileTag)), subjID, cond, leg, entityName);
    fpath = fullfile(outDir, fname);

    axs = findall(fig, 'Type', 'axes');
    for ia = 1:numel(axs)
        try
            axs(ia).Toolbar.Visible = 'off';
        catch
        end
    end

    exportgraphics(fig, fpath, 'Resolution', 200);
    close(fig);
end

function [origSignals, rebuiltSignals, signalLabels] = get_original_and_rebuilt_signals(P)

    % Preferred new generic format
    if isfield(P, 'original_signals') && isfield(P, 'rebuilt_signals') && isfield(P, 'signal_labels')
        origSignals = P.original_signals;
        rebuiltSignals = P.rebuilt_signals;
        signalLabels = P.signal_labels;
        return;
    end

    % Legacy pair fallback
    origSignals = {P.original_signal_1(:), P.original_signal_2(:)};
    rebuiltSignals = {P.final_concatenated_signal_1(:), P.final_concatenated_signal_2(:)};
    signalLabels = P.muscles;
end