function f_qc_example_plots(FINAL_PAIRED_SIGNALS, FINAL_SIGNAL_SUMMARY, C)
% F_QC_EXAMPLE_PLOTS  Example figures of excluded and rebuilt pair signals
% (random and manual selections, overall and per band) and of wavelet ROI
% exclusions. Each kind has its own switch in C.f_final_signals.plot.

    P  = C.f_final_signals.params;
    PL = C.f_final_signals.plot;
    bandNames = fieldnames(C.f_final_signals.params.wavelet_contamination_qc.freq_bands);

    %% ===================== PLOTS FOR NON-INCLUDED PAIR SIGNALS =====================

    if PL.excluded.enable && ~isempty(FINAL_SIGNAL_SUMMARY)
        fprintf('\nGenerating plots for excluded pair signals...\n');
        excludedT = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.included_after_crosstalk == false, :);

        if ~isempty(excludedT)

            if isempty(PL.excluded.random_seed)
                rng('shuffle');
            else
                rng(PL.excluded.random_seed);
            end

            nAvail = height(excludedT);
            nPlot  = min(PL.excluded.n_random_pairs, nAvail);
            idxPick = randperm(nAvail, nPlot);

            for ip = 1:nPlot
                fprintf('  Plotting excluded pair signal %d / %d (index %d in excluded table)\n', ip, nPlot, idxPick(ip));
                row = excludedT(idxPick(ip), :);

                subjID   = char(row.subject);
                cond     = char(row.condition);
                leg      = char(row.leg);
                pairName = char(row.pair_name);

                if ~isfield(FINAL_PAIRED_SIGNALS, subjID) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID), cond) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond), leg) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg), pairName)
                    continue;
                end

                PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                plot_excluded_pair_signal(PairStruct, subjID, cond, leg, pairName, PL.excluded.out_dir, C);
                plot_excluded_multisignal( PairStruct, subjID, cond, leg, pairName, PL.excluded.out_dir, C, 'FileTag', 'excluded_pair', 'Visible', 'off');
            end
        end
    end
    fprintf('\nExcluded pair signal plots saved to:\n  %s\n', PL.excluded.out_dir);

    %% ===================== RANDOM PLOTS: BAND-SPECIFIC EXCLUDED SIGNALS =====================
    if isfield(PL, 'excluded_band') && PL.excluded_band.enable && ~isempty(FINAL_SIGNAL_SUMMARY)

        fprintf('\nGenerating random plots of band-specific excluded signals...\n');

        if ~exist(PL.excluded_band.out_dir, 'dir'), mkdir(PL.excluded_band.out_dir); end
        delete(fullfile(PL.excluded_band.out_dir, '*.png'));

        for ib = 1:numel(bandNames)
            band = bandNames{ib};

            includeVar = ['included_for_analysis_' lower(band)];
            TexclBand = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.(includeVar) == false, :);

            if isempty(TexclBand)
                fprintf('  No excluded signals for %s band.\n', band);
                continue;
            end

            if isempty(PL.excluded_band.random_seed)
                rng('shuffle');
            else
                rng(PL.excluded_band.random_seed + ib);
            end

            nAvail = height(TexclBand);
            nPlot  = min(PL.excluded_band.n_random_per_band, nAvail);
            idxPick = randperm(nAvail, nPlot);

            for ip = 1:nPlot
                row = TexclBand(idxPick(ip), :);

                subjID   = char(row.subject);
                cond     = char(row.condition);
                leg      = char(row.leg);
                pairName = char(row.pair_name);

                if ~isfield(FINAL_PAIRED_SIGNALS, subjID) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID), cond) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond), leg) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg), pairName)
                    continue;
                end

                PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);
                Pplot = make_band_plot_struct(PairStruct, band);

                plot_excluded_multisignal( Pplot, subjID, cond, leg, [pairName '_' band], PL.excluded_band.out_dir, C, 'FileTag', ['excluded_' lower(band)], 'Visible', 'off', 'FigureTitle', sprintf('%s | %s | %s | %s | %s-specific excluded', subjID, cond, leg, pairName, band));
            end
        end
    end

    fprintf('\nBand-specific excluded plots saved to:\n  %s\n', PL.excluded_band.out_dir);

    %% ===================== MANUAL PLOTS FOR SELECTED PAIRS =====================
    if isfield(PL, 'manual') && isfield(PL.manual, 'enable') && PL.manual.enable
        fprintf('\nGenerating manual plots for selected pairs set in config_emg.m...\n');

        if ~exist(PL.manual.out_dir, 'dir'), mkdir(PL.manual.out_dir); end

        % optional: remove old plots
        delete(fullfile(PL.manual.out_dir, '*.png'));

        requests = PL.manual.requests;

        for iR = 1:numel(requests)
            req = requests{iR};

            subjID   = char(string(req.subject));
            cond     = char(string(req.condition));
            leg      = char(string(req.leg));
            pairName = char(string(req.pair_name));

            fprintf('  Manual plot %d / %d: %s | %s | %s | %s\n', iR, numel(requests), subjID, cond, leg, pairName);

            if ~isfield(FINAL_PAIRED_SIGNALS, subjID)
                warning('Manual plot skipped: subject not found: %s', subjID);
                continue;
            end
            if ~isfield(FINAL_PAIRED_SIGNALS.(subjID), cond)
                warning('Manual plot skipped: condition not found: %s | %s', subjID, cond);
                continue;
            end
            if ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond), leg)
                warning('Manual plot skipped: leg not found: %s | %s | %s', subjID, cond, leg);
                continue;
            end
            if ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg), pairName)
                warning('Manual plot skipped: pair not found: %s | %s | %s | %s', subjID, cond, leg, pairName);
                continue;
            end

            PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

            % choose which plotting function you want
            plot_excluded_pair_signal(PairStruct, subjID, cond, leg, pairName, PL.manual.out_dir, C);
            plot_excluded_multisignal( PairStruct, subjID, cond, leg, pairName, PL.manual.out_dir, C, 'FileTag', 'manual_pair', 'Visible', 'off');

            % If instead you want the rebuilt signal plot for that exact case, use:
            %plot_original_vs_rebuilt_pair_signal(PairStruct, subjID, cond, leg, pairName, PL.manual.out_dir, C);

            plot_original_vs_rebuilt_multisignal( PairStruct, subjID, cond, leg, pairName, PL.manual.out_dir, C, 'FileTag', 'rebuilt_pair', 'Visible', 'off', 'CenterRebuilt', true);
        end
        fprintf('\nManual pair plots saved to:\n  %s\n', PL.manual.out_dir);
    else
        fprintf('\nNo manual plotting requested in config_emg.m, skipping manual plots.\n');
    end

    %% ===================== RANDOM PLOTS: ORIGINAL VS REBUILT =====================
    if PL.rebuilt.enable && ~isempty(FINAL_SIGNAL_SUMMARY)
        fprintf('\nGenerating random plots of original vs rebuilt signals...\n');
        % Keep only signals that were included for analysis
        Tplot = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.included_after_crosstalk == true, :);

        if ~isempty(Tplot)
            if isempty(PL.rebuilt.random_seed)
                rng('shuffle');
            else
                rng(PL.rebuilt.random_seed);
            end

            % delete old plots
            if ~exist(PL.rebuilt.out_dir, 'dir'), mkdir(PL.rebuilt.out_dir); end
            delete(fullfile(PL.rebuilt.out_dir, '*.png'));

            nAvail = height(Tplot);
            nPlot  = min(PL.rebuilt.n_random, nAvail);
            idxPick = randperm(nAvail, nPlot);

            for ip = 1:nPlot

                row = Tplot(idxPick(ip), :);

                subjID   = char(row.subject);
                cond     = char(row.condition);
                leg      = char(row.leg);
                pairName = char(row.pair_name);

                if ~isfield(FINAL_PAIRED_SIGNALS, subjID) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID), cond) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond), leg) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg), pairName)
                    continue;
                end

                PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                %plot_original_vs_rebuilt_pair_signal(PairStruct, subjID, cond, leg, pairName, PL.rebuilt.out_dir, C);
                plot_original_vs_rebuilt_multisignal( PairStruct, subjID, cond, leg, pairName, PL.rebuilt.out_dir, C, 'FileTag', 'rebuilt_pair', 'Visible', 'off', 'CenterRebuilt', true);
            end
        end
    end

    fprintf('\nOriginal vs rebuilt signal plots saved to:\n  %s\n', PL.rebuilt.out_dir);

    %% ===================== RANDOM PLOTS: BAND-SPECIFIC REBUILT SIGNALS =====================
    if isfield(PL, 'rebuilt_band') && PL.rebuilt_band.enable && ~isempty(FINAL_SIGNAL_SUMMARY)

        fprintf('\nGenerating random plots of band-specific rebuilt signals...\n');

        if ~exist(PL.rebuilt_band.out_dir, 'dir'), mkdir(PL.rebuilt_band.out_dir); end
        delete(fullfile(PL.rebuilt_band.out_dir, '*.png'));

        for ib = 1:numel(bandNames)
            band = bandNames{ib};

            includeVar = ['included_after_crosstalk_' lower(band)];
            Tband = FINAL_SIGNAL_SUMMARY(FINAL_SIGNAL_SUMMARY.(includeVar) == true, :);

            if isempty(Tband)
                fprintf('  No included signals for %s band.\n', band);
                continue;
            end

            if isempty(PL.rebuilt_band.random_seed)
                rng('shuffle');
            else
                rng(PL.rebuilt_band.random_seed + ib);
            end

            nAvail = height(Tband);
            nPlot  = min(PL.rebuilt_band.n_random_per_band, nAvail);
            idxPick = randperm(nAvail, nPlot);

            for ip = 1:nPlot
                row = Tband(idxPick(ip), :);

                subjID   = char(row.subject);
                cond     = char(row.condition);
                leg      = char(row.leg);
                pairName = char(row.pair_name);

                if ~isfield(FINAL_PAIRED_SIGNALS, subjID) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID), cond) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond), leg) || ~isfield(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg), pairName)
                    continue;
                end

                PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);
                Pplot = make_band_plot_struct(PairStruct, band);

                plot_original_vs_rebuilt_multisignal( Pplot, subjID, cond, leg, [pairName '_' band], PL.rebuilt_band.out_dir, C, 'FileTag', ['rebuilt_' lower(band)], 'Visible', 'off', 'CenterRebuilt', true, 'FigureTitle', sprintf('%s | %s | %s | %s | %s-specific rebuilt', subjID, cond, leg, pairName, band));
            end
        end
    end

    %% ===================== WAVELET ROI EXCLUSION EXAMPLE PLOTS =====================
    if isfield(C.f_final_signals.plot, 'wavelet_roi') && C.f_final_signals.plot.wavelet_roi.enable
        fprintf('\nGenerating wavelet ROI exclusion example plots...\n');
        plot_wavelet_roi_exclusion_examples(FINAL_PAIRED_SIGNALS, C, P);
    end
end
