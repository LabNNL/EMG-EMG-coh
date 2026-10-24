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
    metricSuffixes = {'', '_AUC_norm', '_Peak', '_POI', '_AUC_norm_POI', '_Peak_POI'};

    % A dataset is FULL (all bands, overall cycle mask) or one band, named
    % in upper case (e.g. HIGHBETA for W.FreqBands.HighBeta)
    bandIdx = find(strcmpi(bandNames, char(datasetName)), 1);

    if strcmpi(char(datasetName), 'FULL') || isempty(bandIdx)
        DS.summaryScalarVars_this = [ ...
            scalar_vars(bandNames, metricSuffixes), ...
            {'FullBand_Mean','FullBand_AUC_norm','FullBand_Peak', ...
             'FullBand_Mean_POI','FullBand_AUC_norm_POI','FullBand_Peak_POI'}];
        DS.scalar_plot_sets_this = GP.scalar_plot_sets;
        DS.FreqMin_this = W.FreqMin;
        DS.FreqMax_this = W.FreqMax;
        DS.FreqBands_this = W.FreqBands;
        DS.FullBandRange_this = FullBandRange;
        DS.computeFullBandMetrics = true;
    else
        band = bandNames{bandIdx};
        DS.summaryScalarVars_this = scalar_vars({band}, metricSuffixes);
        DS.scalar_plot_sets_this = {scalar_vars({band}, metricSuffixes(1:3)), scalar_vars({band}, metricSuffixes(4:6))};
        DS.FreqMin_this = W.FreqBands.(band)(1);
        DS.FreqMax_this = W.FreqBands.(band)(2);
        DS.FreqBands_this = struct(band, W.FreqBands.(band));
        DS.FullBandRange_this = W.FreqBands.(band);
        DS.computeFullBandMetrics = false;
    end

    DS.plot_freq_range_this = [DS.FreqMin_this DS.FreqMax_this];
end

function v = scalar_vars(bands, suffixes)
% {'HighBeta','Gamma'} x {'', '_AUC_norm'} -> {'HighBeta','Gamma','HighBeta_AUC_norm','Gamma_AUC_norm'}
    v = {};
    for k = 1:numel(suffixes)
        v = [v, strcat(bands(:)', suffixes{k})]; %#ok<AGROW>
    end
end
