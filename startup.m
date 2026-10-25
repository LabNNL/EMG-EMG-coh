function startup()
% STARTUP  Put this project on the MATLAB path.
%
% MATLAB runs this file automatically when it starts with the project root as
% the current folder. If you started MATLAB somewhere else, cd here and run
% `startup` once.
%
% Nothing else in the project adds config/ to the path, so config_emg() is not
% resolvable until this has run.

root = fileparts(mfilename('fullpath'));

addpath(root);
addpath(fullfile(root, 'config'));
addpath(genpath(fullfile(root, 'Functions')));

% Optional folders: present depending on what the checkout contains.
for folder = ["scripts", "Tools"]
    p = fullfile(root, folder);
    if isfolder(p)
        addpath(p);
    end
end

fprintf('EMG-EMG-coh on the path (%s)\n', root);
end
