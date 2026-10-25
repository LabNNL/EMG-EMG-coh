function h_band_triplet_figures(T_subj, C, HC, CONTINUOUS_AGE_LME_TABLE)
% H_BAND_TRIPLET_FIGURES  One boxplot figure per pair, metric family and grouping,
% one panel per band, annotated with the primary model's Holm-adjusted p-values.

    %% ===================== PLOTS =====================

    if HC.plot.enable
        fprintf('\nGenerating plots...\n');

        scopeLabelFile = char(lower(string(HC.analysis.metric_scope)));

        if isfield(HC.analysis, 'metric_type_for_plots') && ~isempty(HC.analysis.metric_type_for_plots)
            metricTypes = HC.analysis.metric_type_for_plots;
        else
            metricTypes = {'mean','auc','peak'};
        end
        plotTypes = { 'condition',     'BY_CONDITION'; 'age',           'BY_AGE'; 'age_condition', 'BY_AGE_AND_CONDITION'; 'condition_age', 'BY_CONDITION_AND_AGE' };

        if ~exist('CONTINUOUS_AGE_LME_TABLE', 'var')
            CONTINUOUS_AGE_LME_TABLE = table();
        end

        for ip = 1:numel(HC.analysis.pairs_to_analyze)
            pairName = string(HC.analysis.pairs_to_analyze{ip});
            Tp = T_subj(T_subj.pair_name == pairName, :);

            if isempty(Tp)
                continue;
            end

            for im = 1:numel(metricTypes)
                metricType = metricTypes{im};
                metricLabel = upper(metricType);

                for it = 1:size(plotTypes, 1)
                    plotType = plotTypes{it, 1};
                    plotLabel = plotTypes{it, 2};

                    make_band_triplet_figure( Tp, pairName, metricType, plotType, fullfile(HC.io.band_triplet_dir, sprintf('TRIPLET_%s__%s__%s__%s_%s.png', metricLabel, pairName, scopeLabelFile, plotLabel, HC.analysis.cycle_triplet_source)), HC.plot.visible, C, HC, CONTINUOUS_AGE_LME_TABLE);
                end
            end
        end
    end
end
