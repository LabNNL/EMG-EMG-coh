function v = unwrap_table_vector_entry(col, i)
% Works whether the table column stores:
%   - cell arrays of vectors
%   - direct numeric vectors
%   - 1x1 cells containing vectors

    v = [];

    try
        if iscell(col)
            v = col{i};
        else
            v = col(i);
        end

        % if still a cell, unwrap once more
        if iscell(v) && numel(v) == 1
            v = v{1};
        end

        % if table stored row objects oddly
        if isstring(v) || ischar(v) || iscategorical(v)
            v = [];
            return;
        end

        v = double(v);

    catch
        v = [];
    end
end
