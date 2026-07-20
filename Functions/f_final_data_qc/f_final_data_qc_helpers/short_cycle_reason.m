function out = short_cycle_reason(reasonIn)

    s = char(string(reasonIn));
    s = strrep(s, '_', ' ');

    parts = split(string(s), '+');
    shortParts = strings(size(parts));

    for i = 1:numel(parts)
        p = strtrim(lower(parts(i)));

        switch p
            case "no burst detected"
                shortParts(i) = "no burst";
            case "no good burst"
                shortParts(i) = "no good";
            case "contains bad burst"
                shortParts(i) = "bad burst";
            case "bad burst fraction too high"
                shortParts(i) = "bad frac";
            case "flatline cycle"
                shortParts(i) = "flatline";
            case "flatline fraction too high"
                shortParts(i) = "flat frac";
            otherwise
                shortParts(i) = p;
        end
    end

    if numel(shortParts) == 0
        out = "";
    elseif numel(shortParts) == 1
        out = char(shortParts(1));
    else
        % keep only first 2 reasons, one per line
        out = sprintf('%s\n%s', shortParts(1), shortParts(2));
    end
end
