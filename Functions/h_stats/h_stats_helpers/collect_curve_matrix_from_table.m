function X = collect_curve_matrix_from_table(col)
% Build an nRows x nTime matrix from a table column that may contain:
% - cell array of numeric vectors
% - numeric matrix already
% - odd scalar/cell wrappers

    X = [];

    if isempty(col)
        return;
    end

    % Case 1: already numeric matrix
    if isnumeric(col)
        X = double(col);
        return;
    end

    % Case 2: cell array of vectors
    if iscell(col)
        vecs = cell(size(col));

        for i = 1:numel(col)
            v = col{i};

            if iscell(v) && numel(v) == 1
                v = v{1};
            end

            if isempty(v)
                continue;
            end

            v = double(v(:))';   % force row vector
            vecs{i} = v;
        end

        lens = cellfun(@numel, vecs);
        lens = lens(lens > 0);

        if isempty(lens)
            return;
        end

        nTime = min(lens);   % keep common length safely
        nRows = numel(vecs);

        X = nan(nRows, nTime);
        for i = 1:nRows
            v = vecs{i};
            if isempty(v)
                continue;
            end
            X(i,:) = v(1:nTime);
        end

        return;
    end

    % Fallback
    try
        X = double(col);
    catch
        X = [];
    end
end
