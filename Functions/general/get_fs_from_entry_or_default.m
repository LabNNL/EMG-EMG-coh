function fs = get_fs_from_entry_or_default(E, C)
    if isfield(E,'fs') && ~isempty(E.fs)
        fs = E.fs;
    elseif isfield(C,'general') && isfield(C.general,'fs_emg') && ~isempty(C.general.fs_emg)
        fs = C.general.fs_emg;
    else
        fs = 2000;
    end
end