function export_final_signal_summary_readable_xlsx(FINAL_SIGNAL_SUMMARY, RECOVERABILITY_PRIORITY_RECAP, ADULTS_8_TO_15_CYCLES_BY_SIGNAL, FULL_LEG_PAIR_DETAIL_RECAP, META, outXlsx, include_metadata)

    if isfile(outXlsx)
        delete(outXlsx);
    end

    % Configured bands, read from the summary's per-band inclusion columns
    bandSfx = strings(1,0);
    if ~isempty(FINAL_SIGNAL_SUMMARY)
        v = string(FINAL_SIGNAL_SUMMARY.Properties.VariableNames);
        bandSfx = extractAfter(v(startsWith(v, "included_after_crosstalk_")), "included_after_crosstalk_");
    end

    %% ---------- Sheet 1: main subject summary ----------
    MAIN = table();

    if ~isempty(FINAL_SIGNAL_SUMMARY)

        subjects = unique(string(FINAL_SIGNAL_SUMMARY.subject));
        rows = {};

        for iS = 1:numel(subjects)
            subj = subjects(iS);
            Ts = FINAL_SIGNAL_SUMMARY(string(FINAL_SIGNAL_SUMMARY.subject) == subj, :);

            age_group = string(Ts.age_group(1));

            n_total_signals = height(Ts);
            n_included_overall = sum(Ts.included_after_crosstalk == true);
            n_included_band = arrayfun(@(b) sum(Ts.("included_after_crosstalk_" + b) == true), bandSfx, 'UniformOutput', false);

            median_initial = median(Ts.n_initial_cycles, 'omitnan');
            median_valid   = median(Ts.n_final_valid_cycles, 'omitnan');
            median_kept    = median(Ts.percent_cycles_kept, 'omitnan');

            n_zero_valid = sum(Ts.n_final_valid_cycles == 0);
            n_borderline_8_15 = sum(Ts.n_final_valid_cycles >= 8 & Ts.n_final_valid_cycles <= 15);

            % condition-level minimum valid cycles, across all pairs/legs
            conds = ["Flat","Medium","High"];
            condMin = nan(1, numel(conds));

            for ic = 1:numel(conds)
                Tc = Ts(string(Ts.condition) == conds(ic), :);
                if ~isempty(Tc)
                    condMin(ic) = min(Tc.n_final_valid_cycles);
                end
            end

            % recoverability info if available
            recScore = NaN;
            recCat = "";
            bestTargets = "";

            if ~isempty(RECOVERABILITY_PRIORITY_RECAP) && ismember('subject', RECOVERABILITY_PRIORITY_RECAP.Properties.VariableNames)
                R = RECOVERABILITY_PRIORITY_RECAP(string(RECOVERABILITY_PRIORITY_RECAP.subject) == subj, :);
                if ~isempty(R)
                    recScore = R.recoverability_score(1);
                    recCat = string(R.recoverability_category(1));

                    if ismember('detail_borderline_signals_valid_original_kept', R.Properties.VariableNames)
                        bestTargets = string(R.detail_borderline_signals_valid_original_kept(1));
                    end
                end
            end

            rows(end+1,:) = [{subj, age_group, n_total_signals, n_included_overall}, n_included_band, ...
                {median_initial, median_valid, median_kept, n_zero_valid, ""}]; %#ok<AGROW>
        end

        MAIN = cell2table(rows, 'VariableNames', [{'subject','age_group','n_total_signals','n_included_overall'}, ...
            cellstr("n_included_" + bandSfx), ...
            {'median_initial_cycles','median_valid_cycles','median_percent_cycles_kept','n_zero_valid_signals','notes'}]);

        % merge metadata at the start
        if include_metadata && ~isempty(META) && ismember('subject', META.Properties.VariableNames)
            MAIN.subject = string(MAIN.subject);
            META.subject = string(META.subject);

            MAIN = outerjoin(MAIN, META, ...
                'Keys', 'subject', ...
                'MergeKeys', true, ...
                'Type', 'left');

            metaCols = {'Participant','AgeGroup','AgeMonths','Sex','Height_cm','Weight_kg','L0_m','IMC','TA_TA_cm'};
            metaCols = metaCols(ismember(metaCols, MAIN.Properties.VariableNames));

            MAIN = movevars(MAIN, metaCols, 'After', 'age_group');
        end

        MAIN.subject_num = str2double(regexprep(string(MAIN.subject), '\D', ''));
        MAIN = sortrows(MAIN, 'subject_num');
        MAIN.subject_num = [];
    end

    writetable(MAIN, outXlsx, 'Sheet', '01_MAIN_SUMMARY');

    %% ---------- Sheet 2: signal-level detail ----------
    if ~isempty(FINAL_SIGNAL_SUMMARY)
        keepCols = { ...
            'subject','age_group','condition','leg','pair_name', ...
            'n_initial_cycles','n_final_valid_cycles','n_cycles_removed_by_qc','percent_cycles_kept', ...
            'excluded_by_crosstalk','crosstalk_reason'};
        keepCols = [keepCols(1:9), cellstr("n_valid_cycles_" + bandSfx), keepCols(10:end)];

        keepCols = keepCols(ismember(keepCols, FINAL_SIGNAL_SUMMARY.Properties.VariableNames));
        SIGNAL_DETAIL = FINAL_SIGNAL_SUMMARY(:, keepCols);

        SIGNAL_DETAIL = sortrows(SIGNAL_DETAIL, {'subject','condition','leg','pair_name'});
    else
        SIGNAL_DETAIL = table();
    end

    writetable(SIGNAL_DETAIL, outXlsx, 'Sheet', '02_SIGNAL_DETAIL');

    %% ---------- Sheet 3: band summary ----------
    BAND_SUMMARY = table();

    if ~isempty(FINAL_SIGNAL_SUMMARY)
        bandInfo = [{"OVERALL", 'included_after_crosstalk', 'n_final_valid_cycles'}; ...
            [num2cell(upper(bandSfx(:))), cellstr("included_after_crosstalk_" + bandSfx(:)), cellstr("n_valid_cycles_" + bandSfx(:))]];

        rows = {};

        for ib = 1:size(bandInfo,1)
            band = bandInfo{ib,1};
            includeVar = bandInfo{ib,2};
            cycleVar = bandInfo{ib,3};

            if ~ismember(includeVar, FINAL_SIGNAL_SUMMARY.Properties.VariableNames) || ...
               ~ismember(cycleVar, FINAL_SIGNAL_SUMMARY.Properties.VariableNames)
                continue;
            end

            T = FINAL_SIGNAL_SUMMARY;

            subjects = unique(string(T.subject));
            for iS = 1:numel(subjects)
                subj = subjects(iS);
                Ts = T(string(T.subject) == subj, :);

                age_group = string(Ts.age_group(1));

                pairs = unique(string(Ts.pair_name));
                for ip = 1:numel(pairs)
                    pairName = pairs(ip);
                    Tp = Ts(string(Ts.pair_name) == pairName, :);

                    rows(end+1,:) = { ...
                        subj, age_group, band, pairName, ...
                        height(Tp), ...
                        sum(Tp.(includeVar) == true), ...
                        median(Tp.(cycleVar), 'omitnan'), ...
                        min(Tp.(cycleVar)), ...
                        max(Tp.(cycleVar)), ...
                        100 * mean(Tp.(includeVar) == true, 'omitnan') ...
                        }; %#ok<AGROW>
                end
            end
        end

        BAND_SUMMARY = cell2table(rows, 'VariableNames', { ...
            'subject','age_group','band','pair_name', ...
            'n_signals','n_included','median_valid_cycles','min_valid_cycles','max_valid_cycles', ...
            'percent_included'});
    end

    writetable(BAND_SUMMARY, outXlsx, 'Sheet', '03_BAND_SUMMARY');

    %% ---------- Sheet 4: borderline signals ----------
    if ~isempty(ADULTS_8_TO_15_CYCLES_BY_SIGNAL)
        BORDERLINE = ADULTS_8_TO_15_CYCLES_BY_SIGNAL;
        BORDERLINE = sortrows(BORDERLINE, {'subject','condition','leg','pair_name'});
    else
        BORDERLINE = table();
    end

    writetable(BORDERLINE, outXlsx, 'Sheet', '04_BORDERLINE_SIGNALS');

    %% ---------- Sheet 5: full leg detail ----------
    if ~isempty(FULL_LEG_PAIR_DETAIL_RECAP)
        FULLLEG = FULL_LEG_PAIR_DETAIL_RECAP;
        FULLLEG = sortrows(FULLLEG, {'subject','condition','leg'});
    else
        FULLLEG = table();
    end

    writetable(FULLLEG, outXlsx, 'Sheet', '05_FULL_LEG_DETAIL');

    %% ---------- Sheet 6: README ----------
    README = table( ...
        ["01_MAIN_SUMMARY"; "02_SIGNAL_DETAIL"; "03_BAND_SUMMARY"; "04_BORDERLINE_SIGNALS"; "05_FULL_LEG_DETAIL"], ...
        [ ...
        "One row per subject. Human-readable overview of final signal availability."; ...
        "One row per subject x condition x leg x pair. Detailed final signal information."; ...
        "One row per subject x pair x band. Shows band-specific inclusion."; ...
        "Adult TA-TA/SOL-GM signals with 8-15 valid cycles, useful for manual recovery checks."; ...
        "One row per subject x condition x leg, with pair-specific enough-cycle flags." ...
        ], ...
        'VariableNames', {'sheet','description'});

    writetable(README, outXlsx, 'Sheet', 'README');
end