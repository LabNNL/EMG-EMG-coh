function fs = pp_get_fs(P)
if isempty(P.fs)
    error("P.fs is empty. Set EMG sampling rate (Hz) in b_config().");
end
fs = P.fs;

end