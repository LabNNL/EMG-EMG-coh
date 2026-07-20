function EMG_PREPROC = pp_init_subject_struct(P, inFile, subjID)
EMG_PREPROC = struct();
EMG_PREPROC.(subjID) = struct();
EMG_PREPROC.(subjID).meta = P;
EMG_PREPROC.(subjID).meta.source_file = inFile;
end