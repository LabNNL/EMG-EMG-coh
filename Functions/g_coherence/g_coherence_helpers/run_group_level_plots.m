function run_group_level_plots(G, datasetGroupDir, plot_freq_range_this, scalar_plot_sets_this, GP, C)

    pairNamesAll = unique(string({G.pair_name}));

    for ip = 1:numel(pairNamesAll)
        pairName = pairNamesAll(ip);

        idxPair = string({G.pair_name})' == pairName;
        Gpair = G(idxPair);

        if isempty(Gpair)
            continue;
        end

        ageAvail = cellstr(unique(string({Gpair.age_group})));
        ageGroups = string(keep_present_in_order(get_age_order(), ageAvail));

        if ~isempty(ageGroups)
            plot_group_mean_maps(Gpair, ageGroups, 'age_group', pairName, datasetGroupDir, plot_freq_range_this, 'Coherence');
            plot_group_mean_maps(Gpair, ageGroups, 'age_group', pairName, datasetGroupDir, plot_freq_range_this, 'Coherence_sig');
            plot_group_mean_spectra(Gpair, ageGroups, 'age_group', pairName, datasetGroupDir, plot_freq_range_this, 'MeanFreqCurve', C);
            plot_group_mean_spectra(Gpair, ageGroups, 'age_group', pairName, datasetGroupDir, plot_freq_range_this, 'MeanFreqCurve_Sig', C);

            if GP.make_scalar_bars
                for iset = 1:numel(scalar_plot_sets_this)
                    scalarVars = scalar_plot_sets_this{iset};
                    plot_group_scalar_bars(Gpair, ageGroups, 'age_group', pairName, datasetGroupDir, scalarVars);
                end
            end
        end

        condAvail = cellstr(unique(string({Gpair.condition})));
        condGroups = string(keep_present_in_order(get_condition_order(), condAvail));

        if ~isempty(condGroups)
            plot_group_mean_maps(Gpair, condGroups, 'condition', pairName, datasetGroupDir, plot_freq_range_this, 'Coherence');
            plot_group_mean_maps(Gpair, condGroups, 'condition', pairName, datasetGroupDir, plot_freq_range_this, 'Coherence_sig');
            plot_group_mean_spectra(Gpair, condGroups, 'condition', pairName, datasetGroupDir, plot_freq_range_this, 'MeanFreqCurve', C);
            plot_group_mean_spectra(Gpair, condGroups, 'condition', pairName, datasetGroupDir, plot_freq_range_this, 'MeanFreqCurve_Sig', C);

            if GP.make_scalar_bars
                for iset = 1:numel(scalar_plot_sets_this)
                    scalarVars = scalar_plot_sets_this{iset};
                    plot_group_scalar_bars(Gpair, condGroups, 'condition', pairName, datasetGroupDir, scalarVars);
                end
            end
        end
    end
end