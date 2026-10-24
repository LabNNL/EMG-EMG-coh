function P = local_paths()
% LOCAL_PATHS  Machine-specific paths for this project.
%
% SETUP: copy this file to config/local_paths.m and set the path below to
% match your machine. local_paths.m is git-ignored, so your copy stays local
% and never conflicts with anyone else's.
%
% The code directory is not listed here: config_emg() derives it from its own
% location, so it needs no configuration.

% Folder holding the raw data and the intermediate .mat files.
% It is expected to contain a Reworked_Data/ subfolder with the .c3d files;
% mat_data/ is created inside it by the pipeline.
P.project_data_root = '/path/to/your/Coherence';

end
