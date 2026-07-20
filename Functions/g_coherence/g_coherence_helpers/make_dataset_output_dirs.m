function datasetDirs = make_dataset_output_dirs(datasetName, IO, PL, GP, FP, W)

    datasetDirs = struct();

    % ---------- Per-entry plot folders ----------
    datasetDirs.individualDir = fullfile(PL.individual_plots_dir, char(datasetName));
    if ~exist(datasetDirs.individualDir, 'dir')
        mkdir(datasetDirs.individualDir);
    end

    datasetDirs.beforeAfterDir = fullfile(PL.before_after_plots_dir, char(datasetName));
    if ~exist(datasetDirs.beforeAfterDir, 'dir')
        mkdir(datasetDirs.beforeAfterDir);
    end

    % ---------- Group / final plot folders ----------
    datasetDirs.groupDir = fullfile(GP.dir, char(datasetName));
    if ~exist(datasetDirs.groupDir, 'dir')
        mkdir(datasetDirs.groupDir);
    end

    datasetDirs.finalDir = fullfile(FP.dir, char(datasetName));
    if ~exist(datasetDirs.finalDir, 'dir')
        mkdir(datasetDirs.finalDir);
    end

    % ---------- QC folders ----------
    % Keep using the coherence QC base directory already defined in config
    datasetDirs.qcDir = fullfile(W.qc_edge.dir, char(datasetName));
    if ~exist(datasetDirs.qcDir, 'dir')
        mkdir(datasetDirs.qcDir);
    end

    datasetDirs.outerCycleDiagDir = fullfile(datasetDirs.qcDir, 'outer_cycle_diagnostics');
    if ~exist(datasetDirs.outerCycleDiagDir, 'dir')
        mkdir(datasetDirs.outerCycleDiagDir);
    end
end