function Tsub = average_cycle_triplet_legs(Trow)

    if isempty(Trow)
        Tsub = Trow;
        return;
    end

    [G, subj, ageg, cond, pairn] = findgroups( Trow.subject, Trow.age_group, Trow.condition, Trow.pair_name);

    nG = max(G);
    rows = cell(nG, 11);

    for g = 1:nG
        idx = (G == g);
        Tg = Trow(idx,:);

        alphaMat = cat(1, Tg.Alpha_curve{:});
        betaMat  = cat(1, Tg.Beta_curve{:});
        gammaMat = cat(1, Tg.Gamma_curve{:});

        tvec = Tg.Time_percent{1};
        tvec = tvec(:)';   % force row vector

        alphaMean = mean(alphaMat, 1, 'omitnan');
        betaMean  = mean(betaMat, 1, 'omitnan');
        gammaMean = mean(gammaMat, 1, 'omitnan');

        alphaMean = alphaMean(:)';
        betaMean  = betaMean(:)';
        gammaMean = gammaMean(:)';

        rows(g,:) = { subj(g), ageg(g), cond(g), pairn(g), mean(Tg.n_cycles_used, 'omitnan'), {tvec}, {alphaMean}, {betaMean}, {gammaMean}, mean(Tg.POI_StartPercent, 'omitnan'), mean(Tg.POI_EndPercent, 'omitnan') };
    end

    Tsub = cell2table(rows, 'VariableNames', { 'subject','age_group','condition','pair_name','n_cycles_used', 'Time_percent','Alpha_curve','Beta_curve','Gamma_curve', 'POI_StartPercent','POI_EndPercent'});
end