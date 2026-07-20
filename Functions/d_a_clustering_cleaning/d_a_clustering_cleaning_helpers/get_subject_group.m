function groupName = get_subject_group(C, subjID)
    if isfield(C, 'groups') && isa(C.groups, 'containers.Map') && isKey(C.groups, subjID)
        groupName = C.groups(subjID);
    else
        groupName = 'Unknown';
    end
end
