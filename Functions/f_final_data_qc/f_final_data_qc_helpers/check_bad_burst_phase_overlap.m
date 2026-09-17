function [flag_raw, flag_padded, badSegSec, badSegExpandedSec, phaseIntervals_sec] = ...
    check_bad_burst_phase_overlap( ...
        bad_segments_samples, ...
        cycle_length_samples, ...
        fs, ...
        pairName, ...
        WCQ, ...
        contamination_half_width_sec)

    cycle_duration_sec = cycle_length_samples / fs;

    phaseIntervals_sec = ...
        get_phase_intervals_for_pair( ...
            pairName, ...
            cycle_duration_sec, ...
            WCQ);

    % ============================================================
    % No bad segments
    % ============================================================
    if isempty(bad_segments_samples)

        flag_raw = false;
        flag_padded = false;

        badSegSec = zeros(0,2);
        badSegExpandedSec = zeros(0,2);

        return;
    end

    % ============================================================
    % Convert cycle-local sample indices to seconds
    % ============================================================
    badSegSec = [ ...
        (bad_segments_samples(:,1) - 1) ./ fs, ...
        (bad_segments_samples(:,2) - 1) ./ fs ...
        ];

    % ============================================================
    % RAW overlap with POI
    % ============================================================
    flag_raw = false;

    for i = 1:size(badSegSec,1)

        if overlaps_any_phase_interval( ...
                badSegSec(i,1), ...
                badSegSec(i,2), ...
                phaseIntervals_sec)

            flag_raw = true;
            break;
        end
    end

    % ============================================================
    % WAVELET-AWARE EXPANSION
    %
    % IMPORTANT:
    % Expansion is circular across the gait-cycle boundary.
    %
    % Example:
    %   a bad segment near 100% whose wavelet support extends beyond
    %   the end of the cycle also contaminates the beginning of the
    %   following concatenated cycle.
    %
    % Likewise, contamination extending before 0% is wrapped to the
    % end of the preceding cycle.
    % ============================================================
    badSegExpandedSec = zeros(0,2);

    for i = 1:size(badSegSec,1)

        segStart = badSegSec(i,1);
        segEnd   = badSegSec(i,2);

        expandedStart = segStart - contamination_half_width_sec;
        expandedEnd   = segEnd   + contamination_half_width_sec;

        expandedWidth = expandedEnd - expandedStart;

        % If the expanded interval spans the entire cycle,
        % the whole cycle is potentially contaminated.
        if expandedWidth >= cycle_duration_sec

            newSegments = [0, cycle_duration_sec];

        % --------------------------------------------------------
        % No boundary crossing
        % --------------------------------------------------------
        elseif expandedStart >= 0 && ...
                expandedEnd <= cycle_duration_sec

            newSegments = [ ...
                expandedStart, ...
                expandedEnd ...
                ];

        % --------------------------------------------------------
        % Crosses LEFT boundary:
        %
        %  - part remains near 0
        %  - underflow wraps to end of cycle
        % --------------------------------------------------------
        elseif expandedStart < 0 && ...
                expandedEnd <= cycle_duration_sec

            wrappedStart = ...
                cycle_duration_sec + expandedStart;

            newSegments = [ ...
                0, expandedEnd; ...
                wrappedStart, cycle_duration_sec ...
                ];

        % --------------------------------------------------------
        % Crosses RIGHT boundary:
        %
        %  - part remains near end
        %  - overflow wraps to beginning of cycle
        % --------------------------------------------------------
        elseif expandedStart >= 0 && ...
                expandedEnd > cycle_duration_sec

            wrappedEnd = ...
                expandedEnd - cycle_duration_sec;

            newSegments = [ ...
                expandedStart, cycle_duration_sec; ...
                0, wrappedEnd ...
                ];

        % --------------------------------------------------------
        % Crosses BOTH boundaries
        % --------------------------------------------------------
        else

            newSegments = [0, cycle_duration_sec];

        end

        badSegExpandedSec = [ ...
            badSegExpandedSec; ...
            newSegments ...
            ]; %#ok<AGROW>
    end

    % ============================================================
    % Merge overlapping expanded segments
    % ============================================================
    badSegExpandedSec = ...
        merge_time_segments_local( ...
            badSegExpandedSec, ...
            cycle_duration_sec);

    % ============================================================
    % PADDED / WAVELET-AWARE overlap with POI
    % ============================================================
    flag_padded = false;

    for i = 1:size(badSegExpandedSec,1)

        if overlaps_any_phase_interval( ...
                badSegExpandedSec(i,1), ...
                badSegExpandedSec(i,2), ...
                phaseIntervals_sec)

            flag_padded = true;
            break;
        end
    end
end


%% ========================================================================
% LOCAL HELPER
% ========================================================================

function segments = merge_time_segments_local(segments, cycle_duration_sec)

    if isempty(segments)
        segments = zeros(0,2);
        return;
    end

    % Clamp for numerical safety
    segments(:,1) = max(0, segments(:,1));
    segments(:,2) = min(cycle_duration_sec, segments(:,2));

    % Remove invalid intervals
    segments = segments(segments(:,2) >= segments(:,1), :);

    if isempty(segments)
        segments = zeros(0,2);
        return;
    end

    % Sort by start time
    segments = sortrows(segments, 1);

    merged = segments(1,:);

    for i = 2:size(segments,1)

        if segments(i,1) <= merged(end,2)

            merged(end,2) = ...
                max(merged(end,2), segments(i,2));

        else

            merged(end+1,:) = segments(i,:); %#ok<AGROW>
        end
    end

    segments = merged;
end