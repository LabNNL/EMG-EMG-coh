%% b_preprocess_emg_for_coherence
% Preprocessing of concatenated raw EMG signals for coherence analysis.
%
% GENERAL PRINCIPLE
% -------------------------------------------------------------------------
% This step takes the concatenated raw EMG signals extracted from the .c3d
% files (subject × condition × leg × muscle) and applies a minimal,
% deterministic preprocessing pipeline to make the signals ready for spectral
% / coherence computations.
%
% The preprocessing pipeline is:
%   1) remove DC offset (demeaning)
%   2) apply zero-phase bandpass filtering (default: 8–450 Hz)
%   3) optionally apply a notch filter (50/60 Hz) if line noise is present
%   4) optionally apply full-wave rectification (|EMG|)
%   5) optionally apply z-score normalization (typically OFF for coherence)
%
% IMPORTANT DESIGN CHOICE
% -------------------------------------------------------------------------
% This step is intentionally kept "basic" and does NOT make exclusion
% decisions (artifact rejection, signal usability, cross-talk handling).
% Those decisions are handled in later QC / cleaning steps to keep the
% workflow transparent and reproducible.
%
% INPUT / OUTPUT
% -------------------------------------------------------------------------
% Input:
%   - *_RAW_CYCLES_CONCAT.mat files containing CYCLES_SIGNAL_RAW
%
% Output:
%   - *_EMG_PREPROC.mat files containing EMG_PREPROC, where:
%       * the hierarchy matches CYCLES_SIGNAL_RAW (subj × cond × leg × muscle)
%       * all original metadata fields are copied through (e.g., n_cycles,
%         cycle_lengths, cycle_starts/ends, toe-off info, provenance)
%       * the field .signal is overwritten with the preprocessed signal
%       * the original raw signal is also kept as .signal_raw for convenience
%
% QC / VISUALIZATION
% -------------------------------------------------------------------------
% - Optionally saves a full-length plot of each preprocessed concatenated
%   signal (same naming convention as the raw plots).
% - Optionally generates a small set of random QC figures comparing raw vs
%   filtered vs rectified signals, and their PSD (Welch), to verify that the
%   filtering behaves as expected.
%
% MAIN PARAMETERS THAT CONTROL BEHAVIOR (see config_emg.m)
% -------------------------------------------------------------------------
% Filtering:
%   - C.b_preproc.fs
%   - C.b_preproc.bandpass
%   - C.b_preproc.use_notch, C.b_preproc.notch_hz
%
% Optional transforms:
%   - C.b_preproc.rectify
%   - C.b_preproc.normalize
%
% QC plotting:
%   - C.b_preproc.save_preproc_png
%   - C.b_preproc.plot_random_examples
%   - C.b_preproc.n_random_examples
%   - C.b_preproc.plot_seconds
% -------------------------------------------------------------------------
function b_preprocess_emg()

    C = config_emg();
    P = C.b_preproc;

    IN_DIR = C.paths.raw_dir;
    OUT_DIR = C.paths.preproc_dir;
    PNG_DIR = C.paths.preproc_plot_dir;
    PNG_QC_DIR = C.paths.preproc_qc_plot_dir;

    addpath(genpath(C.paths.helpers.preprocessing));
    addpath(genpath(C.paths.helpers.general));

    if ~exist(OUT_DIR,'dir')
        mkdir(OUT_DIR);
    end

    if P.plot_random_examples && ~exist(PNG_QC_DIR,'dir')
        mkdir(PNG_QC_DIR);
    end

    files = dir(fullfile(IN_DIR, P.input_pattern));
    assert(~isempty(files), "No %s found in %s", P.input_pattern, IN_DIR);

    %% ===================== Main loop: preprocess each subject's raw cycles and save =====================

    plotCandidates = {};
    pc = 0;

    for f = 1:numel(files)
        inFile = fullfile(files(f).folder, files(f).name);
        L = load(inFile);
        assert(isfield(L,'CYCLES_SIGNAL_RAW'), "Missing CYCLES_SIGNAL_RAW in %s", inFile);

        subjID = pp_get_subjID(L);
        fprintf("\n=== Preprocess: %s ===\n", subjID);

        EMG_PREPROC = pp_init_subject_struct(P, inFile, subjID);

        [EMG_PREPROC, plotCandidates, pc] = pp_process_subject( L.CYCLES_SIGNAL_RAW, subjID, EMG_PREPROC, P, PNG_DIR, plotCandidates, pc);

        outFile = fullfile(OUT_DIR, sprintf('%s_EMG_PREPROC.mat', subjID));
        save(outFile, 'EMG_PREPROC', '-v7.3');
        fprintf("Saved: %s\n", outFile);

    end

    %% ===================== Post-processing & QC =====================

    % Random QC plots (time + PSD) from collected candidates
    if P.plot_random_examples && ~isempty(plotCandidates)
        preprocessing_qc_plots(P, plotCandidates, PNG_QC_DIR);
    end

    % Find one random output mat file and inspect its structure with disp_tree
    qc_files = dir(fullfile(OUT_DIR, '*_EMG_PREPROC.mat'));
    if ~isempty(qc_files)
        sample_file = fullfile(qc_files(1).folder, qc_files(1).name);
        fprintf("\nInspecting structure of a sample preprocessed file:\n%s\n", sample_file);
        L = load(sample_file);
        if isfield(L, 'EMG_PREPROC')
            disp_tree(L.EMG_PREPROC, 3);
        else
            warning('EMG_PREPROC variable not found in loaded file. Cannot display structure.');
        end
    else
        warning('No preprocessed files found to inspect.');
    end
end