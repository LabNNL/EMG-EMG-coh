function [C1, C2] = extract_resampled_real_cycles(SRC, nSamples)

    x1 = SRC.x1(:);
    x2 = SRC.x2(:);
    Tseg = SRC.Tseg;
    validCycles = SRC.valid_cycle_numbers(:);

    C1 = [];
    C2 = [];

    requiredCols = { ...
        'cycle_number', ...
        'final_concat_start_idx_signal1', ...
        'final_concat_end_idx_signal1', ...
        'final_concat_start_idx_signal2', ...
        'final_concat_end_idx_signal2'};

    for iCol = 1:numel(requiredCols)
        if ~ismember(requiredCols{iCol}, Tseg.Properties.VariableNames)
            error('Missing column in Tseg: %s', requiredCols{iCol});
        end
    end

    for i = 1:numel(validCycles)

        cyc = validCycles(i);

        rowIdx = find(Tseg.cycle_number == cyc, 1, 'first');

        if isempty(rowIdx)
            continue
        end

        idxStart1 = round(double(Tseg.final_concat_start_idx_signal1(rowIdx)));
        idxEnd1   = round(double(Tseg.final_concat_end_idx_signal1(rowIdx)));

        idxStart2 = round(double(Tseg.final_concat_start_idx_signal2(rowIdx)));
        idxEnd2   = round(double(Tseg.final_concat_end_idx_signal2(rowIdx)));

        if idxStart1 < 1 || idxEnd1 > numel(x1) || idxEnd1 <= idxStart1
            continue
        end

        if idxStart2 < 1 || idxEnd2 > numel(x2) || idxEnd2 <= idxStart2
            continue
        end

        seg1 = x1(idxStart1:idxEnd1);
        seg2 = x2(idxStart2:idxEnd2);

        if numel(seg1) < 10 || numel(seg2) < 10
            continue
        end

        seg1 = resample_to_length(seg1, nSamples);
        seg2 = resample_to_length(seg2, nSamples);

        seg1 = normalize_cycle(seg1);
        seg2 = normalize_cycle(seg2);

        C1(:,end+1) = seg1; %#ok<AGROW>
        C2(:,end+1) = seg2; %#ok<AGROW>
    end
end


