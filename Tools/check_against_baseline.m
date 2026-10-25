function R = check_against_baseline(varargin)
% CHECK_AGAINST_BASELINE  Do the stage f/g/h tables still hold the same numbers?
%
%   check_against_baseline('MakeReference', true)   save the current tables as the reference
%   R = check_against_baseline()                    compare the current tables to it
%
% Options
%   'Reference'      reference folder (default Results/_reference_tables)
%   'MakeReference'  copy the current tables into 'Reference' instead of comparing
%   'Tol'            numeric tolerance, absolute or relative (default 1e-10)
%   'Stages'         Results subfolders to cover (default the f, g and h outputs)
%
% Compares every .csv and every sheet of every .xlsx: same files, same
% columns, same rows, numbers equal to within Tol, text identical. Figures
% and the text model reports are not compared (their bytes and layout vary
% with MATLAB version and figure size). Use it after any change that is
% meant to leave the results alone: refactors, renames, clean-ups.
%
% Returns one row per table: status "same", "within_tol", "differs",
% "missing" (in the current run) or "new" (not in the reference).

opt = parse_args(varargin);
C   = config_emg();
if isempty(opt.Reference)
    opt.Reference = fullfile(C.paths.results_dir, '_reference_tables');
end

if opt.MakeReference
    make_reference(C.paths.results_dir, opt.Reference, opt.Stages);
    R = table();
    return;
end

assert(isfolder(opt.Reference), 'No reference at %s. Run check_against_baseline(''MakeReference'', true) first.', opt.Reference);

refFiles = list_tables(opt.Reference, opt.Stages);
curFiles = list_tables(C.paths.results_dir, opt.Stages);

% A sync client (OneDrive) rewriting a file while MATLAB writes it leaves an
% empty file and a copy named '<name> 2.csv'. Say so instead of a cryptic diff.
conflicts = curFiles(~cellfun(@isempty, regexp(cellstr(curFiles), ' \d+\.(csv|xlsx)$', 'once')));
for k = 1:numel(conflicts)
    warning('check_against_baseline:syncConflict', 'Looks like a sync-conflict copy: %s. Compare it with the original and keep the complete one.', conflicts(k));
end

rows = {};
for k = 1:numel(refFiles)
    rel = refFiles(k);
    cur = fullfile(C.paths.results_dir, rel);
    if ~isfile(cur)
        rows(end+1, :) = {rel, "", "missing", NaN, "not in the current run"}; %#ok<AGROW>
        continue;
    end
    d = dir(cur);
    if d.bytes == 0
        rows(end+1, :) = {rel, "", "differs", NaN, "empty file (interrupted write or sync conflict)"}; %#ok<AGROW>
        continue;
    end
    for sheet = sheets_of(fullfile(opt.Reference, rel))
        [status, maxDiff, note] = compare_tables(fullfile(opt.Reference, rel), cur, sheet, opt.Tol);
        rows(end+1, :) = {rel, sheet, status, maxDiff, note}; %#ok<AGROW>
    end
end
for rel = setdiff(curFiles, refFiles)'
    rows(end+1, :) = {rel, "", "new", NaN, "not in the reference"}; %#ok<AGROW>
end

R = cell2table(rows, 'VariableNames', {'file','sheet','status','max_abs_diff','note'});

nBad = sum(ismember(R.status, ["differs","missing"]));
fprintf('\n%d tables compared against %s\n', height(R), opt.Reference);
fprintf('  same %d | within tol %d | differs %d | missing %d | new %d\n', ...
    sum(R.status == "same"), sum(R.status == "within_tol"), sum(R.status == "differs"), ...
    sum(R.status == "missing"), sum(R.status == "new"));
if nBad > 0
    disp(R(ismember(R.status, ["differs","missing"]), :));
else
    fprintf('  no differences beyond %g\n', opt.Tol);
end
end

% ---------------------------------------------------------------------------

function make_reference(resultsDir, refDir, stages)
    files = list_tables(resultsDir, stages);
    for rel = files'
        dst = fullfile(refDir, rel);
        if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
        copyfile(fullfile(resultsDir, rel), dst);
    end
    fid = fopen(fullfile(refDir, 'REFERENCE_INFO.txt'), 'w');
    fprintf(fid, 'Reference tables copied %s from %s\n', string(datetime('now')), resultsDir);
    [~, head] = system('git rev-parse --short HEAD');
    fprintf(fid, 'Code at commit %s\n', strtrim(head));
    fclose(fid);
    fprintf('Saved %d tables to %s\n', numel(files), refDir);
end

function files = list_tables(root, stages)
% Relative paths of the .csv/.xlsx tables under root/<stage>, skipping archives
    files = strings(0, 1);
    for st = string(stages)
        F = [dir(fullfile(root, st, '**', '*.csv')); dir(fullfile(root, st, '**', '*.xlsx'))];
        for k = 1:numel(F)
            p = string(fullfile(F(k).folder, F(k).name));
            rel = extractAfter(p, strlength(string(root)) + 1);
            if contains(rel, ["_stale_", "_archive", "~$"]), continue; end
            files(end+1, 1) = rel; %#ok<AGROW>
        end
    end
    files = sort(files);
end

function s = sheets_of(file)
    if endsWith(file, '.xlsx')
        s = string(sheetnames(file))';
    else
        s = "";
    end
end

function [status, maxDiff, note] = compare_tables(refFile, curFile, sheet, tol)
    args = {'TextType', 'string', 'VariableNamingRule', 'preserve'};
    if sheet ~= ""
        args = [args, {'Sheet', sheet}];
    end
    A = readtable(refFile, args{:});
    B = readtable(curFile, args{:});
    maxDiff = 0;
    note = "";

    if ~isequal(A.Properties.VariableNames, B.Properties.VariableNames)
        status = "differs";
        note = "columns: " + strjoin(string(setxor(A.Properties.VariableNames, B.Properties.VariableNames)), ", ");
        if note == "columns: ", note = "column order differs"; end
        return;
    end
    if height(A) ~= height(B)
        status = "differs";
        note = sprintf('rows %d -> %d', height(A), height(B));
        return;
    end

    bad = strings(0, 1);
    for v = string(A.Properties.VariableNames)
        a = A.(v); b = B.(v);
        if isnumeric(a) && isnumeric(b)
            d = abs(double(a) - double(b));
            d(isnan(a) & isnan(b)) = 0;
            scale = max(1, abs(double(a)));
            if any(isnan(a) ~= isnan(b), 'all') || any(d ./ scale > tol, 'all')
                bad(end+1) = v; %#ok<AGROW>
            end
            maxDiff = max([maxDiff; d(isfinite(d))]);
        elseif ~isequaln(string(a), string(b))
            bad(end+1) = v; %#ok<AGROW>
        end
    end

    if ~isempty(bad)
        status = "differs";
        note = "columns: " + strjoin(bad, ", ");
    elseif maxDiff == 0
        status = "same";
    else
        status = "within_tol";
    end
end

function opt = parse_args(args)
    p = inputParser;
    p.addParameter('Reference', '');
    p.addParameter('MakeReference', false);
    p.addParameter('Tol', 1e-10);
    p.addParameter('Stages', ["f_cycle_level_qc_and_signal_rebuild", "g_emg_emg_wavelet_coherence", "h_coherence_stats_pair_phase_main"]);
    p.parse(args{:});
    opt = p.Results;
end
