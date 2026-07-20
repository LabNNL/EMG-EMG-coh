function print_phase_intervals_for_pair(pairName, cycle_duration_sec, WCQ)

    phaseIntervals_sec = get_phase_intervals_for_pair(pairName, cycle_duration_sec, WCQ);

    fprintf('\nPhase intervals for %s (cycle duration = %.3f s):\n', ...
        char(string(pairName)), cycle_duration_sec);

    for i = 1:size(phaseIntervals_sec,1)
        fprintf('  Interval %d: [%.3f, %.3f] s\n', ...
            i, phaseIntervals_sec(i,1), phaseIntervals_sec(i,2));
    end
end