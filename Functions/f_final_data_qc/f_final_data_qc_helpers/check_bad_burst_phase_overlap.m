function [flag_raw, flag_padded, badSegSec, badSegExpandedSec, phaseIntervals_sec] = ...
    check_bad_burst_phase_overlap(bad_segments_samples, cycle_length_samples, fs, ...
    pairName, WCQ, overall_contamination_half_width_sec)

    cycle_duration_sec = cycle_length_samples / fs;

    phaseIntervals_sec = get_phase_intervals_for_pair(pairName, cycle_duration_sec, WCQ);

    if isempty(bad_segments_samples)
        flag_raw = false;
        flag_padded = false;
        badSegSec = zeros(0,2);
        badSegExpandedSec = zeros(0,2);
        return;
    end

    % convert local sample indices to seconds
    badSegSec = [ ...
        (bad_segments_samples(:,1) - 1) ./ fs, ...
        (bad_segments_samples(:,2) - 1) ./ fs];

    % expand by wavelet contamination half-width
    badSegExpandedSec = [ ...
        max(0, badSegSec(:,1) - overall_contamination_half_width_sec), ...
        min(cycle_duration_sec, badSegSec(:,2) + overall_contamination_half_width_sec)];

    flag_raw = false;
    flag_padded = false;

    for i = 1:size(badSegSec,1)
        if overlaps_any_phase_interval(badSegSec(i,1), badSegSec(i,2), phaseIntervals_sec)
            flag_raw = true;
            break;
        end
    end

    for i = 1:size(badSegExpandedSec,1)
        if overlaps_any_phase_interval(badSegExpandedSec(i,1), badSegExpandedSec(i,2), phaseIntervals_sec)
            flag_padded = true;
            break;
        end
    end
end