function Sexp = build_export_final_paired_signals(Smaster, mode)

    Sexp = struct();

    subjFields = fieldnames(Smaster);
    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};

        condFields = fieldnames(Smaster.(subjID));
        for ic = 1:numel(condFields)
            cond = condFields{ic};

            legFields = fieldnames(Smaster.(subjID).(cond));
            for il = 1:numel(legFields)
                leg = legFields{il};

                pairFields = fieldnames(Smaster.(subjID).(cond).(leg));
                for ip = 1:numel(pairFields)
                    pairName = pairFields{ip};

                    P = Smaster.(subjID).(cond).(leg).(pairName);
                    Q = P;

                    switch string(mode)

                        case "overall"
                            Q.export_mode = "overall";

                            if ~isfield(Q, 'excluded_by_crosstalk')
                                Q.excluded_by_crosstalk = false;
                            end
                            if ~isfield(Q, 'crosstalk_reason')
                                Q.crosstalk_reason = "";
                            end
                            if ~isfield(Q, 'included_after_crosstalk')
                                Q.included_after_crosstalk = Q.included_for_analysis && ~Q.excluded_by_crosstalk;
                            end

                        case {"Alpha","Beta","Gamma"}
                            band = char(string(mode));

                            if ~isfield(P, 'band_specific') || ~isfield(P.band_specific, band)
                                warning('Missing band_specific.%s for %s | %s | %s | %s', ...
                                    band, subjID, cond, leg, pairName);
                                continue;
                            end

                            B = P.band_specific.(band);

                            Q.export_mode = string(band);

                            Q.pair_cycle_keep_mask  = B.pair_cycle_keep_mask;
                            Q.pair_cycle_reason     = B.pair_cycle_reason;
                            Q.valid_cycle_numbers   = B.valid_cycle_numbers;
                            Q.removed_cycle_numbers = B.removed_cycle_numbers;
                            Q.n_valid_cycles        = B.n_valid_cycles;

                            Q.included_for_analysis = B.included_for_analysis;

                            if isfield(B, 'excluded_by_crosstalk')
                                Q.excluded_by_crosstalk = B.excluded_by_crosstalk;
                            elseif isfield(P, 'excluded_by_crosstalk')
                                Q.excluded_by_crosstalk = P.excluded_by_crosstalk;
                            else
                                Q.excluded_by_crosstalk = false;
                            end

                            if isfield(B, 'crosstalk_reason')
                                Q.crosstalk_reason = B.crosstalk_reason;
                            elseif isfield(P, 'crosstalk_reason')
                                Q.crosstalk_reason = P.crosstalk_reason;
                            else
                                Q.crosstalk_reason = "";
                            end

                            if isfield(B, 'included_after_crosstalk')
                                Q.included_after_crosstalk = B.included_after_crosstalk;
                            else
                                Q.included_after_crosstalk = ...
                                    B.included_for_analysis && ~Q.excluded_by_crosstalk;
                            end

                            if ~B.included_for_analysis
                                Q.exclusion_reason = "too_few_valid_cycles";
                            elseif Q.excluded_by_crosstalk
                                Q.exclusion_reason = "excluded_by_crosstalk";
                            else
                                Q.exclusion_reason = "";
                            end

                            Q.final_concatenated_signal_1 = B.final_concatenated_signal_1;
                            Q.final_concatenated_signal_2 = B.final_concatenated_signal_2;
                            Q.final_cycle_segments_table  = B.final_cycle_segments_table;

                            Q.muscle1_cycle_qc.cycle_keep_mask = P.muscle1_cycle_qc.band_keep_mask.(band);
                            Q.muscle2_cycle_qc.cycle_keep_mask = P.muscle2_cycle_qc.band_keep_mask.(band);

                            Q.muscle1_cycle_qc.cycle_reason = P.muscle1_cycle_qc.band_reason.(band);
                            Q.muscle2_cycle_qc.cycle_reason = P.muscle2_cycle_qc.band_reason.(band);

                        otherwise
                            error('Unknown export mode: %s', string(mode));
                    end

                    Sexp = ensure_pair_fields(Sexp, subjID, cond, leg);
                    Sexp.(subjID).(cond).(leg).(pairName) = Q;
                end
            end
        end
    end
end