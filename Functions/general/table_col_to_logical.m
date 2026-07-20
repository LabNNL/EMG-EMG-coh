function out = table_col_to_logical(x)

    if islogical(x)
        out = x(:);
        return;
    end

    if isnumeric(x)
        out = x(:) ~= 0;
        return;
    end

    if isstring(x) || ischar(x) || iscategorical(x)
        s = lower(strtrim(string(x)));
        out = (s == "1") | (s == "true") | (s == "yes");
        out = out(:);
        return;
    end

    if iscell(x)
        out = false(numel(x),1);

        for i = 1:numel(x)
            xi = x{i};

            if isempty(xi)
                out(i) = false;

            elseif islogical(xi)
                out(i) = any(xi(:));

            elseif isnumeric(xi)
                out(i) = any(xi(:) ~= 0);

            elseif isstring(xi) || ischar(xi) || iscategorical(xi)
                s = lower(strtrim(string(xi)));
                tf = (s == "1") | (s == "true") | (s == "yes");
                out(i) = any(tf(:));

            else
                error('Unsupported cell content type in table_col_to_logical.');
            end
        end
        return;
    end

    error('Unsupported type for logical conversion.');
end