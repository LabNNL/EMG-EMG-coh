function x = fill_short_zeros_local(x, maxGap)
    % Fill zero gaps shorter than or equal to maxGap
    x = logical(x(:));

    z = ~x;
    d = diff([false; z; false]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;

    if isempty(starts), return; end

    lens = ends - starts + 1;
    shortZero = find(lens <= maxGap);

    for i = 1:numel(shortZero)
        r1 = starts(shortZero(i));
        r2 = ends(shortZero(i));

        % Fill only if gap is internal (surrounded by ones)
        if r1 > 1 && r2 < numel(x)
            if x(r1-1) && x(r2+1)
                x(r1:r2) = true;
            end
        end
    end
end
