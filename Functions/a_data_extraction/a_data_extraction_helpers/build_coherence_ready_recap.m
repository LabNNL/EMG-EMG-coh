function COH = build_coherence_ready_recap(RAW_SIGNAL_SUMMARY, C)
%BUILD_COHERENCE_READY_RECAP Build coherence-ready recap for all muscle pairs
%
% Input:
%   RAW_SIGNAL_SUMMARY
%   C (config with pairs)
%
% Output:
%   COH struct with all recap tables

fprintf('\n=== COHERENCE-READY RECAP (ALL CONFIGURED PAIRS) ===\n');

if isempty(RAW_SIGNAL_SUMMARY) || height(RAW_SIGNAL_SUMMARY) == 0

    fprintf('RAW_SIGNAL_SUMMARY is empty. No coherence-ready recap can be built.\n');

    COH = struct();
    COH.COHERENCE_SUMMARY = table();
    COH.COHERENCE_READY = table();
    COH.COH_THEORETICAL_BY_PAIR = table();
    COH.COH_RECAP_BY_PAIR = table();
    COH.COH_RECAP_BY_PAIR_CONDITION = table();
    COH.COH_RECAP_BY_PAIR_AGE = table();
    COH.COH_RECAP_BY_PAIR_AGE_CONDITION = table();
    COH.COH_PARTICIPANT_SUMMARY = table();
    COH.COH_RECAP_PARTICIPANTS_BY_AGE = table();
    COH.COH_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = table();
    COH.n_signals_coherence_total = 0;
    COH.n_possible_per_pair = 0;
    COH.n_possible_total_all_pairs = 0;
    return;
end

PAIR_DEFS = C.f_final_signals.params.pairs;
nPairs = numel(PAIR_DEFS);

COH_ROWS = {};
riCoh = 0;

BASE_COMBOS = unique(RAW_SIGNAL_SUMMARY(:, {'subject','age_group','condition','leg'}));
n_possible_per_pair = height(BASE_COMBOS);
n_possible_total_all_pairs = n_possible_per_pair * nPairs;

pair_names = strings(nPairs,1);
for iPair = 1:nPairs
    pair_names(iPair) = string(PAIR_DEFS{iPair}.name);
end

COH_THEORETICAL_BY_PAIR = table(pair_names, repmat(n_possible_per_pair, nPairs, 1), ...
    'VariableNames', {'pair_name','n_signals_theoretical_max'});

fprintf('\nPossible subject x condition x leg combinations: %d\n', n_possible_per_pair);
fprintf('Configured muscle pairs: %d\n', nPairs);
fprintf('Theoretical maximum across all pairs: %d\n', n_possible_total_all_pairs);

%% ===================== BUILD COHERENCE TABLE =====================
for iPair = 1:nPairs
    pair_name = string(PAIR_DEFS{iPair}.name);
    pair_muscles = string(PAIR_DEFS{iPair}.muscles);

    if numel(pair_muscles) ~= 2
        warning('Pair %s invalid (not 2 muscles). Skipping.', pair_name);
        continue;
    end

    mus1 = pair_muscles(1);
    mus2 = pair_muscles(2);

    Tpair = RAW_SIGNAL_SUMMARY(ismember(string(RAW_SIGNAL_SUMMARY.muscle), [mus1, mus2]), :);
    if isempty(Tpair), continue; end

    [G, subj_g, age_g, cond_g, leg_g] = findgroups( ...
        string(Tpair.subject), ...
        string(Tpair.age_group), ...
        string(Tpair.condition), ...
        string(Tpair.leg));

    for g = 1:max(G)
        Tg = Tpair(G == g, :);
        mus_present = unique(string(Tg.muscle));

        has_mus1 = any(mus_present == mus1);
        has_mus2 = any(mus_present == mus2);
        is_ready = has_mus1 && has_mus2;

        riCoh = riCoh + 1;
        COH_ROWS(riCoh,:) = { ...
            pair_name, subj_g(g), age_g(g), cond_g(g), leg_g(g), ...
            mus1, mus2, has_mus1, has_mus2, is_ready ...
        };
    end
end

%% ===================== BUILD TABLES =====================
if ~isempty(COH_ROWS)

    COHERENCE_SUMMARY = cell2table(COH_ROWS, 'VariableNames', { ...
        'pair_name','subject','age_group','condition','leg', ...
        'muscle_1','muscle_2','has_muscle_1','has_muscle_2','is_coherence_ready'});

    COHERENCE_READY = COHERENCE_SUMMARY(COHERENCE_SUMMARY.is_coherence_ready, :);

    n_signals_coherence_total = height(COHERENCE_READY);

    COH_RECAP_BY_PAIR = groupcounts(COHERENCE_READY, 'pair_name');
    COH_RECAP_BY_PAIR.Properties.VariableNames{'GroupCount'} = 'n_signals';

    COH_RECAP_BY_PAIR_CONDITION = groupcounts(COHERENCE_READY, {'pair_name','condition'});
    COH_RECAP_BY_PAIR_CONDITION.Properties.VariableNames{'GroupCount'} = 'n_signals';

    COH_RECAP_BY_PAIR_AGE = groupcounts(COHERENCE_READY, {'pair_name','age_group'});
    COH_RECAP_BY_PAIR_AGE.Properties.VariableNames{'GroupCount'} = 'n_signals';

    COH_RECAP_BY_PAIR_AGE_CONDITION = groupcounts(COHERENCE_READY, {'pair_name','age_group','condition'});
    COH_RECAP_BY_PAIR_AGE_CONDITION.Properties.VariableNames{'GroupCount'} = 'n_signals';

    % Participant-level
    subjList = unique(COHERENCE_READY.subject);
    COH_PARTICIPANT_ROWS = {};

    for iSub = 1:numel(subjList)
        subj = subjList(iSub);
        Ts = COHERENCE_READY(COHERENCE_READY.subject == subj, :);

        age_group = Ts.age_group(1);
        pair_list = unique(string(Ts.pair_name));
        conds = unique(string(Ts.condition));
        legs = unique(string(Ts.leg));

        COH_PARTICIPANT_ROWS(end+1,:) = { ...
            string(subj), age_group, ...
            height(Ts), numel(pair_list), numel(conds), numel(legs), ...
            strjoin(pair_list, ","), ...
            strjoin(conds, ","), ...
            strjoin(legs, ",") ...
        };
    end

    COH_PARTICIPANT_SUMMARY = cell2table(COH_PARTICIPANT_ROWS, 'VariableNames', { ...
        'subject','age_group','n_signals_coherence','n_pairs','n_conditions','n_legs', ...
        'pairs_list','conditions_list','legs_list'});

    COH_RECAP_PARTICIPANTS_BY_AGE = groupcounts(unique(COHERENCE_READY(:, {'subject','age_group'})), 'age_group');
    COH_RECAP_PARTICIPANTS_BY_AGE.Properties.VariableNames{'GroupCount'} = 'n_participants';

    COH_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = groupsummary( ...
        COH_PARTICIPANT_SUMMARY, 'age_group', ...
        {'mean','median','min','max'}, 'n_signals_coherence');


else
    COHERENCE_SUMMARY = table();
    COHERENCE_READY = table();
    COH_RECAP_BY_PAIR = table();
    COH_RECAP_BY_PAIR_CONDITION = table();
    COH_RECAP_BY_PAIR_AGE = table();
    COH_RECAP_BY_PAIR_AGE_CONDITION = table();
    COH_PARTICIPANT_SUMMARY = table();
    COH_RECAP_PARTICIPANTS_BY_AGE = table();
    COH_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = table();
    n_signals_coherence_total = 0;
end

%% ===================== DISPLAY =====================
fprintf('\nTotal coherence-ready signals: %d\n', n_signals_coherence_total);
fprintf('Max per pair: %d\n', n_possible_per_pair);
fprintf('Max across pairs: %d\n', n_possible_total_all_pairs);

%% ===================== OUTPUT STRUCT =====================
COH = struct();

COH.COHERENCE_SUMMARY = COHERENCE_SUMMARY;
COH.COHERENCE_READY = COHERENCE_READY;

COH.COH_RECAP_BY_PAIR = COH_RECAP_BY_PAIR;
COH.COH_RECAP_BY_PAIR_CONDITION = COH_RECAP_BY_PAIR_CONDITION;
COH.COH_RECAP_BY_PAIR_AGE = COH_RECAP_BY_PAIR_AGE;
COH.COH_RECAP_BY_PAIR_AGE_CONDITION = COH_RECAP_BY_PAIR_AGE_CONDITION;

COH.COH_PARTICIPANT_SUMMARY = COH_PARTICIPANT_SUMMARY;
COH.COH_RECAP_PARTICIPANTS_BY_AGE = COH_RECAP_PARTICIPANTS_BY_AGE;
COH.COH_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = COH_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE;

COH.n_signals_coherence_total = n_signals_coherence_total;
COH.n_possible_per_pair = n_possible_per_pair;
COH.n_possible_total_all_pairs = n_possible_total_all_pairs;
COH.COH_THEORETICAL_BY_PAIR = COH_THEORETICAL_BY_PAIR;

end