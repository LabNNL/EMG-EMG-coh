function col = get_group_color(groupName, colorStruct)
    groupName = string(groupName);

    if isfield(colorStruct, char(groupName))
        col = colorStruct.(char(groupName));
    else
        % fallback if group name not found
        col = [0.6 0.6 0.6];
    end
end