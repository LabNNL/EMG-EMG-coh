function merged = merge_segments_local(segs)
    % segs = [start end] in local coordinates
    if isempty(segs)
        merged = zeros(0,2);
        return;
    end

    segs = sortrows(segs, 1);
    merged = segs(1,:);

    for i = 2:size(segs,1)
        cur = segs(i,:);
        last = merged(end,:);

        if cur(1) <= last(2) + 1
            % overlap or touch -> merge
            merged(end,2) = max(last(2), cur(2));
        else
            merged = [merged; cur]; %#ok<AGROW>
        end
    end
end