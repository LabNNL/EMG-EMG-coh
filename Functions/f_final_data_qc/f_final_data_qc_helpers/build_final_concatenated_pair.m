function [final_sig_1, final_sig_2, Tseg] = build_final_concatenated_pair(x1, x2, cycle_starts, cycle_ends, pair_cycle_keep)

    final_sig_1 = [];
    final_sig_2 = [];

    rows = {};
    ri = 0;
    outStart1 = 1;
    outStart2 = 1;

    for iC = 1:numel(pair_cycle_keep)
        c1 = cycle_starts(iC);
        c2 = cycle_ends(iC);

        if ~pair_cycle_keep(iC)
            continue;
        end

        seg1 = x1(c1:c2);
        seg2 = x2(c1:c2);

        final_sig_1 = [final_sig_1; seg1]; %#ok<AGROW>
        final_sig_2 = [final_sig_2; seg2]; %#ok<AGROW>

        outEnd1 = outStart1 + numel(seg1) - 1;
        outEnd2 = outStart2 + numel(seg2) - 1;

        ri = ri + 1;
        rows(ri,:) = { ...
            iC, c1, c2, numel(seg1), ...
            outStart1, outEnd1, outStart2, outEnd2 ...
            };

        outStart1 = outEnd1 + 1;
        outStart2 = outEnd2 + 1;
    end

    if ~isempty(rows)
        Tseg = cell2table(rows, 'VariableNames', { ...
            'cycle_number','original_cycle_start_idx','original_cycle_end_idx','cycle_length_samples', ...
            'final_concat_start_idx_signal1','final_concat_end_idx_signal1', ...
            'final_concat_start_idx_signal2','final_concat_end_idx_signal2'});
    else
        Tseg = table();
    end
end