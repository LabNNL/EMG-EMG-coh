function T = build_cycle_triplet_table_from_results(COH, C, HC)

    rows = {};
    ri = 0;

    subjects = fieldnames(COH);

    for iS = 1:numel(subjects)
        subjID = subjects{iS};
        age_group = subject_to_group(subjID, C);

        conds = fieldnames(COH.(subjID));
        for ic = 1:numel(conds)
            cond = conds{ic};

            legs = fieldnames(COH.(subjID).(cond));
            for il = 1:numel(legs)
                leg = legs{il};

                pairNames = fieldnames(COH.(subjID).(cond).(leg));
                for ip = 1:numel(pairNames)
                    pairName = pairNames{ip};

                    if ~ismember(string(pairName), string(HC.analysis.pairs_to_analyze))
                        continue;
                    end

                    R = COH.(subjID).(cond).(leg).(pairName);
                    if isempty(R)
                        continue;
                    end

                    nCycles = get_field_or_nan(R, 'n_cycles_used');
                    if isnan(nCycles) || nCycles < HC.analysis.min_cycles_required
                        continue;
                    end

                    if ~isfield(R, 'Freq') || isempty(R.Freq) || ~isfield(R, 'Time_percent') || isempty(R.Time_percent)
                        continue;
                    end

                    switch lower(string(HC.analysis.cycle_triplet_source))
                        case "sig"
                            if ~isfield(R, 'Coherence_sig') || isempty(R.Coherence_sig)
                                continue;
                            end
                            M = R.Coherence_sig;
                        case "sig_equalized"
                            if ~isfield(R, 'Coherence_sig_equalized') || isempty(R.Coherence_sig_equalized)
                                continue;
                            end
                            M = R.Coherence_sig_equalized;
                        case "sig_common_threshold"
                            if ~isfield(R, 'Coherence_sig_common_threshold') || isempty(R.Coherence_sig_common_threshold)
                                continue;
                            end
                            M = R.Coherence_sig_common_threshold;
                        case "zcoh_bokil"
                            if ~isfield(R, 'Coherence_zcoh_bokil') || isempty(R.Coherence_zcoh_bokil)
                                continue;
                            end
                            M = R.Coherence_zcoh_bokil;
                        otherwise
                            if ~isfield(R, 'Coherence') || isempty(R.Coherence)
                                continue;
                            end
                            M = R.Coherence;
                    end

                    freq = R.Freq(:);
                    tvec = R.Time_percent(:)';

                    if size(M,1) ~= numel(freq) || size(M,2) ~= numel(tvec)
                        continue;
                    end

                    alphaCurve = mean_band_over_time(M, freq, 'Alpha');
                    betaCurve  = mean_band_over_time(M, freq, 'Beta');
                    gammaCurve = mean_band_over_time(M, freq, 'Gamma');

                    if ~isfield(R, 'Time_percent') || isempty(R.Time_percent)
                        fprintf('R.Time_percent missing or empty\n');
                    end

                    if ~any(isfinite(alphaCurve))
                        fprintf('Alpha all non-finite\n');
                    end

                    if ~any(isfinite(betaCurve))
                        fprintf('Beta all non-finite\n');
                    end

                    if ~any(isfinite(gammaCurve))
                        fprintf('Gamma all non-finite\n');
                    end

                    if all(isnan(alphaCurve)) && all(isnan(betaCurve)) && all(isnan(gammaCurve))
                        continue;
                    end

                    ri = ri + 1;
                    rows(ri,:) = { categorical(string(subjID)), categorical(string(age_group), C.plotting.age_order, C.plotting.age_order, 'Ordinal', true), categorical(string(cond), C.plotting.condition_order, C.plotting.condition_order, 'Ordinal', true), categorical(string(leg), C.design.legs, C.design.legs, 'Ordinal', true), categorical(string(pairName), HC.analysis.pairs_to_analyze, HC.analysis.pairs_to_analyze, 'Ordinal', true), nCycles, {tvec}, {alphaCurve}, {betaCurve}, {gammaCurve}, get_nested_field_or_nan(R, {'POI','start_pct'}), get_nested_field_or_nan(R, {'POI','end_pct'}) };
                end
            end
        end
    end

    if isempty(rows)
        T = table();
        return;
    end

    T = cell2table(rows, 'VariableNames', { 'subject','age_group','condition','leg','pair_name','n_cycles_used', 'Time_percent','Alpha_curve','Beta_curve','Gamma_curve', 'POI_StartPercent','POI_EndPercent'});
end

function val = get_nested_field_or_nan(S, fieldPath)

    val = NaN;

    try
        tmp = S;
        for i = 1:numel(fieldPath)
            tmp = tmp.(fieldPath{i});
        end

        if ~isempty(tmp) && isnumeric(tmp) && isscalar(tmp)
            val = tmp;
        end
    catch
        val = NaN;
    end
end

function curve = mean_band_over_time(M, freq, bandName)

    switch char(string(bandName))
        case 'Alpha'
            fr = [8 12];
        case 'Beta'
            fr = [13 30];
        case 'Gamma'
            fr = [31 150];
        otherwise
            curve = nan(1, size(M,2));
            return;
    end

    idxF = freq >= fr(1) & freq <= fr(2);

    if ~any(idxF)
        curve = nan(1, size(M,2));
        return;
    end

    curve = mean(M(idxF,:), 1, 'omitnan');
    curve = curve(:)';
end
