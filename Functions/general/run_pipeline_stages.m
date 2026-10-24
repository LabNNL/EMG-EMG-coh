function run_pipeline_stages(stages, pipelineName)
% RUN_PIPELINE_STAGES  Run the enabled stages of a pipeline, in order.
%
%   run_pipeline_stages(stages, pipelineName)
%
%   stages : N x 4 cell array, one row per stage:
%            {enabled (logical), function folder, function name, label}
%
%   The stage folder (with subfolders) is added to the path before the stage
%   runs. Errors are not caught: a failing stage stops the pipeline, so later
%   stages never run on stale inputs.

if nargin < 2
    pipelineName = 'Pipeline';
end

tAll = tic;
nRun = 0;

fprintf('\n===== %s =====\n', pipelineName);
for i = 1:size(stages, 1)
    [enabled, folder, fname, label] = stages{i, :};

    if ~enabled
        fprintf('[skip] %s\n', label);
        continue
    end

    fprintf('\n[run ] %s (%s)\n', label, fname);
    addpath(genpath(folder));
    tStage = tic;
    feval(fname);
    fprintf('[done] %s in %s\n', label, format_elapsed(toc(tStage)));
    nRun = nRun + 1;
end
fprintf('\n===== %s finished: %d stage(s) run in %s =====\n', ...
    pipelineName, nRun, format_elapsed(toc(tAll)));
end

function s = format_elapsed(sec)
s = char(duration(0, 0, sec, 'Format', 'hh:mm:ss'));
end
