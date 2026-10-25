function h_spectrum_curves_and_spm(COH_DEFAULT, allCoh, subjects, C, HC)
% H_SPECTRUM_CURVES_AND_SPM  POI-averaged coherence spectra per participant, mean
% curves, and SPM / SnPM tests of age, condition, age x condition and the
% Bonferroni-corrected follow-ups. Runs when HC.spectrum.enable.

    %% ===================== SPECTRUM CURVE PLOTS + OPTIONAL SPM =====================

    HS = HC.spectrum;

    if HS.enable

        fprintf('\nGenerating coherence spectrum plots...\n');

        if ~exist(HS.out_dir, 'dir'), mkdir(HS.out_dir); end
        if ~exist(HS.tables_dir, 'dir'), mkdir(HS.tables_dir); end

        % add spm1d if available and requested
        if (HS.run_spm_age || HS.run_spm_condition) && isfield(C.paths, 'toolboxes') && isfield(C.paths.toolboxes, 'spm1d')
            if exist(C.paths.toolboxes.spm1d, 'dir')
                addpath(genpath(C.paths.toolboxes.spm1d));
            else
                warning('SPM1D folder not found: %s', C.paths.toolboxes.spm1d);
            end
        end

        % ===================== BUILD SPECTRUM TABLE DIRECTLY FROM FULL DATASET =====================

        SPEC_ROWS = {};
        riS = 0;
        nSkippedFreq = 0;

        subjects_spec = subjects;   % union over all sources, built for the row table

        for iS = 1:numel(subjects_spec)
            subjID = subjects_spec{iS};
            age_group = subject_to_group(subjID, C);

            conds_spec = union_of_nested_fields(allCoh, {subjID});
            for ic = 1:numel(conds_spec)
                cond = conds_spec{ic};

                legs_spec = union_of_nested_fields(allCoh, {subjID, cond});
                for il = 1:numel(legs_spec)
                    leg = legs_spec{il};

                    pairNames_spec = union_of_nested_fields(allCoh, {subjID, cond, leg});
                    fprintf('Processing subject %s | condition %s | leg %s | pairs: %s\n', subjID, cond, leg, strjoin(pairNames_spec, ', '));
                    for ip = 1:numel(pairNames_spec)
                        pairName = pairNames_spec{ip};

                        if ~ismember(string(pairName), string(HC.analysis.pairs_to_analyze))
                            continue;
                        end

                        R = get_nested_result(COH_DEFAULT, subjID, cond, leg, pairName);

                        if isempty(R)
                            continue;
                        end

                        CohMap = get_coherence_map_for_source(R, HS.spectrum_source);
                        if isempty(CohMap) || ~isfield(R, 'Freq') || isempty(R.Freq)
                            continue;
                        end

                        % minimum cycle requirement
                        nCycles = get_field_or_nan(R, 'n_cycles_used');
                        if isnan(nCycles) || nCycles < HC.analysis.min_cycles_required
                            continue;
                        end

                        % choose time window
                        usePOI = isfield(HC.analysis, 'metric_scope') && strcmpi(string(HC.analysis.metric_scope), "POI");

                        if usePOI
                            if ~result_has_poi(R)
                                continue;
                            end
                            timeIdx = get_poi_indices(R);
                        else
                            timeIdx = 1:size(CohMap, 2);
                        end

                        if isempty(timeIdx)
                            continue;
                        end
                        spec = mean(CohMap(:, timeIdx), 2, 'omitnan');

                        freq = R.Freq(:);

                        % remove NaNs consistently
                        keep = isfinite(freq) & isfinite(spec);
                        freq = freq(keep);
                        spec = spec(keep);

                        if isempty(freq) || isempty(spec)
                            continue;
                        end

                        fkeep = freq >= HC.analysis.spectrum_freq_range(1) & freq <= HC.analysis.spectrum_freq_range(2);
                        freq = freq(fkeep);
                        spec = spec(fkeep);

                        if isempty(freq) || isempty(spec)
                            continue;
                        end

                        % force ascending frequency axis
                        [freq, sortIdx] = sort(freq, 'ascend');
                        spec = spec(sortIdx);

                        riS = riS + 1;
                        SPEC_ROWS(riS,:) = { categorical(string(subjID)), categorical(string(age_group), C.plotting.age_order, C.plotting.age_order, 'Ordinal', true), categorical(string(cond), C.plotting.condition_order, C.plotting.condition_order, 'Ordinal', true), categorical(string(leg), C.design.legs, C.design.legs, 'Ordinal', true), categorical(string(pairName), HC.analysis.pairs_to_analyze, HC.analysis.pairs_to_analyze, 'Ordinal', true), nCycles, {freq(:)'}, {spec(:)'} };
                    end
                end
            end
        end

        if isempty(SPEC_ROWS)
            warning('No spectrum rows could be built from COH_DEFAULT. Skipping spectrum plots.');
        else

            T_spec_row = cell2table(SPEC_ROWS, 'VariableNames', { 'subject','age_group','condition','leg','pair_name','n_cycles_used','Freq','Spectrum'});
            fprintf('Row-level spectrum table: %d rows\n', height(T_spec_row));
            fprintf('\n=== Spectrum width diagnostics ===\n');

            specWidths = cellfun(@numel, T_spec_row.Spectrum);
            freqWidths = cellfun(@numel, T_spec_row.Freq);

            fprintf('Unique spectrum widths:\n');
            disp(unique(specWidths));

            fprintf('Unique frequency widths:\n');
            disp(unique(freqWidths));

            Tdiag = table( string(T_spec_row.subject), string(T_spec_row.condition), string(T_spec_row.leg), string(T_spec_row.pair_name), specWidths, freqWidths, 'VariableNames', { 'subject','condition','leg','pair','specWidth','freqWidth'});

            disp(head(Tdiag,30))

            T_spec_row.subject   = categorical(string(T_spec_row.subject));
            T_spec_row.age_group = categorical(string(T_spec_row.age_group), C.plotting.age_order, C.plotting.age_order, 'Ordinal', true);
            T_spec_row.condition = categorical(string(T_spec_row.condition), C.plotting.condition_order, C.plotting.condition_order, 'Ordinal', true);
            T_spec_row.leg       = categorical(string(T_spec_row.leg), C.design.legs, C.design.legs, 'Ordinal', true);
            T_spec_row.pair_name = categorical(string(T_spec_row.pair_name), HC.analysis.pairs_to_analyze, HC.analysis.pairs_to_analyze, 'Ordinal', true);

            T_spec_row = T_spec_row(~isundefined(T_spec_row.age_group) & ~isundefined(T_spec_row.condition) & ~isundefined(T_spec_row.pair_name), :);

            writetable(spectrum_table_to_flat_table(T_spec_row), fullfile(HS.tables_dir, 'T_spec_row_flat.csv'));

            % ---------------------------------------------------------
            % Average left/right legs within subject x age_group x condition x pair
            % ---------------------------------------------------------
            [T_spec_subj, freqRef] = average_spectrum_legs(T_spec_row);
            fprintf('\n=== CHECK SUBJECT-LEVEL SPECTRUM TABLE ===\n');

            disp(head(T_spec_subj(:, {'subject','condition','pair_name'})));

            fprintf('Rows in T_spec_subj: %d\n', height(T_spec_subj));

            nUnique = height(unique(T_spec_subj(:, {'subject','condition','pair_name'})));

            fprintf('Unique subject-condition-pair combinations: %d\n', nUnique);

            keyVars = {'subject','condition','pair_name'};
            nUnique = height(unique(T_spec_subj(:, keyVars)));

            if height(T_spec_subj) ~= nUnique
                warning('T_spec_subj has duplicate subject-condition-pair rows: %d rows vs %d unique keys.', height(T_spec_subj), nUnique);
            end
            %T_spec_subj = standardize_spectrum_table(T_spec_subj);

            writetable(spectrum_table_to_flat_table(T_spec_subj), fullfile(HS.tables_dir, 'T_spec_subject_flat.csv'));

            pairList = categories(removecats(T_spec_subj.pair_name));

            specWidths = nan(height(T_spec_subj),1);
            for i = 1:height(T_spec_subj)
                specWidths(i) = numel(T_spec_subj.Spectrum{i});
            end

            MIXED_SPM_ROWS = {};

            for ip = 1:numel(pairList)
                pairName = pairList{ip};
                Tp = T_spec_subj(T_spec_subj.pair_name == pairName, :);

                if isempty(Tp)
                    continue;
                end

                % complete-case subset for repeated-measures condition SPM
                Tp_cond_spm = keep_only_complete_subjects_for_conditions(Tp, C.plotting.condition_order);

                % ---------- CONDITION FIGURE ----------
                condLevels = keep_present_in_order(cellstr(C.plotting.condition_order), categories(removecats(Tp.condition)));

                showSPMsubplot = isfield(HS, 'show_spm_subplot') && HS.show_spm_subplot;

                if showSPMsubplot
                    fig1 = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [100 100 1000 850]);
                    ax1 = subplot(2,1,1);
                else
                    fig1 = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [100 100 1000 520]);
                    ax1 = axes(fig1);
                end

                pos = ax1.Position;
                pos(2) = pos(2) - 0.02;
                pos(4) = pos(4) - 0.03;
                ax1.Position = pos;

                hold(ax1, 'on');

                %[hCond, lCond] = plot_mean_spectrum_by_group(ax1, Tp, 'condition', condLevels, @(x)get_condition_color(x,C), freqRef);
                [hCond, lCond] = plot_mean_spectrum_by_group(ax1, Tp, 'condition', condLevels, @(x)get_condition_color(x,C), freqRef, HS);

                if isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "sig")
                    yLabelTxt = 'Significant coherence';
                    spectrumTxt = 'significant coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "equalized")
                    yLabelTxt = 'Equalized unthresholded coherence';
                    spectrumTxt = 'equalized unthresholded coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "sig_equalized")
                    yLabelTxt = 'Equalized significant coherence';
                    spectrumTxt = 'equalized significant coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "sig_common_threshold")
                    yLabelTxt = 'Significant coherence (common threshold subtracted)';
                    spectrumTxt = 'significant coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "zcoh_bokil")
                    yLabelTxt = 'Z-scored coherence (Bokil method)';
                    spectrumTxt = 'Z-scored coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "surrogate_delta")
                    yLabelTxt = 'Delta surrogate coherence';
                    spectrumTxt = 'Delta surrogate coherence spectrum';
                elseif isfield(HS, 'spectrum_source') && strcmpi(HS.spectrum_source, "cycle_bias_corrected")
                    yLabelTxt = 'Cycle-bias-corrected coherence';
                    spectrumTxt = 'Cycle-bias-corrected coherence spectrum';
                else
                    yLabelTxt = 'Raw coherence';
                    spectrumTxt = 'raw coherence spectrum';
                end
                xlabel(ax1, 'Frequency (Hz)');

                ylabel(ax1, yLabelTxt);
                % title(ax1, sprintf('%s | condition effect | %s %s', ...
                %     string(pairName), spectrumTxt, get_metric_scope_label(HS.scope)), ...
                %     'Interpreter','none');
                grid(ax1, 'on');
                xlim(ax1, [HS.freq_min HS.freq_max]);
                apply_shared_coherence_ylim(ax1, HC);

                if ~isempty(hCond)
                    legend(ax1, hCond, lCond, 'Location', 'best', 'Interpreter', 'none');
                end

                spmCondInfo = struct([]);
                topAxCond = ax1;

                if showSPMsubplot
                    ax2 = subplot(2,1,2);
                    hold(ax2, 'on');
                else
                    ax2 = [];
                end

                fprintf('\n=== CONDITION SPECTRUM COUNTS | %s ===\n', pairName);

                for ic = 1:numel(condLevels)
                    condName = condLevels{ic};
                    Ttmp = Tp(Tp.condition == condName, :);
                    fprintf('%s plot n = %d unique subjects\n', condName, numel(unique(Ttmp.subject)));
                end

                fprintf('Condition SPM complete-case n = %d unique subjects\n', numel(unique(Tp_cond_spm.subject)));

                if HS.run_spm_condition && ~isempty(Tp_cond_spm)

                    condLevels_spm = keep_present_in_order( cellstr(C.plotting.condition_order), categories(removecats(Tp_cond_spm.condition)));

                    if numel(condLevels_spm) >= 2

                        spmCondInfo = run_spm_condition_on_spectrum(Tp_cond_spm, condLevels_spm, freqRef, HS);

                        if isfield(spmCondInfo, 'spmi') && ~isempty(spmCondInfo.spmi)

                            if showSPMsubplot && isgraphics(ax2, 'axes')
                                axes(ax2); %#ok<LAXES>
                                spmCondInfo.spmi.plot();
                                spmCondInfo.spmi.plot_threshold_label();
                                spmCondInfo.spmi.plot_p_values();

                                xlabel(ax2, 'Frequency (Hz)');
                                ylabel(ax2, 'SPM{t} / SPM{F}');
                                title(ax2, 'SPM condition effect', 'Interpreter','none');
                                xlim(ax2, [HS.freq_min HS.freq_max]);

                            end

                            if HS.show_cluster_stars && isgraphics(topAxCond, 'axes')
                                axes(topAxCond); %#ok<LAXES>
                                add_spm_significance_bars_frequency(topAxCond, spmCondInfo.spmi, freqRef, 'y_frac', 0.85, 'line_width', 1.5, 'color', [0 0 0], 'show_stars', true);
                            end

                        elseif showSPMsubplot && isgraphics(ax2, 'axes')
                            cla(ax2);
                            axis(ax2, 'off');
                            text(0.5, 0.5, 'No SPM result available', 'Parent', ax2, 'HorizontalAlignment', 'center');
                        end
                    end

                elseif showSPMsubplot && isgraphics(ax2, 'axes')
                    cla(ax2);
                    axis(ax2, 'off');
                    text(0.5, 0.5, 'Condition SPM disabled or no complete-case data', 'Parent', ax2, 'HorizontalAlignment', 'center');
                end

                sgtitle(sprintf('%s | condition spectrum analysis | %s', string(pairName), get_pair_phase_text(pairName, C)), 'Interpreter','none');

                saveas(fig1, fullfile(HS.out_dir, sprintf('SPECTRUM_CONDITION_SPM__%s__%s__%s.png', char(string(pairName)), lower(char(string(HS.scope))), HS.spectrum_source)));
                close(fig1);

                % ---------- AGE FIGURE ----------
                % Collapse conditions first so each participant contributes only one curve.
                Tp_age = average_spectrum_conditions(Tp);

                fprintf('\n=== AGE SPECTRUM PARTICIPANT COUNTS | %s ===\n', pairName);
                disp(groupcounts_table(Tp_age, {'age_group'}));

                ageLevels = keep_present_in_order( cellstr(C.plotting.age_order), categories(removecats(Tp_age.age_group)));

                if showSPMsubplot
                    fig2 = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [100 100 1000 850]);
                    ax3 = subplot(2,1,1);
                else
                    fig2 = figure('Visible', HC.plot.visible, 'Color', 'w', 'Position', [100 100 1000 520]);
                    ax3 = axes(fig2);
                end

                pos = ax3.Position;
                pos(2) = pos(2) - 0.02;   % move plot down
                pos(4) = pos(4) - 0.03;   % slightly reduce height
                ax3.Position = pos;

                hold(ax3, 'on');

                %[hAge, lAge] = plot_mean_spectrum_by_group(ax3, Tp, 'age_group', ageLevels, @(x)get_age_color(x,C), freqRef);
                [hAge, lAge] = plot_mean_spectrum_by_group(ax3, Tp_age, 'age_group', ageLevels, @(x)get_age_color(x,C), freqRef, HS);

                xlabel(ax3, 'Frequency (Hz)');
                ylabel(ax3, yLabelTxt);
                % title(ax3, sprintf('%s | age effect | %s %s', ...
                %     string(pairName), spectrumTxt, get_metric_scope_label(HS.scope)), ...
                %     'Interpreter','none');
                grid(ax3, 'on');
                xlim(ax3, [HS.freq_min HS.freq_max]);
                apply_shared_coherence_ylim(ax3, HC);

                if ~isempty(hAge)
                    legend(ax3, hAge, lAge, 'Location', 'best', 'Interpreter', 'none');
                end

                spmAgeInfo = struct([]);
                topAxAge = ax3;

                if showSPMsubplot
                    ax4 = subplot(2,1,2);
                    hold(ax4, 'on');
                else
                    ax4 = [];
                end

                if HS.run_spm_age

                    spmAgeInfo = run_spm_age_on_spectrum(Tp_age, ageLevels, freqRef, HS);

                    if isfield(spmAgeInfo, 'spmi') && ~isempty(spmAgeInfo.spmi)

                        if showSPMsubplot && isgraphics(ax4, 'axes')
                            axes(ax4); %#ok<LAXES>
                            spmAgeInfo.spmi.plot();
                            spmAgeInfo.spmi.plot_threshold_label();
                            spmAgeInfo.spmi.plot_p_values();

                            xlabel(ax4, 'Frequency (Hz)');
                            ylabel(ax4, 'SPM{t} / SPM{F}');
                            title(ax4, 'SPM age effect', 'Interpreter','none');
                            xlim(ax4, [HS.freq_min HS.freq_max]);
                        end

                        if HS.show_cluster_stars && isgraphics(topAxAge, 'axes')
                            axes(topAxAge); %#ok<LAXES>
                            add_spm_significance_bars_frequency(topAxAge, spmAgeInfo.spmi, freqRef, 'y_frac', 0.85, 'line_width', 1.5, 'color', [0 0 0], 'show_stars', true);
                        end

                    elseif showSPMsubplot && isgraphics(ax4, 'axes')
                        cla(ax4);
                        axis(ax4, 'off');
                        text(0.5, 0.5, 'No SPM result available', 'Parent', ax4, 'HorizontalAlignment', 'center');
                    end

                elseif showSPMsubplot && isgraphics(ax4, 'axes')
                    cla(ax4);
                    axis(ax4, 'off');
                    text(0.5, 0.5, 'Age SPM disabled', 'Parent', ax4, 'HorizontalAlignment', 'center');
                end

                sgtitle(sprintf('%s | age spectrum analysis | %s', string(pairName), get_pair_phase_text(pairName, C)), 'Interpreter','none');

                saveas(fig2, fullfile(HS.out_dir, sprintf('SPECTRUM_AGE_SPM__%s__%s__%s.png', char(string(pairName)), lower(char(string(HS.scope))), HS.spectrum_source)));
                close(fig2);

                % ---------- EXTRA SPECTRUM FOLLOW-UP FIGURES ----------
                % 1) Condition effect within each age group: 4 subplots
                % 2) Age effect within each condition: 3 subplots

                if isfield(HS, 'make_followup_subplot_spm') && HS.make_followup_subplot_spm

                    fprintf('\nMaking follow-up spectrum figure (condition within age) for significant SPM effects | %s\n', pairName);

                    make_spectrum_condition_within_age_figure( Tp, pairName, freqRef, C, HC, HS);

                    fprintf('\nMaking follow-up spectrum figure (age within condition) for significant SPM effects | %s\n', pairName);

                    make_spectrum_age_within_condition_figure( Tp, pairName, freqRef, C, HC, HS);
                end


                % ---------- OPTIONAL: MIXED AGE-CONDITION SPM ----------
                if isfield(HS, 'run_spm_mixed_age_condition') && HS.run_spm_mixed_age_condition

                    ageLevels_mixed = keep_present_in_order( cellstr(C.plotting.age_order), categories(removecats(Tp.age_group)));

                    condLevels_mixed = keep_present_in_order( cellstr(C.plotting.condition_order), categories(removecats(Tp.condition)));

                    if numel(ageLevels_mixed) >= 2 && numel(condLevels_mixed) >= 2

                        spmMixedInfo = run_spm_mixed_age_condition_on_spectrum( Tp, ageLevels_mixed, condLevels_mixed, freqRef, HS);

                        if spmMixedInfo.ok
                            fprintf('\nMIXED SPM OK | %s\n', string(pairName));
                            fprintf('  n subjects = %d\n', spmMixedInfo.n_subjects);
                            fprintf('  n rows     = %d\n', spmMixedInfo.n_rows);

                            print_mixed_spm_result_summary(spmMixedInfo, pairName);
                        else
                            fprintf('\nMIXED SPM NOT OK | %s | %s\n', string(pairName), string(spmMixedInfo.label));
                        end

                        % Keep the result: the console summary above is the
                        % only place these numbers appeared, and there is no
                        % diary.
                        MIXED_SPM_ROWS{end+1,1} = build_mixed_spm_result_table(spmMixedInfo, pairName); %#ok<AGROW>
                    end
                end
            end

            if ~isempty(MIXED_SPM_ROWS)
                MIXED_SPM_TABLE = vertcat(MIXED_SPM_ROWS{:});
                mixedCsv = fullfile(HS.tables_dir, 'MIXED_SPM_RESULTS.csv');
                writetable(MIXED_SPM_TABLE, mixedCsv);
                fprintf('\nSaved mixed age x condition SPM results to:\n  %s\n', mixedCsv);
            end
        end
    end
end
