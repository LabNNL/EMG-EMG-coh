function Tsub = average_cycle_triplet_legs(Trow)
% Average the <Band>_curve columns over legs within subject x condition x pair

    if isempty(Trow)
        Tsub = Trow;
        return;
    end

    curveVars = Trow.Properties.VariableNames(endsWith(Trow.Properties.VariableNames, '_curve'));

    [G, subj, ageg, cond, pairn] = findgroups( Trow.subject, Trow.age_group, Trow.condition, Trow.pair_name);

    nG = max(G);
    rows = cell(nG, 8 + numel(curveVars));

    for g = 1:nG
        idx = (G == g);
        Tg = Trow(idx,:);

        tvec = Tg.Time_percent{1};
        tvec = tvec(:)';   % force row vector

        curveMeans = cell(1, numel(curveVars));
        for k = 1:numel(curveVars)
            m = mean(cat(1, Tg.(curveVars{k}){:}), 1, 'omitnan');
            curveMeans{k} = {m(:)'};
        end

        rows(g,:) = [{ subj(g), ageg(g), cond(g), pairn(g), mean(Tg.n_cycles_used, 'omitnan'), {tvec}}, curveMeans, {mean(Tg.POI_StartPercent, 'omitnan'), mean(Tg.POI_EndPercent, 'omitnan')}];
    end

    Tsub = cell2table(rows, 'VariableNames', [{ 'subject','age_group','condition','pair_name','n_cycles_used', 'Time_percent'}, curveVars, {'POI_StartPercent','POI_EndPercent'}]);
end
