function [toeoff_percentages, toeoff_percent, toeoff_index, ...
    stance_phase_indices, swing_phase_indices] = compute_toeoff_segmentation(P, Tseg, W)

    toeoff_percentages = nan(height(Tseg),1);

    if isfield(P, 'toe_off_original_idx_muscle1') && ~isempty(P.toe_off_original_idx_muscle1)
        toeIdxAll = P.toe_off_original_idx_muscle1(:);

        for iC = 1:height(Tseg)
            cycNum = Tseg.cycle_number(iC);

            if cycNum <= numel(toeIdxAll) && ~isnan(toeIdxAll(cycNum))
                c1 = Tseg.original_cycle_start_idx(iC);
                c2 = Tseg.original_cycle_end_idx(iC);
                dur = c2 - c1;

                if dur > 0
                    toeoff_percentages(iC) = 100 * (toeIdxAll(cycNum) - c1) / dur;
                end
            end
        end
    end

    if W.use_toeoff_segmentation && any(~isnan(toeoff_percentages))
        toeoff_percent = mean(toeoff_percentages, 'omitnan');
    else
        toeoff_percent = W.default_toeoff_percent;
    end

    toeoff_index = round(toeoff_percent * W.n_interp_time / 100);
    toeoff_index = max(1, min(toeoff_index, W.n_interp_time-1));

    stance_phase_indices = 1:toeoff_index;
    swing_phase_indices  = (toeoff_index+1):W.n_interp_time;
end