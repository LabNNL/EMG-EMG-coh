function make_spectrum_age_within_condition_figure(Tp, pairName, freqRef, C, HC, HS)
%MAKE_SPECTRUM_AGE_WITHIN_CONDITION_FIGURE
% 3 subplots: one condition per subplot.
% Within each subplot: plot age groups and run age-group SPM.
%
% Test:
%   age-group effect within one condition
%   between-subject SPM: anova1
%
% No condition averaging is needed because condition is fixed per subplot.

    if isempty(Tp)
        return;
    end

    ageLevelsAll  = cellstr(C.plotting.age_order);
    condLevelsAll = cellstr(C.plotting.condition_order);

    outDir = fullfile(HS.out_dir, 'followup_subplots');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    fig = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [100 100 1650 600]);

    tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

    axList = gobjects(numel(condLevelsAll), 1);
    axActive = false(numel(condLevelsAll), 1);
    spmInfoList = cell(numel(condLevelsAll), 1);
    spmTextList = strings(numel(condLevelsAll), 1);
    legendHandlesList = cell(numel(condLevelsAll), 1);
    legendLabelsList  = cell(numel(condLevelsAll), 1);

    % ===================== PASS 1: plot curves only =====================
    for ic = 1:numel(condLevelsAll)

        condName = condLevelsAll{ic};

        ax = nexttile(tl, ic);
        hold(ax, 'on');
        axList(ic) = ax;

        Tc = Tp(Tp.condition == condName, :);

        if isempty(Tc)
            axis(ax, 'off');
            text(ax, 0.5, 0.5, sprintf('%s\nNo data', condName), 'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Interpreter', 'none');
            continue;
        end

        axActive(ic) = true;

        ageLevels = keep_present_in_order(ageLevelsAll, categories(removecats(Tc.age_group)));

        [h, labels] = plot_mean_spectrum_by_group( ax, Tc, 'age_group', ageLevels, @(x)get_age_color(x,C), freqRef, HS);

        legendHandlesList{ic} = h;
        legendLabelsList{ic}  = labels;

        xlabel(ax, 'Frequency (Hz)');
        ylabel(ax, get_spectrum_ylabel_from_source(HS));
        title(ax, sprintf('%s | age effect', condName), 'Interpreter', 'none');

        grid(ax, 'on');
        xlim(ax, [HS.freq_min HS.freq_max]);

        % ---------- Compute SPM but do not draw yet ----------
        nSubj = numel(unique(Tc.subject));

        minN = 3;
        if isfield(HS, 'subplot_spm_min_subjects') && ~isempty(HS.subplot_spm_min_subjects)
            minN = HS.subplot_spm_min_subjects;
        end

        nAgeGroupsPresent = numel(ageLevels);

        spmInfo = [];
        if nAgeGroupsPresent >= 2 && nSubj >= minN
            spmInfo = run_spm_age_on_spectrum(Tc, ageLevels, freqRef, HS);
            txt = sprintf('SPM n=%d subjects', nSubj);
        else
            txt = sprintf('SPM skipped: n=%d', nSubj);
        end

        spmInfoList{ic} = spmInfo;
        spmTextList(ic) = txt;
    end

    % ===================== PASS 2: common ylim =====================
    yTopCommon = get_common_spectrum_ymax(axList(axActive), HS, HC);

    % ===================== PASS 3: add bars, text, local legends =====================
    for ic = 1:numel(condLevelsAll)

        ax = axList(ic);

        if ~axActive(ic) || ~isgraphics(ax, 'axes')
            continue;
        end

        ylim(ax, [0 yTopCommon]);

        spmInfo = spmInfoList{ic};

        if ~isempty(spmInfo) && isstruct(spmInfo) && isfield(spmInfo, 'spmi') && ~isempty(spmInfo.spmi)

            showStars = true;
            if isfield(HS, 'subplot_show_cluster_stars')
                showStars = HS.subplot_show_cluster_stars;
            end

            if showStars
                add_spm_significance_bars_frequency(ax, spmInfo.spmi, freqRef, 'y_frac', 0.78, 'line_width', 1.5, 'color', [0 0 0], 'show_stars', true);
            end
        end

        text(ax, 0.02, 0.955, spmTextList(ic), 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 9, 'BackgroundColor', 'w', 'Margin', 2, 'Interpreter', 'none');

        % local legend in each subplot
        h = legendHandlesList{ic};
        labels = legendLabelsList{ic};

        if ~isempty(h)
            lgd = legend(ax, h, labels, 'Location', 'northeast', 'Interpreter', 'none', 'Box', 'off');
            lgd.FontSize = 8;
        end

        % enforce identical limits after everything
        ylim(ax, [0 yTopCommon]);
    end

    sgtitle(fig, sprintf('%s | age effect within each condition | %s', string(pairName), get_pair_phase_text(pairName, C)), 'Interpreter', 'none');

    outFile = fullfile(outDir, sprintf( 'SPECTRUM_AGE_WITHIN_CONDITION__%s__%s__%s.png', char(string(pairName)), lower(char(string(HS.scope))), lower(char(string(HS.spectrum_source)))));

    saveas(fig, outFile);
    close(fig);
end