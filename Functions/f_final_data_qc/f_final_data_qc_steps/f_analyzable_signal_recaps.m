function RECAPS = f_analyzable_signal_recaps(FINAL_SIGNAL_SUMMARY, C)
% F_ANALYZABLE_SIGNAL_RECAPS  How many signals and participants are analysable,
% overall and per band, by age group, condition and pair (printed and
% returned). RECAPS holds the tables saved in FINAL_PAIRED_SIGNALS.mat.

    P  = C.f_final_signals.params;
    bandNames = fieldnames(C.f_final_signals.params.wavelet_contamination_qc.freq_bands);

    %% ===================== RECAP OF ANALYZABLE SIGNALS =====================
    if ~isempty(FINAL_SIGNAL_SUMMARY)

        ANALYZABLE_SIGNALS = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.included_after_crosstalk == true, :);
        RECAP_OVERALL = build_signal_recap_tables(ANALYZABLE_SIGNALS);
        for ib = 1:numel(bandNames)
            band = bandNames{ib};
            ANALYZABLE_SIGNALS_BY_BAND.(band) = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.(['included_after_crosstalk_' lower(band)]) == true, :);
            RECAP_BY_BAND.(band) = build_signal_recap_tables(ANALYZABLE_SIGNALS_BY_BAND.(band));
        end

        % Backward-compatible overall variables
        RECAP_BY_AGE                = RECAP_OVERALL.by_age;
        RECAP_BY_CONDITION          = RECAP_OVERALL.by_condition;
        RECAP_BY_PAIR               = RECAP_OVERALL.by_pair;
        RECAP_BY_AGE_CONDITION      = RECAP_OVERALL.by_age_condition;
        RECAP_BY_PAIR_AGE           = RECAP_OVERALL.by_pair_age;
        RECAP_BY_PAIR_CONDITION     = RECAP_OVERALL.by_pair_condition;
        RECAP_BY_PAIR_AGE_CONDITION = RECAP_OVERALL.by_pair_age_condition;

        fprintf('\n===================== FINAL RECAP =====================\n');

        activeRules = get_active_cycle_policy_rules(P.cycle_policy);
        fprintf('Exclusion method(s) applied: %s\n', strjoin(activeRules, ", "));

        print_signal_recap_block('OVERALL', ANALYZABLE_SIGNALS, RECAP_OVERALL);
        for ib = 1:numel(bandNames)
            print_signal_recap_block(upper(bandNames{ib}), ANALYZABLE_SIGNALS_BY_BAND.(bandNames{ib}), RECAP_BY_BAND.(bandNames{ib}));
        end

    else
        ANALYZABLE_SIGNALS       = table();
        RECAP_OVERALL = init_empty_signal_recap();
        for ib = 1:numel(bandNames)
            ANALYZABLE_SIGNALS_BY_BAND.(bandNames{ib}) = table();
            RECAP_BY_BAND.(bandNames{ib}) = init_empty_signal_recap();
        end

        RECAP_BY_AGE                = table();
        RECAP_BY_CONDITION          = table();
        RECAP_BY_PAIR               = table();
        RECAP_BY_AGE_CONDITION      = table();
        RECAP_BY_PAIR_AGE           = table();
        RECAP_BY_PAIR_CONDITION     = table();
        RECAP_BY_PAIR_AGE_CONDITION = table();
    end

    %% ===================== PARTICIPANT-LEVEL RECAP =====================
    if ~isempty(ANALYZABLE_SIGNALS)

        PARTICIPANT_RECAP_OVERALL = build_participant_recap_tables(ANALYZABLE_SIGNALS);
        for ib = 1:numel(bandNames)
            PARTICIPANT_RECAP_BY_BAND.(bandNames{ib}) = build_participant_recap_tables(ANALYZABLE_SIGNALS_BY_BAND.(bandNames{ib}));
        end

        % Backward-compatible overall variables
        PARTICIPANT_SUMMARY = PARTICIPANT_RECAP_OVERALL.summary;
        RECAP_PARTICIPANTS_BY_AGE = PARTICIPANT_RECAP_OVERALL.by_age;
        RECAP_PARTICIPANTS_BY_CONDITION = PARTICIPANT_RECAP_OVERALL.by_condition;
        RECAP_PARTICIPANTS_BY_AGE_CONDITION = PARTICIPANT_RECAP_OVERALL.by_age_condition;
        RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = PARTICIPANT_RECAP_OVERALL.signals_per_participant_by_age;
        RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE = PARTICIPANT_RECAP_OVERALL.conditions_per_participant_by_age;

        fprintf('\n===================== PARTICIPANT-LEVEL RECAP =====================\n');

        print_participant_recap_block('OVERALL', PARTICIPANT_RECAP_OVERALL);
        for ib = 1:numel(bandNames)
            print_participant_recap_block(upper(bandNames{ib}), PARTICIPANT_RECAP_BY_BAND.(bandNames{ib}));
        end

    else
        PARTICIPANT_RECAP_OVERALL = init_empty_participant_recap();
        for ib = 1:numel(bandNames)
            PARTICIPANT_RECAP_BY_BAND.(bandNames{ib}) = init_empty_participant_recap();
        end

        PARTICIPANT_SUMMARY = table();
        RECAP_PARTICIPANTS_BY_AGE = table();
        RECAP_PARTICIPANTS_BY_CONDITION = table();
        RECAP_PARTICIPANTS_BY_AGE_CONDITION = table();
        RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = table();
        RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE = table();
    end


    %% ===================== PARTICIPANT-LEVEL RECAP PER PAIR =====================
    if ~isempty(ANALYZABLE_SIGNALS)

        PARTICIPANT_PAIR_RECAP_OVERALL = build_participant_pair_recap_tables(ANALYZABLE_SIGNALS);
        for ib = 1:numel(bandNames)
            PARTICIPANT_PAIR_RECAP_BY_BAND.(bandNames{ib}) = build_participant_pair_recap_tables(ANALYZABLE_SIGNALS_BY_BAND.(bandNames{ib}));
        end

        % Backward-compatible overall variables
        PARTICIPANT_SUMMARY_BY_PAIR = PARTICIPANT_PAIR_RECAP_OVERALL.summary_by_pair;
        RECAP_PARTICIPANTS_BY_PAIR = PARTICIPANT_PAIR_RECAP_OVERALL.by_pair;
        RECAP_PARTICIPANTS_BY_PAIR_AGE = PARTICIPANT_PAIR_RECAP_OVERALL.by_pair_age;
        RECAP_PARTICIPANTS_BY_PAIR_CONDITION = PARTICIPANT_PAIR_RECAP_OVERALL.by_pair_condition;
        RECAP_PARTICIPANTS_BY_PAIR_AGE_CONDITION = PARTICIPANT_PAIR_RECAP_OVERALL.by_pair_age_condition;
        RECAP_SIGNALS_PER_PARTICIPANT_BY_PAIR_AGE = PARTICIPANT_PAIR_RECAP_OVERALL.signals_per_participant_by_pair_age;
        RECAP_CONDITIONS_PER_PARTICIPANT_BY_PAIR_AGE = PARTICIPANT_PAIR_RECAP_OVERALL.conditions_per_participant_by_pair_age;

        fprintf('\n===================== PARTICIPANT-LEVEL RECAP PER PAIR =====================\n');

        print_participant_pair_recap_block('OVERALL', PARTICIPANT_PAIR_RECAP_OVERALL);
        for ib = 1:numel(bandNames)
            print_participant_pair_recap_block(upper(bandNames{ib}), PARTICIPANT_PAIR_RECAP_BY_BAND.(bandNames{ib}));
        end

    else
        PARTICIPANT_PAIR_RECAP_OVERALL = init_empty_participant_pair_recap();
        for ib = 1:numel(bandNames)
            PARTICIPANT_PAIR_RECAP_BY_BAND.(bandNames{ib}) = init_empty_participant_pair_recap();
        end

        PARTICIPANT_SUMMARY_BY_PAIR = table();
        RECAP_PARTICIPANTS_BY_PAIR = table();
        RECAP_PARTICIPANTS_BY_PAIR_AGE = table();
        RECAP_PARTICIPANTS_BY_PAIR_CONDITION = table();
        RECAP_PARTICIPANTS_BY_PAIR_AGE_CONDITION = table();
        RECAP_SIGNALS_PER_PARTICIPANT_BY_PAIR_AGE = table();
        RECAP_CONDITIONS_PER_PARTICIPANT_BY_PAIR_AGE = table();
    end

    % ---------- Everything above that is saved with FINAL_PAIRED_SIGNALS.mat ----------
    RECAPS = struct();
    RECAPS.ANALYZABLE_SIGNALS = ANALYZABLE_SIGNALS;
    RECAPS.RECAP_BY_AGE = RECAP_BY_AGE;
    RECAPS.RECAP_BY_CONDITION = RECAP_BY_CONDITION;
    RECAPS.RECAP_BY_PAIR = RECAP_BY_PAIR;
    RECAPS.RECAP_BY_AGE_CONDITION = RECAP_BY_AGE_CONDITION;
    RECAPS.RECAP_BY_PAIR_AGE = RECAP_BY_PAIR_AGE;
    RECAPS.RECAP_BY_PAIR_CONDITION = RECAP_BY_PAIR_CONDITION;
    RECAPS.RECAP_BY_PAIR_AGE_CONDITION = RECAP_BY_PAIR_AGE_CONDITION;
    RECAPS.PARTICIPANT_SUMMARY = PARTICIPANT_SUMMARY;
    RECAPS.RECAP_PARTICIPANTS_BY_AGE = RECAP_PARTICIPANTS_BY_AGE;
    RECAPS.RECAP_PARTICIPANTS_BY_CONDITION = RECAP_PARTICIPANTS_BY_CONDITION;
    RECAPS.RECAP_PARTICIPANTS_BY_AGE_CONDITION = RECAP_PARTICIPANTS_BY_AGE_CONDITION;
    RECAPS.RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE;
    RECAPS.RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE = RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE;
    RECAPS.PARTICIPANT_SUMMARY_BY_PAIR = PARTICIPANT_SUMMARY_BY_PAIR;
    RECAPS.RECAP_PARTICIPANTS_BY_PAIR = RECAP_PARTICIPANTS_BY_PAIR;
    RECAPS.RECAP_PARTICIPANTS_BY_PAIR_AGE = RECAP_PARTICIPANTS_BY_PAIR_AGE;
    RECAPS.RECAP_SIGNALS_PER_PARTICIPANT_BY_PAIR_AGE = RECAP_SIGNALS_PER_PARTICIPANT_BY_PAIR_AGE;
    RECAPS.RECAP_CONDITIONS_PER_PARTICIPANT_BY_PAIR_AGE = RECAP_CONDITIONS_PER_PARTICIPANT_BY_PAIR_AGE;
    RECAPS.ANALYZABLE_SIGNALS_BY_BAND = ANALYZABLE_SIGNALS_BY_BAND;
    RECAPS.RECAP_BY_BAND = RECAP_BY_BAND;
    RECAPS.PARTICIPANT_RECAP_BY_BAND = PARTICIPANT_RECAP_BY_BAND;
    RECAPS.PARTICIPANT_PAIR_RECAP_BY_BAND = PARTICIPANT_PAIR_RECAP_BY_BAND;
end
