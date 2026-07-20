
function [starts_pair, ends_pair, note] = harmonize_cycle_boundaries(st1, en1, st2, en2, n1, n2)
    note = "identical";

    st1 = round(st1(:));
    en1 = round(en1(:));
    st2 = round(st2(:));
    en2 = round(en2(:));

    st1 = st1(~isnan(st1));
    st2 = st2(~isnan(st2));

    en1 = en1(:);
    en2 = en2(:);

    % infer last end if needed
    if ~isempty(en1) && isnan(en1(end))
        en1(end) = n1;
    end
    if ~isempty(en2) && isnan(en2(end))
        en2(end) = n2;
    end

    % If end vectors are too short, infer from starts
    if numel(en1) ~= numel(st1)
        if numel(st1) >= 2
            en1 = [st1(2:end)-1; n1];
        else
            en1 = n1;
        end
        note = note + "+recomputed_end1";
    end

    if numel(en2) ~= numel(st2)
        if numel(st2) >= 2
            en2 = [st2(2:end)-1; n2];
        else
            en2 = n2;
        end
        note = note + "+recomputed_end2";
    end

    % simplest case: identical starts
    if isequal(st1, st2)
        starts_pair = st1;
        ends_pair = min(en1, en2);
    else
        % fallback: intersection of starts
        commonStarts = intersect(st1, st2, 'stable');

        if isempty(commonStarts)
            starts_pair = [];
            ends_pair = [];
            note = "no_common_cycle_starts";
            return;
        end

        starts_pair = commonStarts(:);
        ends_pair = [starts_pair(2:end)-1; min(n1,n2)];
        note = "used_common_cycle_starts_intersection";
    end

    % final safety cleanup
    starts_pair = starts_pair(:);
    ends_pair   = ends_pair(:);

    n = min(numel(starts_pair), numel(ends_pair));
    starts_pair = starts_pair(1:n);
    ends_pair   = ends_pair(1:n);

    valid = ~isnan(starts_pair) & ~isnan(ends_pair) & (ends_pair >= starts_pair);
    starts_pair = starts_pair(valid);
    ends_pair   = ends_pair(valid);
end
