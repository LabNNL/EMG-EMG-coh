function RECAP = save_and_display_recaps(log_rows, trial_rows, trial_headers, OUT_DIR, RESULTS_DIR, ...
    COHERENCE_READY, COHERENCE_SUMMARY, COH_THEORETICAL_BY_PAIR, ...
    COH_RECAP_BY_PAIR, COH_RECAP_BY_PAIR_CONDITION, COH_RECAP_BY_PAIR_AGE, COH_RECAP_BY_PAIR_AGE_CONDITION, ...
    COH_PARTICIPANT_SUMMARY, COH_RECAP_PARTICIPANTS_BY_AGE, COH_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE)
%SAVE_AND_DISPLAY_RECAPS Save logs / trial recap / coherence recap and display summaries.
%
% Output:
%   RECAP.LOG
%   RECAP.LOG_ISSUES
%   RECAP.TRIAL_RECAP

fprintf('\n=== RECAP ===\n');

%% ---------------- Build log table ----------------
if ~isempty(log_rows)
    LOG = cell2table(log_rows, 'VariableNames', ...
        {'timestamp','severity','event_type','participant','condition', ...
         'trial','leg','muscle','file_name','file_path','reason','details'});
else
    LOG = table();
end

%% ---------------- Save logs ----------------
log_csv_all = fullfile(RESULTS_DIR, 'processing_log_all.csv');
log_csv_issues = fullfile(RESULTS_DIR, 'processing_issues_only.csv');

LOG_ISSUES = table();

if ~isempty(LOG)
    try
        writetable(LOG, log_csv_all);
        fprintf('Log complet sauvegardé: %s\n', log_csv_all);
    catch ME
        warning('Erreur lors de la sauvegarde du log complet: %s', ME.message);
    end

    issues_mask = ismember(LOG.severity, {'WARN','ERROR'});
    LOG_ISSUES = LOG(issues_mask, :);

    try
        writetable(LOG_ISSUES, log_csv_issues);
        fprintf('Log des anomalies sauvegardé: %s\n', log_csv_issues);
    catch ME
        warning('Erreur lors de la sauvegarde du log des anomalies: %s', ME.message);
    end
else
    fprintf('Aucun événement enregistré dans le log.\n');
end

%% ---------------- Count generated .mat files ----------------
mat_files = dir(fullfile(OUT_DIR, '*_RAW_CYCLES_CONCAT.mat'));
fprintf('Fichiers .mat générés: %d\n', numel(mat_files));

%% ---------------- Display log summaries ----------------
if ~isempty(LOG)
    fprintf('\n--- Résumé par sévérité ---\n');
    sev = groupsummary(LOG, 'severity');
    disp(sev(:, {'severity','GroupCount'}));

    fprintf('\n--- Résumé par type d événement ---\n');
    evt = groupsummary(LOG, 'event_type');
    evt = sortrows(evt, 'GroupCount', 'descend');
    disp(evt(:, {'event_type','GroupCount'}));

    fprintf('\n--- Résumé des anomalies par participant ---\n');
    if ~isempty(LOG_ISSUES)
        part = groupsummary(LOG_ISSUES, 'participant');
        part = sortrows(part, 'GroupCount', 'descend');
        disp(part(:, {'participant','GroupCount'}));
    else
        fprintf('Aucune anomalie WARN/ERROR détectée.\n');
    end
end

%% ---------------- Save trial recap ----------------
TRIAL_RECAP = table();

if ~isempty(trial_rows)
    TRIAL_RECAP = cell2table(trial_rows, 'VariableNames', trial_headers);
    trial_csv = fullfile(RESULTS_DIR, 'trial_recap.csv');

    try
        writetable(TRIAL_RECAP, trial_csv);
        fprintf('Récapitulatif par essai sauvegardé: %s\n', trial_csv);
    catch ME
        warning('Erreur lors de la sauvegarde du récapitulatif par essai: %s', ME.message);
    end
else
    fprintf('Aucun récapitulatif par essai à sauvegarder.\n');
end

%% ---------------- Save coherence recap ----------------
if ~isempty(COHERENCE_READY)
    try
        writetable(COHERENCE_SUMMARY, fullfile(RESULTS_DIR, 'coherence_summary_all_pairs.csv'));
        writetable(COHERENCE_READY, fullfile(RESULTS_DIR, 'coherence_ready_all_pairs.csv'));

        writetable(COH_THEORETICAL_BY_PAIR, fullfile(RESULTS_DIR, 'coherence_theoretical_by_pair.csv'));

        writetable(COH_RECAP_BY_PAIR, fullfile(RESULTS_DIR, 'coherence_recap_by_pair.csv'));
        writetable(COH_RECAP_BY_PAIR_CONDITION, fullfile(RESULTS_DIR, 'coherence_recap_by_pair_condition.csv'));
        writetable(COH_RECAP_BY_PAIR_AGE, fullfile(RESULTS_DIR, 'coherence_recap_by_pair_age.csv'));
        writetable(COH_RECAP_BY_PAIR_AGE_CONDITION, fullfile(RESULTS_DIR, 'coherence_recap_by_pair_age_condition.csv'));

        writetable(COH_PARTICIPANT_SUMMARY, fullfile(RESULTS_DIR, 'coherence_participant_summary.csv'));
        writetable(COH_RECAP_PARTICIPANTS_BY_AGE, fullfile(RESULTS_DIR, 'coherence_recap_participants_by_age.csv'));
        writetable(COH_RECAP_SIGNALS_PER_PARTICIPANT_BY_AGE, fullfile(RESULTS_DIR, 'coherence_recap_signals_per_participant_by_age.csv'));

        fprintf('\nCoherence recap tables saved in:\n%s\n', RESULTS_DIR);
    catch ME
        warning('Erreur lors de la sauvegarde des tables de cohérence: %s', ME.message);
    end
else
    fprintf('Aucune table de cohérence à sauvegarder.\n');
end

%% ---------------- Package outputs ----------------
RECAP = struct();
RECAP.LOG = LOG;
RECAP.LOG_ISSUES = LOG_ISSUES;
RECAP.TRIAL_RECAP = TRIAL_RECAP;
RECAP.MAT_FILES = mat_files;

end