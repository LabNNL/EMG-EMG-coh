function tf = overlaps_any_phase_interval(segStart, segEnd, phaseIntervals_sec)

    tf = false;

    for i = 1:size(phaseIntervals_sec,1)
        p1 = phaseIntervals_sec(i,1);
        p2 = phaseIntervals_sec(i,2);

        if segStart <= p2 && p1 <= segEnd
            tf = true;
            return;
        end
    end
end