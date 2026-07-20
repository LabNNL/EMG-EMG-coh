function [toe_off, note] = get_toe_off_in_concat_coordinates(E)
    toe_off = [];
    note = "";

    candidate_fields = {'toe_off_concat'};
    
    for i = 1:numel(candidate_fields)
        fn = candidate_fields{i};
        if isfield(E, fn) && ~isempty(E.(fn))
            toe_off = round(E.(fn)(:));
            note = string(fn);
            break;
        end
    end

    if ~isempty(toe_off)
        toe_off = toe_off(:);
        toe_off = toe_off(~isnan(toe_off));
        toe_off = unique(toe_off, 'stable');
    end
end
