function fs = get_fs_from_entry_or_config(entry, C)
    candidateFields = {'fs','Fs','sample_rate','sampling_rate','freq','Freq'};
    fs = [];

    for i = 1:numel(candidateFields)
        if isfield(entry, candidateFields{i}) && ~isempty(entry.(candidateFields{i}))
            fs = entry.(candidateFields{i});
            break;
        end
    end

    if isempty(fs)
        if isfield(C, 'general') && isfield(C.general, 'fs_emg') && ~isempty(C.general.fs_emg)
            fs = C.general.fs_emg;
        else
            error('Sampling frequency not found in signal entry or config.');
        end
    end
end
