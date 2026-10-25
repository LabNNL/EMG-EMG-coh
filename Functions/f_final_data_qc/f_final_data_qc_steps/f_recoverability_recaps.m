function f_recoverability_recaps(FINAL_SIGNAL_SUMMARY, FULL_LEG_PAIR_DETAIL_RECAP, C)
% F_RECOVERABILITY_RECAPS  Participants with 8-15 valid cycles in the target age
% groups, a recoverability priority score, and the readable summary workbook.

    IO = C.f_final_signals.io;

    %% ===================== LOAD PARTICIPANT METADATA =====================

    % Read the CSV, not the .xlsx beside it: the .xlsx is a stale export with
    % 77 of the 80 participants (CTL_78, CTL_79 and CTL_81 are missing), and
    % the join below is a left join, so those three silently ended up with
    % empty metadata. h_coherence_stats reads this same CSV.
    metadata_csv = fullfile(C.paths.metadata_dir, 'participants_metadata_EMG.csv');

    META = readtable(metadata_csv, 'Delimiter', ';', 'TreatAsEmpty', {'NA','NaN',''});
    META.subject = string(META.Participant);

    %% ===================== TARGET AGE GROUPS WITH 8-15 VALID CYCLES =====================

    minCyclesCheck = 8;
    maxCyclesCheck = 15;

    targetPairsRecoverability = ["TAprox_TAdist","SOL_GM"];
    targetAgeGroupsRecoverability = ["Adultes","Adolescents"];

    TallTarget = FINAL_SIGNAL_SUMMARY( ismember(string(FINAL_SIGNAL_SUMMARY.age_group), targetAgeGroupsRecoverability) & ismember(string(FINAL_SIGNAL_SUMMARY.pair_name), targetPairsRecoverability), :);

    assert(all(ismember(string(TallTarget.pair_name), targetPairsRecoverability)), 'TallTarget contains non-target pairs. Check targetPairsRecoverability filter.');

    assert(all(ismember(string(TallTarget.age_group), targetAgeGroupsRecoverability)), 'TallTarget contains non-target age groups. Check targetAgeGroupsRecoverability filter.');

    TtargetRange = TallTarget( TallTarget.n_final_valid_cycles >= minCyclesCheck & TallTarget.n_final_valid_cycles <= maxCyclesCheck, :);

    TARGET_8_TO_15_CYCLES_BY_SIGNAL = TtargetRange(:, { 'subject','age_group','condition','leg','pair_name', 'n_initial_cycles','n_final_valid_cycles', 'n_cycles_removed_by_qc','percent_cycles_kept'});

    fprintf('\nTarget age groups with %d-%d valid cycles per subject / condition / leg / pair: %d rows\n', minCyclesCheck, maxCyclesCheck, height(TARGET_8_TO_15_CYCLES_BY_SIGNAL));

    disp(TARGET_8_TO_15_CYCLES_BY_SIGNAL);

    %% ===================== ONE-LINE RECAP PER SUBJECT WITH 8-15 VALID CYCLES =====================

    TARGET_8_TO_15_ONE_ROW = table();

    if ~isempty(TtargetRange)

        targetIDs = unique(string(TtargetRange.subject));
        rows = {};

        for iA = 1:numel(targetIDs)
            subj = targetIDs(iA);

            TsRange = TtargetRange(string(TtargetRange.subject) == subj, :);
            TsAll   = TallTarget(string(TallTarget.subject) == subj, :);

            age_group_i = string(TsAll.age_group(1));

            nBelow = sum(TsAll.n_final_valid_cycles < minCyclesCheck);
            nIn    = sum(TsAll.n_final_valid_cycles >= minCyclesCheck & TsAll.n_final_valid_cycles <= maxCyclesCheck);
            nAbove = sum(TsAll.n_final_valid_cycles > maxCyclesCheck);

            minInitialAll = min(TsAll.n_initial_cycles);
            maxInitialAll = max(TsAll.n_initial_cycles);
            medianInitialAll = median(TsAll.n_initial_cycles, 'omitnan');

            minValidAll = min(TsAll.n_final_valid_cycles);
            maxValidAll = max(TsAll.n_final_valid_cycles);
            medianValidAll = median(TsAll.n_final_valid_cycles, 'omitnan');

            medianPercentKeptAll = median(TsAll.percent_cycles_kept, 'omitnan');
            minPercentKeptAll = min(TsAll.percent_cycles_kept);
            maxPercentKeptAll = max(TsAll.percent_cycles_kept);

            detailStrings = strings(height(TsRange),1);

            for i = 1:height(TsRange)
                detailStrings(i) = sprintf('%s_%s_%s: valid=%d/original=%d kept=%.1f%%', string(TsRange.condition(i)), string(TsRange.leg(i)), string(TsRange.pair_name(i)), TsRange.n_final_valid_cycles(i), TsRange.n_initial_cycles(i), TsRange.percent_cycles_kept(i));
            end

            rows(end+1,:) = { subj, age_group_i, height(TsAll), nBelow, nIn, nAbove, minInitialAll, medianInitialAll, maxInitialAll, minValidAll, medianValidAll, maxValidAll, minPercentKeptAll, medianPercentKeptAll, maxPercentKeptAll, strjoin(unique(string(TsRange.condition)), ","), strjoin(unique(string(TsRange.leg)), ","), strjoin(unique(string(TsRange.pair_name)), ","), strjoin(detailStrings, " | ") }; %#ok<SAGROW>
        end

        TARGET_8_TO_15_ONE_ROW = cell2table(rows, 'VariableNames', { 'subject', 'age_group', 'n_total_target_signals_TATA_SOLGM', 'n_signals_below_8_valid_cycles', 'n_signals_between_8_and_15_valid_cycles', 'n_signals_above_15_valid_cycles', 'min_initial_cycles_overall', 'median_initial_cycles_overall', 'max_initial_cycles_overall', 'min_valid_cycles_overall', 'median_valid_cycles_overall', 'max_valid_cycles_overall', 'min_percent_cycles_kept_overall', 'median_percent_cycles_kept_overall', 'max_percent_cycles_kept_overall', 'conditions_concerned_in_range', 'legs_concerned_in_range', 'pairs_concerned_in_range', 'detail_condition_leg_pair_valid_original_kept_in_range' });

        TARGET_8_TO_15_ONE_ROW.subject = string(TARGET_8_TO_15_ONE_ROW.subject);

        TARGET_8_TO_15_ONE_ROW = outerjoin( TARGET_8_TO_15_ONE_ROW, META, 'Keys', 'subject', 'MergeKeys', true, 'Type', 'left');

        metaCols = { 'Participant','AgeGroup','AgeMonths','Sex', 'Height_cm','Weight_kg','L0_m','IMC','TA_TA_cm'};

        metaCols = metaCols(ismember(metaCols, TARGET_8_TO_15_ONE_ROW.Properties.VariableNames));

        TARGET_8_TO_15_ONE_ROW = movevars( TARGET_8_TO_15_ONE_ROW, metaCols, 'Before', 'subject');
    end

    TARGET_8_TO_15_ONE_ROW = sortrows( TARGET_8_TO_15_ONE_ROW, 'n_signals_between_8_and_15_valid_cycles', 'descend');

    disp(TARGET_8_TO_15_ONE_ROW);

    writetable(TARGET_8_TO_15_CYCLES_BY_SIGNAL, fullfile(IO.xlsx_dir, 'TARGET_AGEGROUPS_8_TO_15_CYCLES_BY_SIGNAL.xlsx'));

    writetable(TARGET_8_TO_15_ONE_ROW, fullfile(IO.xlsx_dir, 'TARGET_AGEGROUPS_8_TO_15_ONE_ROW_RECAP.xlsx'));

    % Backward-compatible aliases for downstream code / XLSX function
    ADULTS_8_TO_15_CYCLES_BY_SIGNAL = TARGET_8_TO_15_CYCLES_BY_SIGNAL;
    ADULTS_8_TO_15_ONE_ROW = TARGET_8_TO_15_ONE_ROW;

    %% ===================== TARGET AGE GROUP RECOVERABILITY PRIORITY SCORE =====================

    fprintf('\nBuilding target age-group recoverability priority score...\n');

    expectedConditions = string(C.plotting.condition_order);
    expectedLegs = ["left","right"];

    RECOVERABILITY_PRIORITY_RECAP = table();

    if ~isempty(TallTarget)

        targetIDs = unique(string(TallTarget.subject));
        rows = {};

        for iA = 1:numel(targetIDs)

            subj = targetIDs(iA);

            TsAll = TallTarget(string(TallTarget.subject) == subj, :);
            TsTarget = TsAll;

            if isempty(TsTarget)
                continue;
            end

            nExpectedRows = numel(targetPairsRecoverability) * numel(expectedConditions) * numel(expectedLegs);
            nRowsPresent = height(TsTarget);
            nMissingRows = max(0, nExpectedRows - nRowsPresent);

            nBelow8 = sum(TsTarget.n_final_valid_cycles < 8);
            nIn8to15 = sum(TsTarget.n_final_valid_cycles >= 8 & TsTarget.n_final_valid_cycles <= 15);
            nAbove15 = sum(TsTarget.n_final_valid_cycles > 15);
            nZeroValid = sum(TsTarget.n_final_valid_cycles == 0);

            Tin = TsTarget(TsTarget.n_final_valid_cycles >= 8 & TsTarget.n_final_valid_cycles <= 15, :);

            if isempty(Tin)
                continue;
            end

            nConditionsPresent = numel(unique(string(TsTarget.condition)));
            nLegsPresent = numel(unique(string(TsTarget.leg)));
            nConditionLegPresent = height(unique(TsTarget(:, {'condition','leg'})));

            conditionCoverage = nConditionsPresent / numel(expectedConditions);
            legCoverage = nLegsPresent / numel(expectedLegs);
            rowCoverage = nRowsPresent / nExpectedRows;

            medianInitialTarget = median(TsTarget.n_initial_cycles, 'omitnan');
            medianValidTarget = median(TsTarget.n_final_valid_cycles, 'omitnan');
            medianPercentKeptTarget = median(TsTarget.percent_cycles_kept, 'omitnan');

            medianInitialInRange = median(Tin.n_initial_cycles, 'omitnan');
            medianValidInRange = median(Tin.n_final_valid_cycles, 'omitnan');
            medianPercentKeptInRange = median(Tin.percent_cycles_kept, 'omitnan');

            distanceTo15 = 15 - Tin.n_final_valid_cycles;
            medianDistanceTo15 = median(distanceTo15, 'omitnan');

            Tta = TsTarget(string(TsTarget.pair_name) == "TAprox_TAdist", :);
            Tsol = TsTarget(string(TsTarget.pair_name) == "SOL_GM", :);

            medianKeptTATA = median(Tta.percent_cycles_kept, 'omitnan');
            medianKeptSOLGM = median(Tsol.percent_cycles_kept, 'omitnan');

            nInRangeTATA = sum(Tta.n_final_valid_cycles >= 8 & Tta.n_final_valid_cycles <= 15);
            nInRangeSOLGM = sum(Tsol.n_final_valid_cycles >= 8 & Tsol.n_final_valid_cycles <= 15);

            metaRow = META(string(META.subject) == subj, :);

            height_cm = NaN;
            weight_kg = NaN;
            L0_m = NaN;
            TA_TA_cm = NaN;
            AgeMonths = NaN;
            Sex = "";

            if ~isempty(metaRow)
                if ismember('Height_cm', metaRow.Properties.VariableNames), height_cm = metaRow.Height_cm(1); end
                if ismember('Weight_kg', metaRow.Properties.VariableNames), weight_kg = metaRow.Weight_kg(1); end
                if ismember('L0_m', metaRow.Properties.VariableNames), L0_m = metaRow.L0_m(1); end
                if ismember('TA_TA_cm', metaRow.Properties.VariableNames), TA_TA_cm = metaRow.TA_TA_cm(1); end
                if ismember('AgeMonths', metaRow.Properties.VariableNames), AgeMonths = metaRow.AgeMonths(1); end
                if ismember('Sex', metaRow.Properties.VariableNames), Sex = string(metaRow.Sex(1)); end
            end

            height_m = NaN;
            expectedLowCycles_forHeight = NaN;
            expectedHighCycles_forHeight = NaN;
            initialCycleDeficitRelativeToHeight = NaN;
            sizeAdjustedInitialCycleScore = 0;

            if isfinite(height_cm) && height_cm > 0
                height_m = height_cm / 100;

                referenceHeight_m = 1.70;
                referenceLowCycles = 12;
                referenceHighCycles = 18;

                expectedLowCycles_forHeight  = referenceLowCycles  * referenceHeight_m / height_m;
                expectedHighCycles_forHeight = referenceHighCycles * referenceHeight_m / height_m;

                sizeAdjustedInitialCycleScore = clip01( (expectedHighCycles_forHeight - medianInitialTarget) / (expectedHighCycles_forHeight - expectedLowCycles_forHeight));

                initialCycleDeficitRelativeToHeight = expectedHighCycles_forHeight - medianInitialTarget;
            end

            keptScore = clip01(medianPercentKeptTarget / 80);
            distanceScore = clip01((7 - medianDistanceTo15) / 7);
            rangeAmountScore = clip01(nIn8to15 / 6);
            coverageScore = mean([rowCoverage, conditionCoverage, legCoverage], 'omitnan');

            zeroPenalty = clip01(nZeroValid / 4);
            missingPenalty = clip01(nMissingRows / nExpectedRows);

            recoverabilityScore = 100 * ( 0.25 * keptScore + 0.00 * distanceScore + 0.25 * rangeAmountScore + 0.15 * coverageScore + 0.15 * sizeAdjustedInitialCycleScore - 0.35 * zeroPenalty - 0.30 * missingPenalty);

            recoverabilityScore = max(0, min(100, recoverabilityScore));

            if recoverabilityScore >= 65
                category = "HIGH";
            elseif recoverabilityScore >= 40
                category = "MODERATE";
            else
                category = "LOW";
            end

            detailStrings = strings(height(Tin),1);
            for i = 1:height(Tin)
                detailStrings(i) = sprintf('%s_%s_%s: valid=%d/original=%d kept=%.1f%%', string(Tin.condition(i)), string(Tin.leg(i)), string(Tin.pair_name(i)), Tin.n_final_valid_cycles(i), Tin.n_initial_cycles(i), Tin.percent_cycles_kept(i));
            end

            missingNote = sprintf(['expected TA-TA/SOL-GM rows=%d; present=%d; missing=%d; ' 'zero_valid=%d; condition_coverage=%.2f; leg_coverage=%.2f; row_coverage=%.2f; size_adjusted_initial_cycle_score=%.2f'], nExpectedRows, nRowsPresent, nMissingRows, nZeroValid, conditionCoverage, legCoverage, rowCoverage, sizeAdjustedInitialCycleScore);

            rows(end+1,:) = { subj, string(TsTarget.age_group(1)), recoverabilityScore, category, keptScore, distanceScore, rangeAmountScore, coverageScore, zeroPenalty, missingPenalty, sizeAdjustedInitialCycleScore, height_m, expectedLowCycles_forHeight, expectedHighCycles_forHeight, initialCycleDeficitRelativeToHeight, nRowsPresent, nExpectedRows, nMissingRows, nZeroValid, nBelow8, nIn8to15, nAbove15, nInRangeTATA, nInRangeSOLGM, medianInitialTarget, medianValidTarget, medianPercentKeptTarget, medianInitialInRange, medianValidInRange, medianPercentKeptInRange, medianDistanceTo15, medianKeptTATA, medianKeptSOLGM, nConditionsPresent, nLegsPresent, nConditionLegPresent, conditionCoverage, legCoverage, rowCoverage, height_cm, weight_kg, L0_m, TA_TA_cm, AgeMonths, Sex, missingNote, strjoin(unique(string(Tin.condition)), ","), strjoin(unique(string(Tin.leg)), ","), strjoin(unique(string(Tin.pair_name)), ","), strjoin(detailStrings, " | ") }; %#ok<AGROW>
        end

        RECOVERABILITY_PRIORITY_RECAP = cell2table(rows, 'VariableNames', { 'subject', 'age_group', 'recoverability_score', 'recoverability_category', 'score_component_percent_kept', 'score_component_distance_to_15', 'score_component_n_borderline_signals', 'score_component_coverage', 'score_penalty_zero_valid_rows', 'score_penalty_missing_rows', 'score_component_low_initial_cycles_relative_to_height', 'height_m', 'expected_low_initial_cycles_for_height', 'expected_high_initial_cycles_for_height', 'initial_cycle_deficit_relative_to_height', 'n_target_rows_present_TATA_SOLGM', 'n_target_rows_expected_TATA_SOLGM', 'n_missing_target_rows_TATA_SOLGM', 'n_zero_valid_target_rows_TATA_SOLGM', 'n_target_signals_below_8', 'n_target_signals_between_8_and_15', 'n_target_signals_above_15', 'n_TATA_signals_between_8_and_15', 'n_SOLGM_signals_between_8_and_15', 'median_initial_cycles_target_pairs', 'median_valid_cycles_target_pairs', 'median_percent_kept_target_pairs', 'median_initial_cycles_in_range', 'median_valid_cycles_in_range', 'median_percent_kept_in_range', 'median_distance_to_15_cycles_in_range', 'median_percent_kept_TATA', 'median_percent_kept_SOLGM', 'n_conditions_present_target_pairs', 'n_legs_present_target_pairs', 'n_condition_leg_combinations_present_target_pairs', 'condition_coverage_target_pairs', 'leg_coverage_target_pairs', 'row_coverage_target_pairs', 'Height_cm', 'Weight_kg', 'L0_m', 'TA_TA_cm', 'AgeMonths', 'Sex', 'coverage_and_missing_note', 'conditions_concerned_in_range', 'legs_concerned_in_range', 'pairs_concerned_in_range', 'detail_borderline_signals_valid_original_kept' });

        RECOVERABILITY_PRIORITY_RECAP = sortrows( RECOVERABILITY_PRIORITY_RECAP, {'recoverability_score','n_target_signals_between_8_and_15'}, {'descend','descend'});
    end

    disp(RECOVERABILITY_PRIORITY_RECAP);

    writetable(RECOVERABILITY_PRIORITY_RECAP, fullfile(IO.xlsx_dir, 'RECOVERABILITY_PRIORITY_RECAP.xlsx'));

    %% ===================== EXPORT READABLE FINAL SIGNAL SUMMARY XLSX =====================

    fprintf('\nExporting readable final signal summary XLSX...\n');

    summaryXlsx = fullfile(IO.xlsx_dir, 'FINAL_SIGNAL_SUMMARY_READABLE.xlsx');

    include_metadata = false;

    export_final_signal_summary_readable_xlsx( FINAL_SIGNAL_SUMMARY, RECOVERABILITY_PRIORITY_RECAP, ADULTS_8_TO_15_CYCLES_BY_SIGNAL, FULL_LEG_PAIR_DETAIL_RECAP, META, summaryXlsx, include_metadata);

    fprintf('Saved readable XLSX:\n  %s\n', summaryXlsx);
end
