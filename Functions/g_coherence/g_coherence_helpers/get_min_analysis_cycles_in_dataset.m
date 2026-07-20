function Nmin = get_min_analysis_cycles_in_dataset(FINAL_PAIRED_SIGNALS, W)

    allN = [];

    subjects = fieldnames(FINAL_PAIRED_SIGNALS);

    for iS = 1:numel(subjects)
        subjID = subjects{iS};

        conds = fieldnames(FINAL_PAIRED_SIGNALS.(subjID));
        for ic = 1:numel(conds)
            cond = conds{ic};

            legs = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond));
            for il = 1:numel(legs)
                leg = legs{il};

                pairNames = fieldnames(FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg));
                for ip = 1:numel(pairNames)
                    pairName = pairNames{ip};

                    P = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                    if ~isfield(P, 'included_for_analysis') || ~P.included_for_analysis
                        continue;
                    end

                    if ~isfield(P, 'final_cycle_segments_table') || isempty(P.final_cycle_segments_table)
                        continue;
                    end

                    Tseg = P.final_cycle_segments_table;

                    [analysis_cycle_mask, ~, ~, ~] = build_analysis_cycle_masks( ...
                        Tseg, W, subjID, cond, leg, pairName);

                    if isempty(analysis_cycle_mask)
                        continue;
                    end

                    nUsed = sum(analysis_cycle_mask);

                    if nUsed > 0
                        allN(end+1,1) = nUsed; %#ok<AGROW>
                    end
                end
            end
        end
    end

    if isempty(allN)
        error('Could not determine N_common_equalized: no included entries with valid cycles.');
    end

    Nmin = min(allN);

    if Nmin < 2
        warning('N_common_equalized is very low: %d cycles. Significant coherence threshold may be unstable.', Nmin);
    end
end