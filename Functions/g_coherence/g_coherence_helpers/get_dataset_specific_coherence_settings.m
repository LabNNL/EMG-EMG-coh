function DS = get_dataset_specific_coherence_settings(datasetName, W, GP)

    % Global full-band range across all defined bands
    bandNames = fieldnames(W.FreqBands);
    allMins = zeros(numel(bandNames),1);
    allMaxs = zeros(numel(bandNames),1);

    for i = 1:numel(bandNames)
        allMins(i) = W.FreqBands.(bandNames{i})(1);
        allMaxs(i) = W.FreqBands.(bandNames{i})(2);
    end

    FullBandRange = [min(allMins) max(allMaxs)];

    DS = struct();

    switch upper(char(datasetName))

        case 'FULL'
            DS.summaryScalarVars_this = { ...
                'Alpha','Beta','Gamma', ...
                'Alpha_AUC_norm','Beta_AUC_norm','Gamma_AUC_norm', ...
                'Alpha_Peak','Beta_Peak','Gamma_Peak', ...
                'Alpha_POI','Beta_POI','Gamma_POI', ...
                'Alpha_AUC_norm_POI','Beta_AUC_norm_POI','Gamma_AUC_norm_POI', ...
                'Alpha_Peak_POI','Beta_Peak_POI','Gamma_Peak_POI', ...
                'FullBand_Mean','FullBand_AUC_norm','FullBand_Peak', ...
                'FullBand_Mean_POI','FullBand_AUC_norm_POI','FullBand_Peak_POI'};

            DS.scalar_plot_sets_this = GP.scalar_plot_sets;
            DS.FreqMin_this = W.FreqMin;
            DS.FreqMax_this = W.FreqMax;
            DS.FreqBands_this = W.FreqBands;
            DS.FullBandRange_this = FullBandRange;
            DS.computeFullBandMetrics = true;

        case 'ALPHA'
            DS.summaryScalarVars_this = { ...
                'Alpha','Alpha_AUC_norm','Alpha_Peak', ...
                'Alpha_POI','Alpha_AUC_norm_POI','Alpha_Peak_POI'};
            DS.scalar_plot_sets_this = {{'Alpha','Alpha_AUC_norm','Alpha_Peak'}, ...
                                    {'Alpha_POI','Alpha_AUC_norm_POI','Alpha_Peak_POI'}};
            DS.FreqMin_this = W.FreqBands.Alpha(1);
            DS.FreqMax_this = W.FreqBands.Alpha(2);
            DS.FreqBands_this = struct('Alpha', W.FreqBands.Alpha);
            DS.FullBandRange_this = W.FreqBands.Alpha;
            DS.computeFullBandMetrics = false;

        case 'BETA'
            DS.summaryScalarVars_this = { ...
                'Beta','Beta_AUC_norm','Beta_Peak', ...
                'Beta_POI','Beta_AUC_norm_POI','Beta_Peak_POI'};
            DS.scalar_plot_sets_this = {{'Beta','Beta_AUC_norm','Beta_Peak'}, ...
                                    {'Beta_POI','Beta_AUC_norm_POI','Beta_Peak_POI'}};
            DS.FreqMin_this = W.FreqBands.Beta(1);
            DS.FreqMax_this = W.FreqBands.Beta(2);
            DS.FreqBands_this = struct('Beta', W.FreqBands.Beta);
            DS.FullBandRange_this = W.FreqBands.Beta;
            DS.computeFullBandMetrics = false;

        case 'GAMMA'
            DS.summaryScalarVars_this = {'Gamma','Gamma_AUC_norm', 'Gamma_Peak', ...
                                        'Gamma_POI','Gamma_AUC_norm_POI','Gamma_Peak_POI'};
            DS.scalar_plot_sets_this = {{'Gamma','Gamma_AUC_norm', 'Gamma_Peak'}, ...
                                    {'Gamma_POI','Gamma_AUC_norm_POI','Gamma_Peak_POI'}};
            DS.FreqMin_this = W.FreqBands.Gamma(1);
            DS.FreqMax_this = W.FreqBands.Gamma(2);
            DS.FreqBands_this = struct('Gamma', W.FreqBands.Gamma);
            DS.FullBandRange_this = W.FreqBands.Gamma;
            DS.computeFullBandMetrics = false;

        otherwise
            DS.summaryScalarVars_this = GP.summaryScalarVars;
            DS.scalar_plot_sets_this = GP.scalar_plot_sets;
            DS.FreqMin_this = W.FreqMin;
            DS.FreqMax_this = W.FreqMax;
            DS.FreqBands_this = W.FreqBands;
            DS.FullBandRange_this = FullBandRange;
            DS.computeFullBandMetrics = true;
    end

    DS.plot_freq_range_this = [DS.FreqMin_this DS.FreqMax_this];
end