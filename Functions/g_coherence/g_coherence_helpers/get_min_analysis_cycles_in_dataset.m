function Nmin = get_min_analysis_cycles_in_dataset( ...
    FINAL_PAIRED_SIGNALS, W, targetPair)

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

                pairNames = fieldnames( ...
                    FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg));

                for ip = 1:numel(pairNames)
                    pairName = pairNames{ip};

                    % Only calculate minimum for requested pair
                    if ~strcmp(pairName, targetPair)
                        continue;
                    end

                    P = FINAL_PAIRED_SIGNALS.(subjID).(cond).(leg).(pairName);

                    % Match actual coherence inclusion criterion
                    if ~isfield(P, 'included_after_crosstalk') || ...
                            ~P.included_after_crosstalk
                        continue;
                    end

                    if ~isfield(P, 'final_cycle_segments_table') || ...
                            isempty(P.final_cycle_segments_table)
                        continue;
                    end

                    Tseg = P.final_cycle_segments_table;

                    [analysis_cycle_mask, ~, ~, ~] = ...
                        build_analysis_cycle_masks( ...
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
        error('Could not determine common cycle count for pair %s.', ...
            targetPair);
    end

    Nmin = min(allN);
end