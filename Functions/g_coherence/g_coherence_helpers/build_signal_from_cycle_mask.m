function x_out = build_signal_from_cycle_mask(x, Tseg, cycleMask, whichSignal)

    x = x(:);
    x_out = [];

    if isempty(cycleMask) || isempty(Tseg)
        return;
    end

    if whichSignal == 1
        startField = 'final_concat_start_idx_signal1';
        endField   = 'final_concat_end_idx_signal1';
    else
        startField = 'final_concat_start_idx_signal2';
        endField   = 'final_concat_end_idx_signal2';
    end

    if ~ismember(startField, Tseg.Properties.VariableNames) || ...
       ~ismember(endField, Tseg.Properties.VariableNames)
        return;
    end

    idxCycles = find(cycleMask);

    for i = 1:numel(idxCycles)
        iC = idxCycles(i);

        s = Tseg.(startField)(iC);
        e = Tseg.(endField)(iC);

        if isfinite(s) && isfinite(e) && e > s && s >= 1 && e <= numel(x)
            x_out = [x_out; x(s:e)]; %#ok<AGROW>
        end
    end
end