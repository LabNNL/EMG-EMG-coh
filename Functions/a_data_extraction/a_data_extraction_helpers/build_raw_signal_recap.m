function RAW = build_raw_signal_recap(Participants, OUT_DIR, RESULTS_DIR, RCP, C)
%BUILD_RAW_SIGNAL_RECAP Build, display, and save raw signal recap tables.
%
% Inputs
%   Participants - cell array of participant IDs
%   OUT_DIR      - folder containing *_RAW_CYCLES_CONCAT.mat files
%   RESULTS_DIR  - results output folder (for display only)
%   RCP          - struct with CSV output paths
%   C            - config struct (used by subject_to_group)
%
% Output
%   RAW          - struct containing all recap tables
%
% Fields in RAW:
%   .RAW_SIGNAL_SUMMARY
%   .RAW_RECAP_BY_AGE
%   .RAW_RECAP_BY_CONDITION
%   .RAW_RECAP_BY_AGE_CONDITION
%   .RAW_PARTICIPANT_SUMMARY
%   .RAW_RECAP_PARTICIPANTS_BY_AGE
%   .RAW_RECAP_PARTICIPANTS_BY_CONDITION
%   .RAW_RECAP_PARTICIPANTS_BY_AGE_CONDITION
%   .RAW_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE
%   .RAW_RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE
%   .RAW_RECAP_CYCLES_PER_PARTICIPANT_BY_AGE

fprintf('\n=== RAW SIGNAL / PARTICIPANT RECAP ===\n');

%% ---------------- Build RAW_SIGNAL_SUMMARY ----------------
RAW_SIGNAL_ROWS = {};
riRaw = 0;


for iP = 1:numel(Participants)
    subjID = Participants{iP};
    raw_file = fullfile(OUT_DIR, sprintf('%s_RAW_CYCLES_CONCAT.mat', subjID));

    if ~isfile(raw_file)
        continue;
    end

    S = load(raw_file);

    if ~isfield(S, 'CYCLES_SIGNAL_RAW')
        continue;
    end

    subjList = fieldnames(S.CYCLES_SIGNAL_RAW);

    for iSub = 1:numel(subjList)

        subj = subjList{iSub};
        subj_struct = S.CYCLES_SIGNAL_RAW.(subj);

        condList = fieldnames(subj_struct);

        for iC = 1:numel(condList)

            cond = condList{iC};
            cond_struct = subj_struct.(cond);

            legList = fieldnames(cond_struct);

            for iL = 1:numel(legList)

                leg = legList{iL};
                leg_struct = cond_struct.(leg);

                musFields = fieldnames(leg_struct);

                for iM = 1:numel(musFields)

                    musField = musFields{iM};

                    % Only keep *_Concat fields
                    if ~endsWith(musField, '_Concat')
                        continue;
                    end

                    musName = erase(musField, '_Concat');

                    data = leg_struct.(musField);

                    if ~isfield(data, 'signal') || isempty(data.signal)
                        continue;
                    end

                    % === Build row ===
                    riRaw = riRaw + 1;

                    RAW_SIGNAL_ROWS(riRaw,:) = {
                        string(subj), ...
                        subject_to_group(subj, C), ...
                        string(cond), ...
                        string(leg), ...
                        string(musName), ...
                        data.n_cycles, ...
                        numel(data.signal), ...
                        isfield(data, 'toe_off_concat'), ...
                        sum(~isnan(data.toe_off_concat))
                    };

                end
            end
        end
    end
end

if ~isempty(RAW_SIGNAL_ROWS)
    RAW_SIGNAL_SUMMARY = cell2table(RAW_SIGNAL_ROWS, 'VariableNames', { ...
        'subject','age_group','condition','leg','muscle', ...
        'n_cycles','signal_length','has_toe_off','n_toe_off'});
else
    RAW_SIGNAL_SUMMARY = table( ...
        string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        zeros(0,1), zeros(0,1), false(0,1), zeros(0,1), ...
        'VariableNames', {'subject','age_group','condition','leg','muscle', ...
                          'n_cycles','signal_length','has_toe_off','n_toe_off'});
end

fprintf('Raw signal summary rows: %d\n', height(RAW_SIGNAL_SUMMARY));

%% ---------------- Signal-level + participant-level recaps ----------------
if ~isempty(RAW_SIGNAL_SUMMARY)

    RAW_RECAP_BY_AGE = groupcounts(RAW_SIGNAL_SUMMARY, 'age_group');
    RAW_RECAP_BY_AGE.Properties.VariableNames{'GroupCount'} = 'n_signals';

    RAW_RECAP_BY_CONDITION = groupcounts(RAW_SIGNAL_SUMMARY, 'condition');
    RAW_RECAP_BY_CONDITION.Properties.VariableNames{'GroupCount'} = 'n_signals';

    RAW_RECAP_BY_AGE_CONDITION = groupcounts(RAW_SIGNAL_SUMMARY, {'age_group','condition'});
    RAW_RECAP_BY_AGE_CONDITION.Properties.VariableNames{'GroupCount'} = 'n_signals';

    % ---------------- Participant summary ----------------
    subjList = unique(RAW_SIGNAL_SUMMARY.subject);
    RAW_PARTICIPANT_ROWS = {};
    riSub = 0;

    for iSub = 1:numel(subjList)
        subj = subjList(iSub);
        Ts = RAW_SIGNAL_SUMMARY(RAW_SIGNAL_SUMMARY.subject == subj, :);

        age_group = "Unknown";
        if ~isempty(Ts.age_group)
            age_group = Ts.age_group(1);
        end

        conds = unique(Ts.condition);
        legs = unique(Ts.leg);
        muscles = unique(Ts.muscle);

        n_cycles_total = sum(Ts.n_cycles, 'omitnan');

        riSub = riSub + 1;
        RAW_PARTICIPANT_ROWS(riSub,:) = { ...
            string(subj), string(age_group), ...
            height(Ts), numel(conds), numel(legs), numel(muscles), ...
            n_cycles_total, ...
            strjoin(string(conds), ","), ...
            strjoin(string(legs), ","), ...
            strjoin(string(muscles), ",") ...
            };
    end

    RAW_PARTICIPANT_SUMMARY = cell2table(RAW_PARTICIPANT_ROWS, 'VariableNames', { ...
        'subject','age_group','n_signals','n_conditions','n_legs','n_muscles', ...
        'n_cycles_total','conditions_list','legs_list','muscles_list'});

    % ---------------- Participant-level recaps ----------------
    RAW_RECAP_PARTICIPANTS_BY_AGE = groupcounts(RAW_PARTICIPANT_SUMMARY, 'age_group');
    RAW_RECAP_PARTICIPANTS_BY_AGE.Properties.VariableNames{'GroupCount'} = 'n_participants';

    subj_cond = unique(RAW_SIGNAL_SUMMARY(:, {'subject','condition'}));
    RAW_RECAP_PARTICIPANTS_BY_CONDITION = groupcounts(subj_cond, 'condition');
    RAW_RECAP_PARTICIPANTS_BY_CONDITION.Properties.VariableNames{'GroupCount'} = 'n_participants';

    subj_age_cond = unique(RAW_SIGNAL_SUMMARY(:, {'subject','age_group','condition'}));
    RAW_RECAP_PARTICIPANTS_BY_AGE_CONDITION = groupcounts(subj_age_cond, {'age_group','condition'});
    RAW_RECAP_PARTICIPANTS_BY_AGE_CONDITION.Properties.VariableNames{'GroupCount'} = 'n_participants';

    RAW_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = groupsummary(RAW_PARTICIPANT_SUMMARY, 'age_group', ...
        {'mean','median','min','max'}, 'n_signals');

    RAW_RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE = groupsummary(RAW_PARTICIPANT_SUMMARY, 'age_group', ...
        {'mean','median','min','max'}, 'n_conditions');

    RAW_RECAP_CYCLES_PER_PARTICIPANT_BY_AGE = groupsummary(RAW_PARTICIPANT_SUMMARY, 'age_group', ...
        {'mean','median','min','max'}, 'n_cycles_total');

    % ---------------- Display ----------------
    fprintf('\n--- RAW signal-level recap ---\n');
    fprintf('Total raw signals: %d\n', height(RAW_SIGNAL_SUMMARY));

    fprintf('\nBy age group:\n');
    disp(RAW_RECAP_BY_AGE);

    fprintf('\nBy condition:\n');
    disp(RAW_RECAP_BY_CONDITION);

    fprintf('\nBy age group x condition:\n');
    disp(RAW_RECAP_BY_AGE_CONDITION);

    fprintf('\n--- RAW participant-level recap ---\n');
    fprintf('Total participants with at least one raw signal: %d\n', height(RAW_PARTICIPANT_SUMMARY));

    fprintf('\nParticipants by age group:\n');
    disp(RAW_RECAP_PARTICIPANTS_BY_AGE);

    fprintf('\nParticipants by condition:\n');
    disp(RAW_RECAP_PARTICIPANTS_BY_CONDITION);

    fprintf('\nParticipants by age group x condition:\n');
    disp(RAW_RECAP_PARTICIPANTS_BY_AGE_CONDITION);

    fprintf('\nSignals per participant by age group:\n');
    disp(RAW_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE);

    fprintf('\nConditions per participant by age group:\n');
    disp(RAW_RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE);

    fprintf('\nCycles per participant by age group:\n');
    disp(RAW_RECAP_CYCLES_PER_PARTICIPANT_BY_AGE);

else
    RAW_RECAP_BY_AGE = table();
    RAW_RECAP_BY_CONDITION = table();
    RAW_RECAP_BY_AGE_CONDITION = table();

    RAW_PARTICIPANT_SUMMARY = table();
    RAW_RECAP_PARTICIPANTS_BY_AGE = table();
    RAW_RECAP_PARTICIPANTS_BY_CONDITION = table();
    RAW_RECAP_PARTICIPANTS_BY_AGE_CONDITION = table();

    RAW_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = table();
    RAW_RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE = table();
    RAW_RECAP_CYCLES_PER_PARTICIPANT_BY_AGE = table();
end

%% ---------------- Save raw recap tables ----------------
if ~isempty(RAW_SIGNAL_SUMMARY)
    writetable(RAW_SIGNAL_SUMMARY, RCP.raw_signal_summary_csv);
    writetable(RAW_PARTICIPANT_SUMMARY, RCP.raw_participant_summary_csv);

    writetable(RAW_RECAP_BY_AGE, RCP.recap_by_age_csv);
    writetable(RAW_RECAP_BY_CONDITION, RCP.recap_by_condition_csv);
    writetable(RAW_RECAP_BY_AGE_CONDITION, RCP.recap_by_age_condition_csv);

    writetable(RAW_RECAP_PARTICIPANTS_BY_AGE, RCP.recap_participants_by_age_csv);
    writetable(RAW_RECAP_PARTICIPANTS_BY_CONDITION, RCP.recap_participants_by_condition_csv);
    writetable(RAW_RECAP_PARTICIPANTS_BY_AGE_CONDITION, RCP.recap_participants_by_age_condition_csv);

    writetable(RAW_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE, RCP.recap_signals_per_participant_age_csv);
    writetable(RAW_RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE, RCP.recap_conditions_per_participant_age_csv);
    writetable(RAW_RECAP_CYCLES_PER_PARTICIPANT_BY_AGE, RCP.recap_cycles_per_participant_age_csv);

    fprintf('\nRaw recap tables saved in:\n%s\n', RESULTS_DIR);
end

%% ---------------- Package outputs ----------------
RAW = struct();
RAW.RAW_SIGNAL_SUMMARY = RAW_SIGNAL_SUMMARY;

RAW.RAW_RECAP_BY_AGE = RAW_RECAP_BY_AGE;
RAW.RAW_RECAP_BY_CONDITION = RAW_RECAP_BY_CONDITION;
RAW.RAW_RECAP_BY_AGE_CONDITION = RAW_RECAP_BY_AGE_CONDITION;

RAW.RAW_PARTICIPANT_SUMMARY = RAW_PARTICIPANT_SUMMARY;
RAW.RAW_RECAP_PARTICIPANTS_BY_AGE = RAW_RECAP_PARTICIPANTS_BY_AGE;
RAW.RAW_RECAP_PARTICIPANTS_BY_CONDITION = RAW_RECAP_PARTICIPANTS_BY_CONDITION;
RAW.RAW_RECAP_PARTICIPANTS_BY_AGE_CONDITION = RAW_RECAP_PARTICIPANTS_BY_AGE_CONDITION;

RAW.RAW_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE = RAW_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE;
RAW.RAW_RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE = RAW_RECAP_CONDITIONS_PER_PARTICIPANT_BY_AGE;
RAW.RAW_RECAP_CYCLES_PER_PARTICIPANT_BY_AGE = RAW_RECAP_CYCLES_PER_PARTICIPANT_BY_AGE;
end