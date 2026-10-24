function cyc = evaluate_cycles_for_one_muscle(subjID, cond, leg, mf, pairName, x, ...
    cycle_starts, cycle_ends, bursts, burst_keep, burst_reason, P, fs, WCQ, OVERALL_BOUNDARY_SEC, BAND_BOUNDARIES)
    cycle_starts = cycle_starts(:);
    cycle_ends   = cycle_ends(:);

    if numel(cycle_starts) ~= numel(cycle_ends)
        error('evaluate_cycles_for_one_muscle: cycle_starts and cycle_ends must have same length. Got %d vs %d.', ...
            numel(cycle_starts), numel(cycle_ends));
    end

    nCycles = numel(cycle_starts);
    nBursts = size(bursts,1);

    cyc = struct();
    cyc.subject   = string(subjID);
    cyc.condition = string(cond);
    cyc.leg       = string(leg);
    cyc.muscle    = string(mf);

    cyc.cycle_starts = cycle_starts(:);
    cyc.cycle_ends   = cycle_ends(:);

    cyc.cycle_length_samples = cycle_ends(:) - cycle_starts(:) + 1;

    cyc.n_overlapping_bursts = zeros(nCycles,1);
    cyc.overlapping_burst_numbers = cell(nCycles,1);
    cyc.overlapping_burst_idx = cell(nCycles,1);

    cyc.has_any_burst  = false(nCycles,1);
    cyc.has_good_burst = false(nCycles,1);
    cyc.has_bad_burst  = false(nCycles,1);

    cyc.n_good_bursts = zeros(nCycles,1);
    cyc.n_bad_bursts  = zeros(nCycles,1);

    cyc.bad_burst_overlap_segments = cell(nCycles,1);
    cyc.bad_burst_covered_samples  = zeros(nCycles,1);
    cyc.bad_burst_fraction         = zeros(nCycles,1);

    cyc.cycle_ptp = nan(nCycles,1);
    cyc.cycle_std = nan(nCycles,1);
    cyc.is_flatline = false(nCycles,1);

    cyc.flatline_segments = cell(nCycles,1);
    cyc.flatline_covered_samples = zeros(nCycles,1);
    cyc.flatline_fraction = zeros(nCycles,1);
    cyc.is_partly_flatline = false(nCycles,1);

    cyc.cycle_keep_mask = false(nCycles,1);
    cyc.cycle_reason = strings(nCycles,1);

    cyc.wavelet_contaminated_overall = false(nCycles,1);
    cyc.wavelet_keep_overall = true(nCycles,1);
    cyc.wavelet_phase_intervals_sec = cell(nCycles,1);
    cyc.wavelet_bad_segments_sec = cell(nCycles,1);
    cyc.wavelet_bad_segments_expanded_sec = cell(nCycles,1);
    cyc.wavelet_reason_overall = strings(nCycles,1);

    cyc.has_bad_burst_in_phase_of_interest = false(nCycles,1);
    cyc.has_bad_burst_in_phase_of_interest_padded = false(nCycles,1);

    cyc.phase_intervals_sec = cell(nCycles,1);
    cyc.bad_burst_segments_sec = cell(nCycles,1);
    cyc.bad_burst_segments_padded_sec = cell(nCycles,1);

    cyc.band_contaminated = struct();
    cyc.band_keep_mask = struct();
    cyc.band_reason = struct();

    cyc.band_bad_segments_padded_sec = struct();

    bandNames = fieldnames(WCQ.freq_bands);
    for ib = 1:numel(bandNames)
        band = bandNames{ib};

        cyc.band_contaminated.(band) = false(nCycles,1);
        cyc.band_keep_mask.(band) = true(nCycles,1);
        cyc.band_reason.(band) = strings(nCycles,1);
        cyc.band_bad_segments_padded_sec.(band) = cell(nCycles,1);
    end

    cyc.general_keep_mask = false(nCycles,1);
    cyc.general_reason = strings(nCycles,1);

    for iC = 1:nCycles
        c1 = cycle_starts(iC);
        c2 = cycle_ends(iC);

        % ---------- Extract cycle signal ----------
        x_cycle = x(c1:c2);

        cyc.cycle_ptp(iC) = max(x_cycle, [], 'omitnan') - min(x_cycle, [], 'omitnan');
        cyc.cycle_std(iC) = std(x_cycle, 'omitnan');

        % ---------- Flatline detection ----------
        if P.cycle_policy.reject_flatline_cycles
            switch string(P.cycle_policy.parameters.flatline_method)
                case "ptp"
                    cyc.is_flatline(iC) = cyc.cycle_ptp(iC) < P.cycle_policy.parameters.flatline_min_ptp;
                    if cyc.is_flatline(iC)
                        fprintf('For subject %s | %s | %s | %s: ', subjID, cond, leg, mf);
                        fprintf('Cycle %d: PTP=%.4f | Flatline threshold=%.4f | is_flatline=%d\n', iC, cyc.cycle_ptp(iC), P.cycle_policy.parameters.flatline_min_ptp, cyc.is_flatline(iC));
                    end
                case "std"
                    cyc.is_flatline(iC) = cyc.cycle_std(iC) < P.cycle_policy.parameters.flatline_min_std;
                    if cyc.is_flatline(iC)
                        fprintf('For subject %s | %s | %s | %s: ', subjID, cond, leg, mf);
                        fprintf('Cycle %d: STD=%.4f | Flatline threshold=%.4f | is_flatline=%d\n', iC, cyc.cycle_std(iC), P.cycle_policy.parameters.flatline_min_std, cyc.is_flatline(iC));
                    end
                otherwise
                    error('Unknown flatline_method: %s', string(P.cycle_policy.parameters.flatline_method));
            end
        else
            cyc.is_flatline(iC) = false;
        end

        % ---------- Partial flatline detection ----------
        flat_segments = zeros(0,2);

        if numel(x_cycle) >= 2 && ~cyc.is_flatline(iC)
            dx = abs(diff(x_cycle));
            flat_mask = dx < P.cycle_policy.parameters.flatline_diff_thresh;

            % runs are on diff-space, length = numel(x_cycle)-1
            flat_runs = logical_to_runs_local(flat_mask);

            if ~isempty(flat_runs)
                run_lengths = flat_runs(:,2) - flat_runs(:,1) + 1;
                flat_runs = flat_runs(run_lengths >= P.cycle_policy.parameters.flatline_min_run_samples, :);

                % convert diff-index runs to sample-index runs in x_cycle
                if ~isempty(flat_runs)
                    flat_segments = [flat_runs(:,1), flat_runs(:,2)+1];
                    flat_segments = merge_segments_local(flat_segments);
                end
            end
        end

        if isempty(flat_segments)
            flat_covered = 0;
        else
            flat_covered = sum(flat_segments(:,2) - flat_segments(:,1) + 1);
        end

        flat_fraction = flat_covered / cyc.cycle_length_samples(iC);

        cyc.flatline_segments{iC} = flat_segments;
        cyc.flatline_covered_samples(iC) = flat_covered;
        cyc.flatline_fraction(iC) = flat_fraction;
        cyc.is_partly_flatline(iC) = flat_fraction > P.cycle_policy.parameters.max_flatline_fraction;

        % ---------- Find overlapping bursts ----------
        overlap_idx = [];
        bad_segments = [];   % segments of bad burst overlap within this cycle, in cycle-local coordinates

        for iB = 1:nBursts
            b1 = bursts(iB,1);
            b2 = bursts(iB,2);

            % overlap with current cycle
            if (b1 <= c2) && (b2 >= c1)
                overlap_idx(end+1) = iB; %#ok<AGROW>

                % if burst is bad, store the overlap segment with the cycle
                if ~burst_keep(iB)
                    ov1 = max(b1, c1);
                    ov2 = min(b2, c2);

                    if ov2 >= ov1
                        % store in cycle-local coordinates
                        bad_segments = [bad_segments; ov1 - c1 + 1, ov2 - c1 + 1]; %#ok<AGROW>
                    end
                end
            end
        end

        overlap_idx = unique(overlap_idx, 'stable');

        cyc.overlapping_burst_idx{iC} = overlap_idx;
        cyc.overlapping_burst_numbers{iC} = overlap_idx;

        cyc.n_overlapping_bursts(iC) = numel(overlap_idx);
        cyc.has_any_burst(iC) = ~isempty(overlap_idx);

        if ~isempty(overlap_idx)
            cyc.has_good_burst(iC) = any(burst_keep(overlap_idx));
            cyc.has_bad_burst(iC)  = any(~burst_keep(overlap_idx));

            cyc.n_good_bursts(iC) = sum(burst_keep(overlap_idx));
            cyc.n_bad_bursts(iC)  = sum(~burst_keep(overlap_idx));
        else
            cyc.has_good_burst(iC) = false;
            cyc.has_bad_burst(iC)  = false;

            cyc.n_good_bursts(iC) = 0;
            cyc.n_bad_bursts(iC)  = 0;
        end

        % ---------- Compute bad-burst covered fraction ----------
        if isempty(bad_segments)
            cyc.bad_burst_overlap_segments{iC} = zeros(0,2);
            cyc.bad_burst_covered_samples(iC) = 0;
            cyc.bad_burst_fraction(iC) = 0;
        else
            merged_bad_segments = merge_segments_local(bad_segments);
            cyc.bad_burst_overlap_segments{iC} = merged_bad_segments;

            covered = sum(merged_bad_segments(:,2) - merged_bad_segments(:,1) + 1);
            cyc.bad_burst_covered_samples(iC) = covered;
            cyc.bad_burst_fraction(iC) = covered / cyc.cycle_length_samples(iC);
        end

        % ---------- Phase-of-interest / wavelet-aware bad burst checks ----------
        [flag_raw_phase, flag_padded_phase, badSegSec, badSegExpandedSec, phaseIntervals_sec] = ...
            check_bad_burst_phase_overlap( ...
                cyc.bad_burst_overlap_segments{iC}, ...
                cyc.cycle_length_samples(iC), ...
                fs, pairName, WCQ, OVERALL_BOUNDARY_SEC);

        % ---------- Band-specific phase-of-interest / wavelet contamination ----------
        for ib = 1:numel(bandNames)
            band = bandNames{ib};

            if strcmp(string(WCQ.boundary_type), "classical_coi")
                thisBoundarySec = BAND_BOUNDARIES.(band).coi_half_width_sec;
            elseif strcmp(string(WCQ.boundary_type), "amplitude_based")
                thisBoundarySec = BAND_BOUNDARIES.(band).amplitude_based_half_width_sec;
            else
                error('Unknown boundary_type: %s', string(WCQ.boundary_type));
            end

            thisBoundarySec = thisBoundarySec + WCQ.extra_buffer_sec;

            [~, flag_band_padded, ~, badSegBandExpandedSec, ~] = ...
                check_bad_burst_phase_overlap( ...
                    cyc.bad_burst_overlap_segments{iC}, ...
                    cyc.cycle_length_samples(iC), ...
                    fs, pairName, WCQ, thisBoundarySec);

            cyc.band_contaminated.(band)(iC) = flag_band_padded;
            cyc.band_bad_segments_padded_sec.(band){iC} = badSegBandExpandedSec;
        end

        cyc.has_bad_burst_in_phase_of_interest(iC) = flag_raw_phase;
        cyc.has_bad_burst_in_phase_of_interest_padded(iC) = flag_padded_phase;

        cyc.phase_intervals_sec{iC} = phaseIntervals_sec;
        cyc.bad_burst_segments_sec{iC} = badSegSec;
        cyc.bad_burst_segments_padded_sec{iC} = badSegExpandedSec;

        cyc.wavelet_phase_intervals_sec{iC} = phaseIntervals_sec;
        cyc.wavelet_bad_segments_sec{iC} = badSegSec;
        cyc.wavelet_bad_segments_expanded_sec{iC} = badSegExpandedSec;

        cyc.wavelet_contaminated_overall(iC) = flag_padded_phase;
        cyc.wavelet_keep_overall(iC) = ~flag_padded_phase;

        if flag_padded_phase
            cyc.wavelet_reason_overall(iC) = "bad_burst_too_close_to_phase_of_interest";
        else
            cyc.wavelet_reason_overall(iC) = "keep";
        end

        % ---------- General decision driven by non-band-specific config ----------
        reasons = strings(0,1);

        if P.cycle_policy.require_at_least_one_burst && ~cyc.has_any_burst(iC)
            reasons(end+1) = "no_burst_detected";
        end

        if P.cycle_policy.require_at_least_one_good_burst && ~cyc.has_good_burst(iC)
            reasons(end+1) = "no_good_burst";
        end

        if P.cycle_policy.reject_if_any_bad_burst && cyc.has_bad_burst(iC)
            reasons(end+1) = "contains_bad_burst";
        end

        if P.cycle_policy.reject_if_bad_burst_fraction_over && ...
                cyc.bad_burst_fraction(iC) > P.cycle_policy.parameters.max_bad_burst_fraction
            reasons(end+1) = "bad_burst_fraction_too_high";
        end

        if P.cycle_policy.reject_if_in_phase_of_interest && ...
                cyc.has_bad_burst_in_phase_of_interest(iC)
            reasons(end+1) = "bad_burst_in_phase_of_interest";
        end

        if P.cycle_policy.reject_flatline_cycles && cyc.is_flatline(iC)
            reasons(end+1) = "flatline_cycle";
        end

        if P.cycle_policy.reject_if_flatline_fraction_over && cyc.is_partly_flatline(iC)
            reasons(end+1) = "flatline_fraction_too_high";
        end

        if isempty(reasons)
            cyc.general_keep_mask(iC) = true;
            cyc.general_reason(iC) = "keep";
        else
            cyc.general_keep_mask(iC) = false;
            cyc.general_reason(iC) = strjoin(reasons, "+");
        end

        % ---------- Final legacy keep mask (overall padded version) ----------
        legacyReasons = reasons;

        if P.cycle_policy.reject_if_in_phase_of_interest_padded_for_wavelet_analysis && ...
                cyc.has_bad_burst_in_phase_of_interest_padded(iC)
            legacyReasons(end+1) = "bad_burst_too_close_to_phase_of_interest_for_wavelet";
        end

        if isempty(legacyReasons)
            cyc.cycle_keep_mask(iC) = true;
            cyc.cycle_reason(iC) = "keep";
        else
            cyc.cycle_keep_mask(iC) = false;
            cyc.cycle_reason(iC) = strjoin(legacyReasons, "+");
        end

        % ---------- Band-specific keep masks ----------
        for ib = 1:numel(bandNames)
            band = bandNames{ib};
            bandReasons = reasons;

            if cyc.band_contaminated.(band)(iC)
                bandReasons(end+1) = "bad_burst_too_close_to_phase_of_interest_for_" + string(band);
            end

            if isempty(bandReasons)
                cyc.band_keep_mask.(band)(iC) = true;
                cyc.band_reason.(band)(iC) = "keep";
            else
                cyc.band_keep_mask.(band)(iC) = false;
                cyc.band_reason.(band)(iC) = strjoin(bandReasons, "+");
            end
        end
    end

    % ---------- Detailed cycle table ----------
    cyc.cycle_table = table( ...
        repmat(string(subjID), nCycles,1), ...
        repmat(string(cond),   nCycles,1), ...
        repmat(string(leg),    nCycles,1), ...
        repmat(string(mf),     nCycles,1), ...
        repmat(string(pairName), nCycles,1), ...
        (1:nCycles)', ...
        cycle_starts(:), ...
        cycle_ends(:), ...
        cyc.cycle_length_samples, ...
        cyc.cycle_length_samples ./ fs, ...
        cyc.n_overlapping_bursts, ...
        cyc.n_good_bursts, ...
        cyc.n_bad_bursts, ...
        cyc.has_any_burst, ...
        cyc.has_good_burst, ...
        cyc.has_bad_burst, ...
        cyc.bad_burst_covered_samples, ...
        cyc.bad_burst_fraction, ...
        cyc.has_bad_burst_in_phase_of_interest, ...
        cyc.has_bad_burst_in_phase_of_interest_padded, ...
        cyc.cycle_ptp, ...
        cyc.cycle_std, ...
        cyc.is_flatline, ...
        cyc.flatline_covered_samples, ...
        cyc.flatline_fraction, ...
        cyc.is_partly_flatline, ...
        cyc.cycle_keep_mask, ...
        cyc.cycle_reason, ...
        cyc.general_keep_mask, ...
        cyc.general_reason, ...
        'VariableNames', { ...
        'subject','condition','leg','muscle','pair_name','cycle_number', ...
        'cycle_start_idx','cycle_end_idx','cycle_length_samples','cycle_length_sec', ...
        'n_overlapping_bursts','n_good_bursts','n_bad_bursts', ...
        'has_any_burst','has_good_burst','has_bad_burst', ...
        'bad_burst_covered_samples','bad_burst_fraction', ...
        'has_bad_burst_in_phase_of_interest', ...
        'has_bad_burst_in_phase_of_interest_padded', ...
        'cycle_ptp','cycle_std','is_flatline', ...
        'flatline_covered_samples','flatline_fraction','is_partly_flatline', ...
        'cycle_keep','cycle_reason', ...
        'general_keep_mask','general_reason'});

    % One contamination and one keep column per configured band
    for ib = 1:numel(bandNames)
        band = bandNames{ib};
        cyc.cycle_table.(['band_contaminated_' band]) = cyc.band_contaminated.(band);
    end
    for ib = 1:numel(bandNames)
        band = bandNames{ib};
        cyc.cycle_table.(['band_keep_mask_' band]) = cyc.band_keep_mask.(band);
    end
end