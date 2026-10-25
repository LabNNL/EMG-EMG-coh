function G = build_group_plot_struct(COHERENCE_RESULTS, C, W, metricSource)
% BUILD_GROUP_PLOT_STRUCT  Flatten COHERENCE_RESULTS into a struct array
% for the group-level and final comparison plots.
%
% Its own file because g_emg_emg_wavelet_coherence calls it directly, and a
% local function is only visible inside the file that defines it.


    if nargin < 4 || isempty(metricSource)
        metricSource = "sig";
    end
    metricSource = lower(string(metricSource));

    G = struct( ...
        'subject', {}, 'age_group', {}, 'condition', {}, 'leg', {}, 'pair_name', {}, ...
        'metric_source', {}, ...
        'Freq', {}, 'Time_percent', {}, ...
        'Coherence', {}, 'Coherence_sig', {}, ...
        'MeanFreqCurve', {}, 'MeanFreqCurve_Sig', {}, ...
        'StanceIndices', {}, 'SwingIndices', {}, ...
        'FullBand_Mean', {}, 'FullBand_AUC_raw', {}, 'FullBand_AUC_norm', {}, 'FullBand_Peak', {}, ...
        'FullBand_Mean_POI', {}, 'FullBand_AUC_raw_POI', {}, 'FullBand_AUC_norm_POI', {}, 'FullBand_Peak_POI', {}, ...
        'FullBand_Peak_Stance', {}, 'FullBand_Peak_Swing', {}, ...
        'FullBand_Range', {}, ...
        'HasPOI', {}, 'POI_StartPercent', {}, 'POI_EndPercent', {}, 'POI_Indices', {} );

    gi = 0;

    subjFields = fieldnames(COHERENCE_RESULTS);

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};
        age_group = subject_to_group(subjID, C);

        condFields = fieldnames(COHERENCE_RESULTS.(subjID));
        for ic = 1:numel(condFields)
            cond = condFields{ic};

            legFields = fieldnames(COHERENCE_RESULTS.(subjID).(cond));
            for il = 1:numel(legFields)
                leg = legFields{il};

                pairFields = fieldnames(COHERENCE_RESULTS.(subjID).(cond).(leg));
                for ip = 1:numel(pairFields)
                    pairName = pairFields{ip};

                    Rr = COHERENCE_RESULTS.(subjID).(cond).(leg).(pairName);
                    if isempty(Rr)
                        continue;
                    end

                    gi = gi + 1;

                    % ---------- identifiers ----------
                    G(gi).subject = string(subjID);
                    G(gi).age_group = string(age_group);
                    G(gi).condition = string(cond);
                    G(gi).leg = string(leg);
                    G(gi).pair_name = string(pairName);
                    G(gi).metric_source = metricSource;

                    % ---------- axes ----------
                    G(gi).Freq = Rr.Freq(:);
                    G(gi).Time_percent = Rr.Time_percent(:)';

                    % ---------- maps ----------
                    if isfield(Rr, 'Coherence') && ~isempty(Rr.Coherence)
                        G(gi).Coherence = Rr.Coherence;
                        G(gi).MeanFreqCurve = mean(Rr.Coherence, 2, 'omitnan');
                    else
                        G(gi).Coherence = [];
                        G(gi).MeanFreqCurve = [];
                    end

                    if isfield(Rr, 'Coherence_sig') && ~isempty(Rr.Coherence_sig)
                        G(gi).Coherence_sig = Rr.Coherence_sig;
                        G(gi).MeanFreqCurve_Sig = mean(Rr.Coherence_sig, 2, 'omitnan');
                    else
                        G(gi).Coherence_sig = [];
                        G(gi).MeanFreqCurve_Sig = [];
                    end

                    % ---------- phase indices ----------
                    G(gi).StanceIndices = getfield_safe(Rr, 'StanceIndices', []);
                    G(gi).SwingIndices  = getfield_safe(Rr, 'SwingIndices', []);

                    % ---------- defaults ----------
                    bandList = fieldnames(W.FreqBands);   % per-band fields are added here
                    for ib = 1:numel(bandList)
                        b = bandList{ib};

                        G(gi).(b) = NaN;
                        G(gi).([b '_AUC_raw']) = NaN;
                        G(gi).([b '_AUC_norm']) = NaN;
                        G(gi).([b '_Peak']) = NaN;

                        G(gi).([b '_POI']) = NaN;
                        G(gi).([b '_AUC_raw_POI']) = NaN;
                        G(gi).([b '_AUC_norm_POI']) = NaN;
                        G(gi).([b '_Peak_POI']) = NaN;

                        G(gi).([b '_Peak_Stance']) = NaN;
                        G(gi).([b '_Peak_Swing']) = NaN;
                    end

                    G(gi).FullBand_Mean = NaN;
                    G(gi).FullBand_AUC_raw = NaN;
                    G(gi).FullBand_AUC_norm = NaN;
                    G(gi).FullBand_Peak = NaN;

                    G(gi).FullBand_Mean_POI = NaN;
                    G(gi).FullBand_AUC_raw_POI = NaN;
                    G(gi).FullBand_AUC_norm_POI = NaN;
                    G(gi).FullBand_Peak_POI = NaN;

                    G(gi).FullBand_Peak_Stance = NaN;
                    G(gi).FullBand_Peak_Swing = NaN;
                    G(gi).FullBand_Range = getfield_safe(Rr, 'FullBand_Range', []);

                    G(gi).HasPOI = false;
                    G(gi).POI_StartPercent = NaN;
                    G(gi).POI_EndPercent = NaN;
                    G(gi).POI_Indices = [];

                    % ---------- POI metadata ----------
                    if isfield(Rr, 'POI') && isstruct(Rr.POI)
                        G(gi).HasPOI = getfield_safe(Rr.POI, 'has_poi', false);
                        G(gi).POI_StartPercent = getfield_safe(Rr.POI, 'start_pct', NaN);
                        G(gi).POI_EndPercent = getfield_safe(Rr.POI, 'end_pct', NaN);
                        G(gi).POI_Indices = getfield_safe(Rr.POI, 'indices', []);
                    else
                        G(gi).HasPOI = getfield_safe(Rr, 'HasPOI', false);
                        G(gi).POI_StartPercent = getfield_safe(Rr, 'POI_StartPercent', NaN);
                        G(gi).POI_EndPercent = getfield_safe(Rr, 'POI_EndPercent', NaN);
                        G(gi).POI_Indices = getfield_safe(Rr, 'POI_Indices', []);
                    end

                    % ---------- scalar metrics from selected source ----------
                    for ib = 1:numel(bandList)
                        b = bandList{ib};

                        % full cycle
                        G(gi).(b) = get_metric_value_from_R(Rr, metricSource, "full", "mean", b);
                        G(gi).([b '_AUC_raw']) = get_metric_value_from_R(Rr, metricSource, "full", "auc_raw", b);
                        G(gi).([b '_AUC_norm']) = get_metric_value_from_R(Rr, metricSource, "full", "auc_norm", b);
                        G(gi).([b '_Peak']) = get_metric_value_from_R(Rr, metricSource, "full", "peak", b);

                        % POI
                        G(gi).([b '_POI']) = get_metric_value_from_R(Rr, metricSource, "poi", "mean", b);
                        G(gi).([b '_AUC_raw_POI']) = get_metric_value_from_R(Rr, metricSource, "poi", "auc_raw", b);
                        G(gi).([b '_AUC_norm_POI']) = get_metric_value_from_R(Rr, metricSource, "poi", "auc_norm", b);
                        G(gi).([b '_Peak_POI']) = get_metric_value_from_R(Rr, metricSource, "poi", "peak", b);

                        % stance / swing peaks
                        G(gi).([b '_Peak_Stance']) = get_metric_value_from_R(Rr, metricSource, "stance", "peak", b);
                        G(gi).([b '_Peak_Swing'])  = get_metric_value_from_R(Rr, metricSource, "swing", "peak", b);
                    end

                    % full-band scalar metrics
                    G(gi).FullBand_Mean = get_metric_value_from_R(Rr, metricSource, "full", "fullband_mean", "");
                    G(gi).FullBand_AUC_raw = get_metric_value_from_R(Rr, metricSource, "full", "fullband_auc_raw", "");
                    G(gi).FullBand_AUC_norm = get_metric_value_from_R(Rr, metricSource, "full", "fullband_auc_norm", "");
                    G(gi).FullBand_Peak = get_metric_value_from_R(Rr, metricSource, "full", "fullband_peak", "");

                    G(gi).FullBand_Mean_POI = get_metric_value_from_R(Rr, metricSource, "poi", "fullband_mean", "");
                    G(gi).FullBand_AUC_raw_POI = get_metric_value_from_R(Rr, metricSource, "poi", "fullband_auc_raw", "");
                    G(gi).FullBand_AUC_norm_POI = get_metric_value_from_R(Rr, metricSource, "poi", "fullband_auc_norm", "");
                    G(gi).FullBand_Peak_POI = get_metric_value_from_R(Rr, metricSource, "poi", "fullband_peak", "");

                    G(gi).FullBand_Peak_Stance = get_metric_value_from_R(Rr, metricSource, "stance", "fullband_peak", "");
                    G(gi).FullBand_Peak_Swing  = get_metric_value_from_R(Rr, metricSource, "swing", "fullband_peak", "");
                end
            end
        end
    end
end
