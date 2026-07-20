function Tseg = add_toe_off_to_rebuilt_segments(Tseg, toeInfo)
    if isempty(Tseg)
        return;
    end

    Tseg.has_toe_off = false(height(Tseg),1);
    Tseg.toe_off_original_idx = nan(height(Tseg),1);
    Tseg.toe_off_relative_idx_in_cycle = nan(height(Tseg),1);
    Tseg.toe_off_rebuilt_idx_signal1 = nan(height(Tseg),1);
    Tseg.toe_off_rebuilt_idx_signal2 = nan(height(Tseg),1);

    for i = 1:height(Tseg)
        cycNum = Tseg.cycle_number(i);

        if toeInfo.has_toe_off(cycNum)
            relIdx = toeInfo.toe_off_relative_idx(cycNum);

            Tseg.has_toe_off(i) = true;
            Tseg.toe_off_original_idx(i) = toeInfo.toe_off_original_idx(cycNum);
            Tseg.toe_off_relative_idx_in_cycle(i) = relIdx;

            Tseg.toe_off_rebuilt_idx_signal1(i) = Tseg.final_concat_start_idx_signal1(i) + relIdx - 1;
            Tseg.toe_off_rebuilt_idx_signal2(i) = Tseg.final_concat_start_idx_signal2(i) + relIdx - 1;
        end
    end
end