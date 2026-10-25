function FULL_LEG_PAIR_DETAIL_RECAP = f_cycle_count_recaps_and_tests(FINAL_PAIRED_SIGNALS, FINAL_SIGNAL_SUMMARY, C)
% F_CYCLE_COUNT_RECAPS_AND_TESTS  Where bad bursts fall in excluded cycles,
% histograms of initial vs valid cycles, cycle recap tables, and tests of
% age group / condition differences in cycle counts.

    IO = C.f_final_signals.io;
    PL = C.f_final_signals.plot;

    %% ===================== RECAP: BURST POSITIONS IN EXCLUDED CYCLES =====================
    fprintf('\nBuilding excluded-cycle burst position recap...\n');

    EXCLUDED_BURST_ROWS = {};
    riEB = 0;

    subjFields = fieldnames(FINAL_PAIRED_SIGNALS);

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};

        condFields = fieldnames(FINAL_PAIRED_SIGNALS.(subjID));
        for ic = 1:numel(condFields)
            cond = condFields{ic};

            legFields = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond));
            for il = 1:numel(legFields)
                leg = legFields{il};

                pairFields = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg));
                for ip = 1:numel(pairFields)
                    pairName = pairFields{ip};
                    PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                    if ~isfield(PairStruct, 'pair_cycle_keep_mask') || isempty(PairStruct.pair_cycle_keep_mask)
                        continue;
                    end

                    age_group = subject_to_group(subjID, C);

                    cycle_starts = PairStruct.cycle_starts(:);
                    cycle_ends   = PairStruct.cycle_ends(:);
                    pair_keep    = PairStruct.pair_cycle_keep_mask(:);

                    % muscle-specific qc
                    cycStructs = {PairStruct.muscle1_cycle_qc, PairStruct.muscle2_cycle_qc};

                    for iM = 1:2
                        cycM = cycStructs{iM};
                        musName = char(cycM.muscle);

                        % we need overlapping burst indices + burst keep information
                        if ~isfield(cycM, 'overlapping_burst_idx') || isempty(cycM.overlapping_burst_idx)
                            continue;
                        end

                        % recover burst keep mask from cycle qc / linked info
                        if isfield(cycM, 'burst_keep')
                            burst_keep_mask = cycM.burst_keep(:);
                        elseif isfield(cycM, 'burst_keep_mask')
                            burst_keep_mask = cycM.burst_keep_mask(:);
                        elseif isfield(cycM, 'source_burst_keep_mask')
                            burst_keep_mask = cycM.source_burst_keep_mask(:);
                        else
                            % if not saved there, try from pair struct if you later decide to store it there
                            burst_keep_mask = [];
                        end

                        if isfield(cycM, 'burst_idx_all')
                            all_bursts = cycM.burst_idx_all;
                        elseif isfield(cycM, 'bursts_idx')
                            all_bursts = cycM.bursts_idx;
                        elseif isfield(cycM, 'source_bursts_idx')
                            all_bursts = cycM.source_bursts_idx;
                        else
                            all_bursts = [];
                        end

                        % fallback: if not stored inside cycM, try reading from the pair struct fields if available
                        if isempty(all_bursts)
                            if iM == 1 && isfield(PairStruct, 'muscle1_bursts_idx')
                                all_bursts = PairStruct.muscle1_bursts_idx;
                            elseif iM == 2 && isfield(PairStruct, 'muscle2_bursts_idx')
                                all_bursts = PairStruct.muscle2_bursts_idx;
                            end
                        end

                        if isempty(burst_keep_mask)
                            if iM == 1 && isfield(PairStruct, 'muscle1_burst_keep_mask')
                                burst_keep_mask = PairStruct.muscle1_burst_keep_mask(:);
                            elseif iM == 2 && isfield(PairStruct, 'muscle2_burst_keep_mask')
                                burst_keep_mask = PairStruct.muscle2_burst_keep_mask(:);
                            end
                        end

                        if isempty(all_bursts) || isempty(burst_keep_mask)
                            warning('Missing burst metadata for excluded-cycle burst recap: %s | %s | %s | %s | %s', subjID, cond, leg, pairName, musName);
                            continue;
                        end

                        for iC = 1:numel(pair_keep)
                            if pair_keep(iC)
                                continue; % only excluded cycles
                            end

                            c1 = cycle_starts(iC);
                            c2 = cycle_ends(iC);
                            cLen = c2 - c1 + 1;

                            overlap_idx = cycM.overlapping_burst_idx{iC};
                            if isempty(overlap_idx)
                                continue;
                            end

                            cycleReason = "";
                            if isfield(cycM, 'cycle_reason') && numel(cycM.cycle_reason) >= iC
                                cycleReason = string(cycM.cycle_reason(iC));
                            end

                            for ib = 1:numel(overlap_idx)
                                bNum = overlap_idx(ib);

                                if bNum < 1 || bNum > size(all_bursts,1)
                                    continue;
                                end

                                b1 = all_bursts(bNum,1);
                                b2 = all_bursts(bNum,2);

                                ov1 = max(b1, c1);
                                ov2 = min(b2, c2);

                                if ov2 < ov1
                                    continue;
                                end

                                rel_start  = (ov1 - c1) / cLen * 100;
                                rel_end    = (ov2 - c1) / cLen * 100;
                                rel_center = (((ov1 + ov2)/2) - c1) / cLen * 100;

                                % riEB = riEB + 1;
                                % EXCLUDED_BURST_ROWS(riEB,:) = { ...
                                %     string(subjID), string(age_group), string(cond), string(leg), string(pairName), string(musName), ...
                                %     iC, bNum, logical(burst_keep_mask(bNum)), ...
                                %     rel_start, rel_end, rel_center, ...
                                %     string(cycleReason) ...
                                %     };
                                % burst reason / method
                                if iM == 1 && isfield(PairStruct, 'muscle1_burst_reason') && numel(PairStruct.muscle1_burst_reason) >= bNum
                                    burstReason = string(PairStruct.muscle1_burst_reason(bNum));
                                elseif iM == 2 && isfield(PairStruct, 'muscle2_burst_reason') && numel(PairStruct.muscle2_burst_reason) >= bNum
                                    burstReason = string(PairStruct.muscle2_burst_reason(bNum));
                                elseif isfield(cycM, 'source_burst_reason') && numel(cycM.source_burst_reason) >= bNum
                                    burstReason = string(cycM.source_burst_reason(bNum));
                                else
                                    burstReason = "";
                                end

                                burstMethod = classify_burst_exclusion_method(burstReason, burst_keep_mask(bNum));

                                riEB = riEB + 1;
                                EXCLUDED_BURST_ROWS(riEB,:) = { string(subjID), string(age_group), string(cond), string(leg), string(pairName), string(musName), iC, bNum, logical(burst_keep_mask(bNum)), string(burstReason), string(burstMethod), rel_start, rel_end, rel_center, string(cycleReason) };
                            end
                        end
                    end
                end
            end
        end
    end

    if ~isempty(EXCLUDED_BURST_ROWS)
        EXCLUDED_CYCLE_BURST_POSITION_TABLE = cell2table(EXCLUDED_BURST_ROWS, 'VariableNames', { 'subject','age_group','condition','leg','pair_name','muscle', 'cycle_number','burst_number','burst_keep', 'burst_reason','burst_method', 'overlap_start_pct','overlap_end_pct','overlap_center_pct', 'cycle_reason'});
    else
        EXCLUDED_CYCLE_BURST_POSITION_TABLE = table();
    end

    fprintf('Excluded-cycle burst-position rows: %d\n', height(EXCLUDED_CYCLE_BURST_POSITION_TABLE));

    % save xlsx
    writetable(EXCLUDED_CYCLE_BURST_POSITION_TABLE, IO.excluded_burst_position_xlsx);

    % make plots
    if ~isempty(EXCLUDED_CYCLE_BURST_POSITION_TABLE)
        delete(fullfile(IO.excluded_burst_position_plot_dir, '*.png'));
        fprintf('Class of T.burst_keep: %s\n', class(EXCLUDED_CYCLE_BURST_POSITION_TABLE.burst_keep));
        if iscell(EXCLUDED_CYCLE_BURST_POSITION_TABLE.burst_keep)
            lens = cellfun(@numel, EXCLUDED_CYCLE_BURST_POSITION_TABLE.burst_keep);
            fprintf('burst_keep cell sizes: min=%d, max=%d\n', min(lens), max(lens));
        end
        plot_excluded_burst_position_histograms(EXCLUDED_CYCLE_BURST_POSITION_TABLE, IO.excluded_burst_position_plot_dir, C);
        plot_excluded_burst_position_histograms_by_muscle(EXCLUDED_CYCLE_BURST_POSITION_TABLE, IO.excluded_burst_position_plot_dir, C);
        plot_excluded_burst_positions_by_method_and_muscle(EXCLUDED_CYCLE_BURST_POSITION_TABLE, IO.excluded_burst_position_plot_dir, C);
    end

    %% ===================== HISTOGRAMS: INITIAL VS VALID CYCLES PER SIGNAL =====================

    if ~isempty(FINAL_SIGNAL_SUMMARY)
        fprintf('\nGenerating histograms of initial and valid cycles per signal...\n');

        if ~exist(PL.hist_cycles_dir, 'dir'), mkdir(PL.hist_cycles_dir); end
        delete(fullfile(PL.hist_cycles_dir, '*.png'));

        % ---------- Overall histograms ----------
        plot_hist_cycle_variable_overall( FINAL_SIGNAL_SUMMARY, PL.hist_cycles_dir, 'n_initial_cycles', 'Initial number of cycles per signal', 'hist_initial_cycles_overall.png', 'Initial cycles');
        plot_hist_cycle_variable_overall( FINAL_SIGNAL_SUMMARY, PL.hist_cycles_dir, 'n_final_valid_cycles', 'Final valid cycles per signal after QC', 'hist_valid_cycles_overall.png', 'Valid cycles');
        plot_hist_cycle_variable_overall( FINAL_SIGNAL_SUMMARY, PL.hist_cycles_dir, 'percent_cycles_kept', 'Percentage of cycles kept after QC', 'hist_percent_cycles_kept_overall.png', 'Cycles kept (%)');

        % ---------- By age group ----------
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'age_group', C.plotting.age_order, C.plotting.colors, PL.hist_cycles_dir, 'Age group', 'n_initial_cycles', 'Initial cycles by age group', 'hist_initial_cycles_by_age_group.png', 'Initial cycles');
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'age_group', C.plotting.age_order, C.plotting.colors, PL.hist_cycles_dir, 'Age group', 'n_final_valid_cycles', 'Valid cycles after QC by age group', 'hist_valid_cycles_by_age_group.png', 'Valid cycles');
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'age_group', C.plotting.age_order, C.plotting.colors, PL.hist_cycles_dir, 'Age group', 'percent_cycles_kept', 'Percentage of cycles kept by age group', 'hist_percent_cycles_kept_by_age_group.png', 'Cycles kept (%)');

        % ---------- By condition ----------
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'condition', C.plotting.condition_order, C.plotting.colors, PL.hist_cycles_dir, 'Condition', 'n_initial_cycles', 'Initial cycles by condition', 'hist_initial_cycles_by_condition.png', 'Initial cycles');
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'condition', C.plotting.condition_order, C.plotting.colors, PL.hist_cycles_dir, 'Condition', 'n_final_valid_cycles', 'Valid cycles after QC by condition', 'hist_valid_cycles_by_condition.png', 'Valid cycles');
        plot_hist_cycle_variable_by_group_colored( FINAL_SIGNAL_SUMMARY, 'condition', C.plotting.condition_order, C.plotting.colors, PL.hist_cycles_dir, 'Condition', 'percent_cycles_kept', 'Percentage of cycles kept by condition', 'hist_percent_cycles_kept_by_condition.png', 'Cycles kept (%)');

        % ---------- Per pair ----------
        pairNames = unique(string(FINAL_SIGNAL_SUMMARY.pair_name));
        pairNames(ismissing(pairNames)) = [];
        pairNames = sort(pairNames);

        for iP = 1:numel(pairNames)
            pairName = pairNames(iP);

            Tpair = FINAL_SIGNAL_SUMMARY(string(FINAL_SIGNAL_SUMMARY.pair_name) == pairName, :);
            if isempty(Tpair), continue; end

            pairTag = make_valid_filename(pairName);
            pairOutDir = fullfile(PL.hist_cycles_dir, ['pair_' char(pairTag)]);
            if ~exist(pairOutDir, 'dir'), mkdir(pairOutDir); end

            plot_hist_cycle_variable_overall( Tpair, pairOutDir, 'n_initial_cycles', sprintf('Initial cycles per signal (%s)', pairName), sprintf('hist_initial_cycles_overall__%s.png', pairTag), 'Initial cycles');
            plot_hist_cycle_variable_overall( Tpair, pairOutDir, 'n_final_valid_cycles', sprintf('Valid cycles after QC per signal (%s)', pairName), sprintf('hist_valid_cycles_overall__%s.png', pairTag), 'Valid cycles');
            plot_hist_cycle_variable_overall( Tpair, pairOutDir, 'percent_cycles_kept', sprintf('Percentage of cycles kept after QC (%s)', pairName), sprintf('hist_percent_cycles_kept_overall__%s.png', pairTag), 'Cycles kept (%)');
            plot_hist_cycle_variable_by_group_colored( Tpair, 'age_group', C.plotting.age_order, C.plotting.colors, pairOutDir, sprintf('Age group | %s', pairName), 'n_initial_cycles', sprintf('Initial cycles by age group | %s', pairName), sprintf('hist_initial_cycles_by_age_group__%s.png', pairTag), 'Initial cycles');
            plot_hist_cycle_variable_by_group_colored( Tpair, 'age_group', C.plotting.age_order, C.plotting.colors, pairOutDir, sprintf('Age group | %s', pairName), 'n_final_valid_cycles', sprintf('Valid cycles after QC by age group | %s', pairName), sprintf('hist_valid_cycles_by_age_group__%s.png', pairTag), 'Valid cycles');
            plot_hist_cycle_variable_by_group_colored( Tpair, 'condition', C.plotting.condition_order, C.plotting.colors, pairOutDir, sprintf('Condition | %s', pairName), 'n_initial_cycles', sprintf('Initial cycles by condition | %s', pairName), sprintf('hist_initial_cycles_by_condition__%s.png', pairTag), 'Initial cycles');
            plot_hist_cycle_variable_by_group_colored( Tpair, 'condition', C.plotting.condition_order, C.plotting.colors, pairOutDir, sprintf('Condition | %s', pairName), 'n_final_valid_cycles', sprintf('Valid cycles after QC by condition | %s', pairName), sprintf('hist_valid_cycles_by_condition__%s.png', pairTag), 'Valid cycles');
        end
    end

    %% ===================== PARTICIPANT-LEVEL HISTOGRAMS: MEAN CYCLES ACROSS LEGS =====================

    fprintf('\nGenerating participant-level 3x4 histograms of mean cycles across legs...\n');

    participantHistDir = fullfile(PL.hist_cycles_dir, 'participant_level_mean_across_legs');
    if ~exist(participantHistDir, 'dir'), mkdir(participantHistDir); end
    delete(fullfile(participantHistDir, '*.png'));

    % One row per participant x condition x pair:
    % mean initial and valid cycles across available legs
    TmeanLegs = groupsummary( FINAL_SIGNAL_SUMMARY, {'subject','age_group','condition','pair_name'}, {'mean','min','max'}, {'n_initial_cycles','n_final_valid_cycles','percent_cycles_kept'});

    % Rename useful variables
    TmeanLegs.Properties.VariableNames{'GroupCount'} = 'n_legs_available';

    TmeanLegs.Properties.VariableNames{'mean_n_initial_cycles'} = 'mean_initial_cycles_across_legs';
    TmeanLegs.Properties.VariableNames{'min_n_initial_cycles'}  = 'min_initial_cycles_across_legs';
    TmeanLegs.Properties.VariableNames{'max_n_initial_cycles'}  = 'max_initial_cycles_across_legs';

    TmeanLegs.Properties.VariableNames{'mean_n_final_valid_cycles'} = 'mean_valid_cycles_across_legs';
    TmeanLegs.Properties.VariableNames{'min_n_final_valid_cycles'}  = 'min_valid_cycles_across_legs';
    TmeanLegs.Properties.VariableNames{'max_n_final_valid_cycles'}  = 'max_valid_cycles_across_legs';

    TmeanLegs.Properties.VariableNames{'mean_percent_cycles_kept'} = 'mean_percent_cycles_kept_across_legs';
    TmeanLegs.Properties.VariableNames{'min_percent_cycles_kept'}  = 'min_percent_cycles_kept_across_legs';
    TmeanLegs.Properties.VariableNames{'max_percent_cycles_kept'}  = 'max_percent_cycles_kept_across_legs';

    pairNames = unique(string(TmeanLegs.pair_name));
    pairNames(ismissing(pairNames)) = [];
    pairNames = sort(pairNames);

    for iP = 1:numel(pairNames)
        pairName = pairNames(iP);

        Tpair = TmeanLegs(string(TmeanLegs.pair_name) == pairName, :);

        plot_hist_cycles_participant_3x4( Tpair, participantHistDir, C.plotting.condition_order, C.plotting.age_order, C.plotting.colors, pairName, 'mean_initial_cycles_across_legs', sprintf('Participant-level initial cycles | %s | mean across legs', pairName), sprintf('hist_participant_initial_cycles_3x4__%s.png', make_valid_filename(pairName)), 'Mean initial cycles across legs');

        plot_hist_cycles_participant_3x4( Tpair, participantHistDir, C.plotting.condition_order, C.plotting.age_order, C.plotting.colors, pairName, 'mean_valid_cycles_across_legs', sprintf('Participant-level valid cycles after QC | %s | mean across legs', pairName), sprintf('hist_participant_valid_cycles_3x4__%s.png', make_valid_filename(pairName)), 'Mean valid cycles across legs');

        plot_hist_cycles_participant_3x4( Tpair, participantHistDir, C.plotting.condition_order, C.plotting.age_order, C.plotting.colors, pairName, 'mean_percent_cycles_kept_across_legs', sprintf('Participant-level percent cycles kept | %s | mean across legs', pairName), sprintf('hist_participant_percent_kept_3x4__%s.png', make_valid_filename(pairName)), 'Mean cycles kept across legs (%)');
    end

    writetable(TmeanLegs, fullfile(IO.xlsx_dir, 'CYCLES_PARTICIPANT_MEAN_ACROSS_LEGS.xlsx'));

    %% ===================== CYCLE RECAPS: DETAIL + MASTER DISTRIBUTIONS =====================

    fprintf('\nBuilding consolidated cycle recap tables...\n');

    if ~isempty(FINAL_SIGNAL_SUMMARY)

        % ---------- 1) Signal-level detail table ----------
        CYCLE_SIGNAL_DETAIL = FINAL_SIGNAL_SUMMARY(:, { 'subject','age_group','condition','leg','pair_name', 'n_initial_cycles','n_final_valid_cycles', 'n_cycles_removed_by_qc','percent_cycles_kept', 'included_after_crosstalk'});

        CYCLE_SIGNAL_DETAIL.n_valid_cycles = CYCLE_SIGNAL_DETAIL.n_final_valid_cycles;
    else
        CYCLE_SIGNAL_DETAIL = table();
    end

    fprintf('Rows in CYCLE_SIGNAL_DETAIL: %d\n', height(CYCLE_SIGNAL_DETAIL));

    % ---------- 2) Master distribution table, all levels but always pair-specific ----------
    CYCLE_RECAP_MASTER = table();

    if ~isempty(CYCLE_SIGNAL_DETAIL)

        cycleVars = { 'n_initial_cycles', 'n_final_valid_cycles', 'n_cycles_removed_by_qc', 'percent_cycles_kept'};

        inclusionModes = { 'all_signals', 'included_for_coherence'};

        rows = {};

        for iInc = 1:numel(inclusionModes)

            inclusionMode = string(inclusionModes{iInc});

            switch inclusionMode
                case "all_signals"
                    Tbase = CYCLE_SIGNAL_DETAIL;

                case "included_for_coherence"
                    Tbase = CYCLE_SIGNAL_DETAIL(CYCLE_SIGNAL_DETAIL.included_after_crosstalk == true, :);
            end

            for iV = 1:numel(cycleVars)
                valueVar = cycleVars{iV};

                rows{end+1,1} = build_cycle_recap_master_one_variable( Tbase, valueVar, inclusionMode); %#ok<AGROW>
            end
        end

        CYCLE_RECAP_MASTER = vertcat_fill_missing(rows{:});
    end

    % ---------- 3) Full-leg pair detail table ----------
    minCyclesFullLeg = 15;

    fprintf('\nBuilding full-leg pair detail recap using threshold >= %d valid cycles...\n', minCyclesFullLeg);

    FULL_LEG_PAIR_DETAIL_RECAP = table();
    FULL_LEG_NOT_VALID_RECAP = table();

    if ~isempty(CYCLE_SIGNAL_DETAIL)

        Tleg = CYCLE_SIGNAL_DETAIL;
        Tleg.has_enough_cycles_for_full_leg = Tleg.n_final_valid_cycles >= minCyclesFullLeg;
        Tleg.pair_var = matlab.lang.makeValidName(string(Tleg.pair_name));

        Tflags = unstack( Tleg(:, {'subject','age_group','condition','leg','pair_var','has_enough_cycles_for_full_leg'}), 'has_enough_cycles_for_full_leg', 'pair_var');

        Tcounts = unstack( Tleg(:, {'subject','age_group','condition','leg','pair_var','n_final_valid_cycles'}), 'n_final_valid_cycles', 'pair_var');

        Tinitial = unstack( Tleg(:, {'subject','age_group','condition','leg','pair_var','n_initial_cycles'}), 'n_initial_cycles', 'pair_var');

        pairVars = matlab.lang.makeValidName(["TAprox_TAdist","SOL_GM","VL_RF"]);

        for i = 1:numel(pairVars)
            pv = char(pairVars(i));

            if ismember(pv, Tflags.Properties.VariableNames)
                Tflags.Properties.VariableNames{pv} = [pv '_enough_cycles'];
            end

            if ismember(pv, Tcounts.Properties.VariableNames)
                Tcounts.Properties.VariableNames{pv} = [pv '_n_valid_cycles'];
            end

            if ismember(pv, Tinitial.Properties.VariableNames)
                Tinitial.Properties.VariableNames{pv} = [pv '_n_initial_cycles'];
            end
        end

        FULL_LEG_PAIR_DETAIL_RECAP = outerjoin( Tflags, Tcounts, 'Keys', {'subject','age_group','condition','leg'}, 'MergeKeys', true);

        FULL_LEG_PAIR_DETAIL_RECAP = outerjoin( FULL_LEG_PAIR_DETAIL_RECAP, Tinitial, 'Keys', {'subject','age_group','condition','leg'}, 'MergeKeys', true);

        vars = FULL_LEG_PAIR_DETAIL_RECAP.Properties.VariableNames;

        flagVars = vars(endsWith(vars, '_enough_cycles'));
        countVars = vars(endsWith(vars, '_n_valid_cycles') | endsWith(vars, '_n_initial_cycles'));

        for i = 1:numel(flagVars)
            v = flagVars{i};
            FULL_LEG_PAIR_DETAIL_RECAP.(v) = logical(FULL_LEG_PAIR_DETAIL_RECAP.(v));
            FULL_LEG_PAIR_DETAIL_RECAP.(v)(ismissing(FULL_LEG_PAIR_DETAIL_RECAP.(v))) = false;
        end

        for i = 1:numel(countVars)
            v = countVars{i};
            FULL_LEG_PAIR_DETAIL_RECAP.(v)(isnan(FULL_LEG_PAIR_DETAIL_RECAP.(v))) = 0;
        end

        enoughMat = false(height(FULL_LEG_PAIR_DETAIL_RECAP), numel(flagVars));
        for i = 1:numel(flagVars)
            enoughMat(:,i) = FULL_LEG_PAIR_DETAIL_RECAP.(flagVars{i});
        end

        FULL_LEG_PAIR_DETAIL_RECAP.n_pairs_present = numel(flagVars) - sum(ismissing(FULL_LEG_PAIR_DETAIL_RECAP(:, flagVars)), 2);
        FULL_LEG_PAIR_DETAIL_RECAP.n_pairs_with_enough_cycles = sum(enoughMat, 2);
        FULL_LEG_PAIR_DETAIL_RECAP.full_leg_all_pairs_enough_cycles = all(enoughMat, 2);

        FULL_LEG_NOT_VALID_RECAP = FULL_LEG_PAIR_DETAIL_RECAP( FULL_LEG_PAIR_DETAIL_RECAP.full_leg_all_pairs_enough_cycles == false, :);
    end

    fprintf('Rows in CYCLE_RECAP_MASTER: %d\n', height(CYCLE_RECAP_MASTER));
    fprintf('Rows in FULL_LEG_PAIR_DETAIL_RECAP: %d\n', height(FULL_LEG_PAIR_DETAIL_RECAP));
    fprintf('Rows in FULL_LEG_NOT_VALID_RECAP: %d\n', height(FULL_LEG_NOT_VALID_RECAP));

    writetable(CYCLE_SIGNAL_DETAIL, fullfile(IO.xlsx_dir, 'CYCLE_SIGNAL_DETAIL.xlsx'));

    writetable(CYCLE_RECAP_MASTER, fullfile(IO.xlsx_dir, 'CYCLE_RECAP_MASTER_BY_PAIR.xlsx'));

    writetable(FULL_LEG_PAIR_DETAIL_RECAP, fullfile(IO.xlsx_dir, 'FULL_LEG_PAIR_DETAIL_RECAP.xlsx'));

    writetable(FULL_LEG_NOT_VALID_RECAP, fullfile(IO.xlsx_dir, 'FULL_LEG_NOT_VALID_RECAP.xlsx'));

    %% ===================== TEST GROUP/CONDITION DIFFERENCES IN CYCLE COUNTS =====================

    % ---------- Save ----------
    outStatsDir = fullfile(IO.xlsx_dir, 'cycle_count_stat_tests');
    if ~exist(outStatsDir, 'dir'), mkdir(outStatsDir); end

    fprintf('\nTesting age / condition differences in cycle counts...\n');

    T = FINAL_SIGNAL_SUMMARY;
    cycleVarsToTest = {'n_initial_cycles','n_final_valid_cycles','percent_cycles_kept'};

    ALL_CYCLE_LME_TESTS = table();
    ALL_CYCLE_KW_TESTS = table();

    for iV = 1:numel(cycleVarsToTest)

        cycleVar = cycleVarsToTest{iV};

        fprintf('\n\n===================== %s =====================\n', cycleVar);

        Tclean = T(~ismissing(T.age_group) & ~ismissing(T.condition) & ~isnan(T.(cycleVar)), :);

        Tclean.age_group = categorical(string(Tclean.age_group));
        Tclean.condition = categorical(string(Tclean.condition));
        Tclean.pair_name = categorical(string(Tclean.pair_name));
        Tclean.subject   = categorical(string(Tclean.subject));

        pairNames = categories(Tclean.pair_name);

        % ---------- A) Kruskal-Wallis: age group, condition, and age x condition ----------
        rowsKW = {};

        for iP = 1:numel(pairNames)
            pairName = pairNames{iP};
            Tp = Tclean(Tclean.pair_name == pairName, :);

            if height(Tp) < 10
                continue;
            end

            % Age
            pAge = NaN;
            if numel(categories(removecats(Tp.age_group))) >= 2
                pAge = kruskalwallis(Tp.(cycleVar), Tp.age_group, 'off');
            end

            % Condition
            pCond = NaN;
            if numel(categories(removecats(Tp.condition))) >= 2
                pCond = kruskalwallis(Tp.(cycleVar), Tp.condition, 'off');
            end

            % Age x Condition as combined groups
            ageCond = categorical(strcat(string(Tp.age_group), "_", string(Tp.condition)));
            pAgeCond = NaN;
            if numel(categories(removecats(ageCond))) >= 2
                pAgeCond = kruskalwallis(Tp.(cycleVar), ageCond, 'off');
            end

            rowsKW(end+1,:) = { string(cycleVar), string(pairName), height(Tp), pAge, pCond, pAgeCond }; %#ok<AGROW>
        end

        if ~isempty(rowsKW)
            KW_THIS = cell2table(rowsKW, 'VariableNames', { 'cycle_variable','pair_name','n_rows', 'p_kruskal_age_group','p_kruskal_condition','p_kruskal_age_condition_combined'});
            ALL_CYCLE_KW_TESTS = [ALL_CYCLE_KW_TESTS; KW_THIS]; %#ok<AGROW>
            disp(KW_THIS);
        end

        % ---------- B) Overall mixed model ----------
        try
            formulaOverall = sprintf('%s ~ age_group + condition + pair_name + (1|subject)', cycleVar);
            LME_overall = fitlme(Tclean, formulaOverall);
            A = dataset2table(anova(LME_overall));

            A.cycle_variable = repmat(string(cycleVar), height(A), 1);
            A.model_scope = repmat("overall_all_pairs", height(A), 1);
            A.pair_name = repmat("ALL", height(A), 1);

            A = movevars(A, {'cycle_variable','model_scope','pair_name'}, 'Before', 1);

            ALL_CYCLE_LME_TESTS = [ALL_CYCLE_LME_TESTS; A]; %#ok<AGROW>

            fprintf('\n===== LME OVERALL | %s =====\n', cycleVar);
            fprintf('%s\n', formulaOverall);
            disp(A);

        catch ME
            warning('Overall LME failed for %s: %s', cycleVar, ME.message);
        end

        % ---------- C) Mixed model per pair ----------
        for iP = 1:numel(pairNames)

            pairName = pairNames{iP};
            Tp = Tclean(Tclean.pair_name == pairName, :);

            if height(Tp) < 10 || numel(categories(removecats(Tp.age_group))) < 2 || numel(categories(removecats(Tp.condition))) < 2
                continue;
            end

            try
                formulaPair = sprintf('%s ~ age_group + condition + (1|subject)', cycleVar);
                LME_pair = fitlme(Tp, formulaPair);
                A = dataset2table(anova(LME_pair));

                A.cycle_variable = repmat(string(cycleVar), height(A), 1);
                A.model_scope = repmat("per_pair", height(A), 1);
                A.pair_name = repmat(string(pairName), height(A), 1);

                A = movevars(A, {'cycle_variable','model_scope','pair_name'}, 'Before', 1);

                ALL_CYCLE_LME_TESTS = [ALL_CYCLE_LME_TESTS; A]; %#ok<AGROW>

                fprintf('\n===== LME | %s | %s =====\n', pairName, cycleVar);
                fprintf('%s\n', formulaPair);
                disp(A);

            catch ME
                warning('Pair LME failed for %s | %s: %s', pairName, cycleVar, ME.message);
            end
        end
        DESC = groupsummary( Tclean, {'age_group','condition','pair_name'}, {'mean','median','std'}, cycleVar);

        disp(DESC);

        writetable(DESC, fullfile(outStatsDir, sprintf('DESC_%s_BY_AGE_CONDITION_PAIR.xlsx', cycleVar)));
    end

    writetable(ALL_CYCLE_KW_TESTS, fullfile(outStatsDir, 'CYCLE_COUNT_KRUSKAL_TESTS_BY_PAIR.xlsx'));

    writetable(ALL_CYCLE_LME_TESTS, fullfile(outStatsDir, 'CYCLE_COUNT_LME_TESTS.xlsx'));

    fprintf('\nSaved cycle-count statistical tests to:\n  %s\n', outStatsDir);
end
