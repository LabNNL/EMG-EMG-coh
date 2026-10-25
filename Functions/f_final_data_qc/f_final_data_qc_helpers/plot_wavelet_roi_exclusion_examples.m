function plot_wavelet_roi_exclusion_examples(FINAL_PAIRED_SIGNALS, C, P)

    PLW = C.f_final_signals.plot.wavelet_roi;
    WCQ = C.f_final_signals.params.wavelet_contamination_qc;

    if ~PLW.enable
        return;
    end

    if ~exist(PLW.out_dir, 'dir')
        mkdir(PLW.out_dir);
    end

    if PLW.delete_old_png
        delete(fullfile(PLW.out_dir, '*.png'));
    end

    bandList = ["overall", string(fieldnames(WCQ.freq_bands))'];

    for ib = 1:numel(bandList)
        band = bandList(ib);

        rows = {};

        subjFields = fieldnames(FINAL_PAIRED_SIGNALS);
        for iS = 1:numel(subjFields)
            subjID = subjFields{iS};

            condFields = fieldnames(FINAL_PAIRED_SIGNALS.(subjID));
            for ic = 1:numel(condFields)
                cond = condFields{ic};

                legFields = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond));
                for il = 1:numel(legFields)
                    leg = legFields{il};

                    pairFields = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg));
                    for ip = 1:numel(pairFields)
                        pairName = pairFields{ip};
                        PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                        if ~isfield(PairStruct, 'muscle1_cycle_qc') || ~isfield(PairStruct, 'muscle2_cycle_qc')
                            continue;
                        end

                        cyc1 = PairStruct.muscle1_cycle_qc;
                        cyc2 = PairStruct.muscle2_cycle_qc;

                        nCycles = numel(PairStruct.cycle_starts);

                        for iC = 1:nCycles
                            bad1 = get_wavelet_overlap_flag_for_band(cyc1, iC, band);
                            bad2 = get_wavelet_overlap_flag_for_band(cyc2, iC, band);

                            if bad1 || bad2
                                rows(end+1,:) = {subjID, cond, leg, pairName, iC}; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end

        if isempty(rows)
            fprintf('No %s wavelet ROI-excluded cycles found for plotting.\n', upper(char(band)));
            continue;
        end

        if isempty(PLW.random_seed)
            rng('shuffle');
        else
            rng(PLW.random_seed + ib);
        end

        nAvail = size(rows,1);
        nPlot = min(PLW.n_random_pairs, nAvail);
        idxPick = randperm(nAvail, nPlot);

        for i = 1:nPlot
            r = rows(idxPick(i), :);
            subjID = r{1};
            cond = r{2};
            leg = r{3};
            pairName = r{4};
            cycleNum = r{5};

            PairStruct = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

            plot_one_wavelet_roi_exclusion_cycle( ...
                PairStruct, subjID, cond, leg, pairName, cycleNum, ...
                WCQ, PLW.out_dir, C, band);
        end
    end
end