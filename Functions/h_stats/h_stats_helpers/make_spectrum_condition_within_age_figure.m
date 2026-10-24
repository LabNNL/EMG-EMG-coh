function make_spectrum_condition_within_age_figure(Tp, pairName, freqRef, C, HC, HS)
%MAKE_SPECTRUM_CONDITION_WITHIN_AGE_FIGURE
% 4 subplots: one age group per subplot.
% Within each subplot: plot Plat/Medium/High and run condition SPM.
%
% Test:
%   condition effect within one age group
%   repeated-measures SPM: anova1rm
%
% Requires complete-case subjects across conditions within each age group.

    if isempty(Tp)
        return;
    end

    ageLevelsAll  = cellstr(C.plotting.age_order);
    condLevelsAll = cellstr(C.plotting.condition_order);

    outDir = fullfile(HS.out_dir, 'followup_subplots');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    fig = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [100 100 1450 900]);

    tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    axList = gobjects(numel(ageLevelsAll), 1);
    axActive = false(numel(ageLevelsAll), 1);
    spmInfoList = cell(numel(ageLevelsAll), 1);
    spmTextList = strings(numel(ageLevelsAll), 1);
    legendHandlesList = cell(numel(ageLevelsAll), 1);
    legendLabelsList  = cell(numel(ageLevelsAll), 1);

    % ===================== PASS 1: plot curves only =====================
    for ia = 1:numel(ageLevelsAll)

        ag = ageLevelsAll{ia};

        ax = nexttile(tl, ia);
        hold(ax, 'on');
        axList(ia) = ax;

        Tag = Tp(Tp.age_group == ag, :);

        if isempty(Tag)
            axis(ax, 'off');
            text(ax, 0.5, 0.5, sprintf('%s\nNo data', ag), 'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Interpreter', 'none');
            continue;
        end

        axActive(ia) = true;

        condLevels = keep_present_in_order(condLevelsAll, categories(removecats(Tag.condition)));

        [h, labels] = plot_mean_spectrum_by_group( ax, Tag, 'condition', condLevels, @(x)get_condition_color(x,C), freqRef, HS);

        legendHandlesList{ia} = h;
        legendLabelsList{ia}  = labels;

        xlabel(ax, 'Frequency (Hz)');
        ylabel(ax, get_spectrum_ylabel_from_source(HS));
        title(ax, sprintf('%s | condition effect', ag), 'Interpreter', 'none');

        grid(ax, 'on');
        xlim(ax, [HS.freq_min HS.freq_max]);

        % ---------- Compute SPM but do not draw yet ----------
        Tag_cc = keep_only_complete_subjects_for_conditions(Tag, condLevels);
        nSubjCC = numel(unique(Tag_cc.subject));

        minN = 3;
        if isfield(HS, 'subplot_spm_min_subjects') && ~isempty(HS.subplot_spm_min_subjects)
            minN = HS.subplot_spm_min_subjects;
        end

        spmInfo = [];
        if numel(condLevels) >= 2 && nSubjCC >= minN
            spmInfo = run_spm_condition_on_spectrum(Tag_cc, condLevels, freqRef, HS);
            if spm_info_ok(spmInfo)
                txt = sprintf('SPM n=%d complete-case', nSubjCC);
            else
                % Never caption a test that did not run as though it ran:
                % a plot with no bars would otherwise read as a null result.
                txt = sprintf('SPM FAILED: n=%d complete-case', nSubjCC);
            end
        else
            txt = sprintf('SPM skipped: n=%d complete-case', nSubjCC);
        end

        spmInfoList{ia} = spmInfo;
        spmTextList(ia) = txt;
    end

    % ===================== PASS 2: common ylim =====================
    yTopCommon = get_common_spectrum_ymax(axList(axActive), HS, HC);

    % ===================== PASS 3: add bars, text, local legends =====================
    for ia = 1:numel(ageLevelsAll)

        ax = axList(ia);

        if ~axActive(ia) || ~isgraphics(ax, 'axes')
            continue;
        end

        ylim(ax, [0 yTopCommon]);

        spmInfo = spmInfoList{ia};

        if ~isempty(spmInfo) && isstruct(spmInfo) && isfield(spmInfo, 'spmi') && ~isempty(spmInfo.spmi)

            showStars = true;
            if isfield(HS, 'subplot_show_cluster_stars')
                showStars = HS.subplot_show_cluster_stars;
            end

            if showStars
                add_spm_significance_bars_frequency(ax, spmInfo.spmi, freqRef, 'y_frac', 0.78, 'line_width', 1.5, 'color', [0 0 0], 'show_stars', true);
            end
        end

        text(ax, 0.02, 0.955, spmTextList(ia), 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 9, 'BackgroundColor', 'w', 'Margin', 2, 'Interpreter', 'none');

        % local legend in each subplot
        h = legendHandlesList{ia};
        labels = legendLabelsList{ia};

        if ~isempty(h)
            lgd = legend(ax, h, labels, 'Location', 'northeast', 'Interpreter', 'none', 'Box', 'off');
            lgd.FontSize = 8;
        end

        % enforce identical limits after everything
        ylim(ax, [0 yTopCommon]);
    end

    sgtitle(fig, sprintf('%s | condition effect within each age group | %s', string(pairName), get_pair_phase_text(pairName, C)), 'Interpreter', 'none');

    outFile = fullfile(outDir, sprintf( 'SPECTRUM_CONDITION_WITHIN_AGE__%s__%s__%s.png', char(string(pairName)), lower(char(string(HS.scope))), lower(char(string(HS.spectrum_source)))));

    saveas(fig, outFile);
    close(fig);
end