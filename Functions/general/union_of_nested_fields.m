function out = union_of_nested_fields(structList, fieldPath)
% Collect union of fieldnames across several nested structs
% fieldPath is a cell array, e.g. {'CTL_01','Plat','left'}

    out = {};

    for i = 1:numel(structList)
        S = structList{i};

        try
            T = S;
            for j = 1:numel(fieldPath)
                if ~isstruct(T) || ~isfield(T, fieldPath{j})
                    T = [];
                    break;
                end
                T = T.(fieldPath{j});
            end

            if isstruct(T)
                out = union(out, fieldnames(T));
            end
        catch
        end
    end
end
