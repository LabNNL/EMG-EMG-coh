function run_final_comparison_plots(G, datasetFinalDir, plot_freq_range_this, FP, C)

    pairNamesAll = unique(string({G.pair_name}));

    for ip = 1:numel(pairNamesAll)
        pairName = pairNamesAll(ip);

        idxPair = string({G.pair_name})' == pairName;
        Gpair = G(idxPair);

        if isempty(Gpair)
            continue;
        end

        condAvail = cellstr(unique(string({Gpair.condition})));
        condGroups = string(keep_present_in_order(get_condition_order(), condAvail));

        if ~isempty(condGroups)
            if FP.make_raw_spectra
                plot_final_spectra_comparison(Gpair, condGroups, 'condition', pairName, datasetFinalDir, plot_freq_range_this, 'raw', C);
            end
            if FP.make_sig_spectra
                plot_final_spectra_comparison(Gpair, condGroups, 'condition', pairName, datasetFinalDir, plot_freq_range_this, 'sig', C);
            end
            if FP.make_raw_maps
                plot_final_maps_comparison(Gpair, condGroups, 'condition', pairName, datasetFinalDir, plot_freq_range_this, 'raw');
            end
            if FP.make_sig_maps
                plot_final_maps_comparison(Gpair, condGroups, 'condition', pairName, datasetFinalDir, plot_freq_range_this, 'sig');
            end
        end

        ageAvail = cellstr(unique(string({Gpair.age_group})));
        ageGroups = string(keep_present_in_order(get_age_order(), ageAvail));

        if ~isempty(ageGroups)
            if FP.make_raw_spectra
                plot_final_spectra_comparison(Gpair, ageGroups, 'age_group', pairName, datasetFinalDir, plot_freq_range_this, 'raw', C);
            end
            if FP.make_sig_spectra
                plot_final_spectra_comparison(Gpair, ageGroups, 'age_group', pairName, datasetFinalDir, plot_freq_range_this, 'sig', C);
            end
            if FP.make_raw_maps
                plot_final_maps_comparison(Gpair, ageGroups, 'age_group', pairName, datasetFinalDir, plot_freq_range_this, 'raw');
            end
            if FP.make_sig_maps
                plot_final_maps_comparison(Gpair, ageGroups, 'age_group', pairName, datasetFinalDir, plot_freq_range_this, 'sig');
            end
        end
    end
end
