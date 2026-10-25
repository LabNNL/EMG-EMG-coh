function h_sample_recap(T_row, T_subj, HC, ANALYSIS_TAG, bandSource)
% H_SAMPLE_RECAP  Text summary of the sample and settings (SAMPLE_RECAP.txt).

    bandNames = fieldnames(bandSource)';
    includeCycleCov = isfield(HC.analysis, 'include_cycle_count_covariate') && HC.analysis.include_cycle_count_covariate;

    %% ===================== SAMPLE RECAP =====================

    fprintf('\nBuilding sample recap...\n');

    sample_txt = fullfile(HC.io.tables_dir, 'SAMPLE_RECAP.txt');
    fid = fopen(sample_txt, 'w');

    fprintf(fid, '=== SAMPLE RECAP ===\n\n');
    fprintf(fid, 'Rows before leg averaging: %d\n', height(T_row));
    fprintf(fid, 'Rows after leg averaging:  %d\n\n', height(T_subj));

    fprintf(fid, 'Unique subjects overall: %d\n\n', numel(unique(T_subj.subject)));

    fprintf(fid, '--- Subjects by age group ---\n');
    disp_to_file(fid, groupcounts_table(T_subj, {'age_group'}));

    fprintf(fid, '\n--- Rows by pair ---\n');
    disp_to_file(fid, groupcounts_table(T_subj, {'pair_name'}));

    fprintf(fid, '\n--- Rows by pair x age_group ---\n');
    disp_to_file(fid, groupcounts_table(T_subj, {'pair_name','age_group'}));

    fprintf(fid, '\n--- Rows by pair x condition ---\n');
    disp_to_file(fid, groupcounts_table(T_subj, {'pair_name','condition'}));

    fprintf(fid, '\n--- Rows by pair x age_group x condition ---\n');
    disp_to_file(fid, groupcounts_table(T_subj, {'pair_name','age_group','condition'}));

    for ib = 1:numel(bandNames)
        fprintf(fid, '%s source: %s\n', bandNames{ib}, bandSource.(bandNames{ib}));
    end
    fprintf(fid, '\n');

    fprintf(fid, 'Coherence source: %s\n', string(HC.analysis.coherence_source));
    fprintf(fid, 'Metric scope: %s\n', string(HC.analysis.metric_scope));
    fprintf(fid, 'Include cycle-count covariate: %d\n', includeCycleCov);

    if isfield(HC.analysis, 'scalar_metric_families')
        fprintf(fid, 'Scalar metric families: %s\n', strjoin(string(HC.analysis.scalar_metric_families), ', '));
    end

    fprintf(fid, 'Dependent variables analyzed:\n');
    for iDV = 1:numel(HC.analysis.dv_list)
        fprintf(fid, '  - %s\n', string(HC.analysis.dv_list{iDV}));
    end

    fprintf(fid, 'Cycle-count covariate requested: %d\n', includeCycleCov);

    fprintf(fid, 'Band-specific cycle-count variables:\n');
    for ib = 1:numel(bandNames)
        fprintf(fid, '  - %s_log_n_cycles from %s_mean_cycles_used_for_metric_across_legs\n', bandNames{ib}, bandNames{ib});
    end

    fprintf(fid, '\nCycle-count source examples in T_row:\n');

    for ib = 1:numel(bandNames)
        v = [bandNames{ib} '_cycle_count_source'];
        if ismember(v, T_row.Properties.VariableNames)
            fprintf(fid, '  %s sources: %s\n', bandNames{ib}, strjoin(unique(string(T_row.(v))), ', '));
        end
    end

    fprintf(fid, 'Analysis tag: %s\n\n', ANALYSIS_TAG);

    fclose(fid);
end
