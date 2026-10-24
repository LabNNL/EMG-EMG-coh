function print_mixed_spm_result_summary(spmMixedInfo, pairName)
%PRINT_MIXED_SPM_RESULT_SUMMARY Print cluster counts and p-values
% for mixed age x condition spectrum SPM.

    if isempty(spmMixedInfo) || ~isfield(spmMixedInfo, 'ok') || ~spmMixedInfo.ok
        fprintf('\nMIXED SPM SUMMARY | %s | not available\n', string(pairName));
        return;
    end

    effectNames = {'AGE main effect', 'CONDITION main effect', 'AGE x CONDITION interaction'};
    effectFields = {'spmi_age', 'spmi_condition', 'spmi_interaction'};

    fprintf('\n=== MIXED SPM RESULT SUMMARY | %s ===\n', string(pairName));
    fprintf('n subjects = %d | n rows = %d\n', spmMixedInfo.n_subjects, spmMixedInfo.n_rows);

    for i = 1:numel(effectFields)

        f = effectFields{i};
        fprintf('\n%s:\n', effectNames{i});

        if ~isfield(spmMixedInfo, f) || isempty(spmMixedInfo.(f))
            fprintf('  no result\n');
            continue;
        end

        spmi = spmMixedInfo.(f);

        try
            clusters = spmi.clusters;
            fprintf('  clusters: %d\n', numel(clusters));

            for ic = 1:numel(clusters)
                % spmi.clusters is a cell array; indexing it with () gave a
                % 1x1 cell and so always printed p = NaN.
                pval = get_cluster_p(clusters, ic);
                fprintf('    cluster %d: p = %.4g\n', ic, pval);
            end

        catch ME
            fprintf('  could not read clusters: %s\n', ME.message);
        end
    end

    fprintf('=========================================\n');
end