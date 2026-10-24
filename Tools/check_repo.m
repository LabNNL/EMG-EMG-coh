function cr_findings = check_repo(varargin)
% CHECK_REPO  Static checks for the EMG-EMG-coh repository.
%
%   check_repo()                 run every check and print a report
%   F = check_repo()             also return the findings as a table
%   check_repo('Checks', {...})  run a subset
%   check_repo('Save', 'f.txt')  also write the report to a file
%
% Checks:
%   config_double   config fields assigned more than once (the later one wins)
%   config_missing  C.<path> read by code but not defined by config_emg()
%   config_dead     config fields assigned but never read (informational)
%   duplicates      duplicate .m basenames on the project path
%   unresolved      functions called but not resolvable from the path
%   checkcode       MATLAB Code Analyzer messages
%
% This file lives outside Functions/ on purpose: config_emg() runs
% addpath(genpath(Functions)), and a checking tool should not be on the
% path it is checking.
%
% Run `startup` first so config_emg() and the project functions resolve.

cr_opt = cr_parse_args(varargin);

cr_root  = fileparts(fileparts(mfilename('fullpath')));
cr_files = cr_project_files(cr_root);
cr_src   = cr_read_sources(cr_files);

fprintf('check_repo: %d project .m files under %s\n\n', numel(cr_src), cr_root);

cr_findings = cr_empty_findings();
if cr_wants(cr_opt, 'config_double')
    cr_findings = [cr_findings; cr_check_config_double(cr_root)];
end
if cr_wants(cr_opt, 'config_missing')
    cr_findings = [cr_findings; cr_check_config_missing(cr_src)];
end
if cr_wants(cr_opt, 'config_dead')
    cr_findings = [cr_findings; cr_check_config_dead(cr_src, cr_root)];
end
if cr_wants(cr_opt, 'duplicates')
    cr_findings = [cr_findings; cr_check_duplicates(cr_files)];
end
if cr_wants(cr_opt, 'unresolved')
    cr_findings = [cr_findings; cr_check_unresolved(cr_src)];
end
if cr_wants(cr_opt, 'checkcode')
    cr_findings = [cr_findings; cr_check_checkcode(cr_files, cr_root)];
end

cr_print_report(cr_findings, cr_root, cr_opt);

if nargout == 0
    clear cr_findings
end
end

% ======================================================================
% Checks
% ======================================================================

function F = cr_check_config_double(root)
% Config fields assigned more than once at the top level of config_emg.m.
% Assignments indented inside a loop or if-block are an accumulate pattern,
% not a mistake, so only unindented ones count.
F = cr_empty_findings();
cfg = fullfile(root, 'config', 'config_emg.m');
lines = cr_readlines(cfg);

names = strings(0, 1);
lineNo = [];
for i = 1:numel(lines)
    tok = regexp(lines{i}, '^C\.([A-Za-z0-9_.]+)\s*=', 'tokens', 'once');
    if ~isempty(tok)
        names(end+1, 1) = string(tok{1}); %#ok<AGROW>
        lineNo(end+1, 1) = i;             %#ok<AGROW>
    end
end

[uniqNames, ~, grp] = unique(names);
for k = 1:numel(uniqNames)
    hits = lineNo(grp == k);
    if numel(hits) > 1
        F = cr_add(F, 'config_double', 'warning', cfg, hits(end), ...
            sprintf('C.%s assigned %d times (lines %s); line %d wins', ...
            uniqNames(k), numel(hits), strjoin(string(hits), ', '), hits(end)));
    end
end
end

function F = cr_check_config_missing(src)
% C.<path> references in code that config_emg() does not define.
F = cr_empty_findings();
C = config_emg();

for s = src
    if s.isConfigFile || ~s.usesConfigC
        continue
    end
    [paths, lineNums, dynamic] = cr_config_refs(s);
    for j = 1:numel(paths)
        if dynamic(j)
            continue   % C.a.b.(name) cannot be resolved statically
        end
        [ok, firstBad] = cr_resolve_path(C, paths{j});
        if ~ok
            F = cr_add(F, 'config_missing', 'error', s.path, lineNums(j), ...
                sprintf('C.%s is not defined by config_emg() (no field "%s")', ...
                paths{j}, firstBad));
        end
    end
end
end

function F = cr_check_config_dead(src, root)
% Config fields assigned but whose leaf name appears nowhere in the code.
% Leaf-name matching on purpose: most stages alias a block
% (IO = C.f_final_signals.io) so a dotted search would miss the readers.
F = cr_empty_findings();
cfg = fullfile(root, 'config', 'config_emg.m');
lines = cr_readlines(cfg);

% every identifier that appears anywhere outside config_emg.m
seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for s = src
    if s.isConfigFile
        continue
    end
    ids = unique(regexp(s.code, '[A-Za-z_]\w*', 'match'));
    for k = 1:numel(ids)
        seen(ids{k}) = true;
    end
end

for i = 1:numel(lines)
    tok = regexp(lines{i}, '^C\.([A-Za-z0-9_.]+)\s*=', 'tokens', 'once');
    if isempty(tok)
        continue
    end
    parts = strsplit(tok{1}, '.');
    leaf  = parts{end};
    if ~isKey(seen, leaf)
        F = cr_add(F, 'config_dead', 'info', cfg, i, ...
            sprintf('C.%s: leaf name "%s" appears nowhere in the code', tok{1}, leaf));
    end
end
end

function F = cr_check_duplicates(files)
% Two .m files with the same name: which one wins depends on path order.
F = cr_empty_findings();
[~, base] = cellfun(@fileparts, files, 'UniformOutput', false);
[uniqBase, ~, grp] = unique(base);

for k = 1:numel(uniqBase)
    idx = find(grp == k);
    if numel(idx) < 2
        continue
    end
    hashes = cellfun(@cr_filehash, files(idx), 'UniformOutput', false);
    identical = isscalar(unique(hashes));
    if identical
        sev = 'info';
        what = 'identical copies';
    else
        sev = 'error';
        what = 'DIFFERENT contents';
    end
    F = cr_add(F, 'duplicates', sev, files{idx(1)}, 0, ...
        sprintf('%s.m exists %d times (%s): %s', uniqBase{k}, numel(idx), what, ...
        strjoin(cellfun(@(p) cr_relpath(p), files(idx), 'UniformOutput', false), ' | ')));
end
end

function F = cr_check_unresolved(src)
% Identifiers called like functions that resolve to nothing on the path.
% A name assigned somewhere in its own file is treated as a variable, and a
% local function is visible only inside its own file, so both are excluded.
F = cr_empty_findings();
kw = iskeyword();
known = containers.Map('KeyType', 'char', 'ValueType', 'logical');

% Methods are called function-style all over this codebase (isKey(map,k),
% outerjoin(t1,t2), parse(p,...)) but exist() does not see them.
methodNames = cr_method_names();

for s = src
    called = cr_called_names(s.code);
    skip = [kw(:); s.locals(:); s.assigned(:); methodNames(:)];
    todo = setdiff(called, skip);
    for j = 1:numel(todo)
        nm = todo{j};
        if ~isKey(known, nm)
            known(nm) = exist(nm) ~= 0; %#ok<EXIST>
        end
        if ~known(nm)
            ln = cr_first_line_with(s, nm);
            F = cr_add(F, 'unresolved', 'error', s.path, ln, ...
                sprintf('"%s" is called here but resolves to nothing on the path', nm));
        end
    end
end
end

function F = cr_check_checkcode(files, root)
% Code Analyzer messages. Syntax-level ids gate; the rest are a trend count.
%
% checkcode splits a path argument on whitespace, and this repository lives
% under a path that contains spaces. Working from the repository root and
% passing paths relative to it avoids the problem, since no folder inside
% the repository has a space in its name.
F = cr_empty_findings();
serious = {'SYNER', 'FNDEF', 'MDOTM', 'NOPRT', 'BADFN'};

oldDir = cd(root);
restore = onCleanup(@() cd(oldDir));

for i = 1:numel(files)
    rel = cr_relpath_root(files{i}, root);
    try
        msgs = checkcode(rel, '-id', '-struct');
    catch err
        % e.g. an uppercase .M extension, which MATLAB will not analyze
        F = cr_add(F, 'checkcode', 'error', files{i}, 0, ...
            sprintf('Code Analyzer cannot read this file: %s', err.message));
        continue
    end
    for k = 1:numel(msgs)
        if ismember(msgs(k).id, serious)
            F = cr_add(F, 'checkcode', 'error', files{i}, msgs(k).line, ...
                sprintf('[%s] %s', msgs(k).id, msgs(k).message));
        end
    end
    if ~isempty(msgs)
        F = cr_add(F, 'checkcode', 'count', files{i}, 0, ...
            sprintf('%d Code Analyzer message(s)', numel(msgs)));
    end
end
end

% ======================================================================
% Source handling
% ======================================================================

function files = cr_project_files(root)
% Every project .m file: root, config/, scripts/, Functions/ minus toolboxes.
files = {};
for folder = {root, fullfile(root, 'config'), fullfile(root, 'scripts')}
    d = dir(fullfile(folder{1}, '*.m'));
    files = [files, fullfile({d.folder}, {d.name})]; %#ok<AGROW>
end

d = dir(fullfile(root, 'Functions', '**', '*.m'));
if ~isempty(d)
    toolboxes = fullfile(root, 'Functions', 'toolboxes');
    keep = ~startsWith({d.folder}, toolboxes);
    d = d(keep);
    files = [files, fullfile({d.folder}, {d.name})];
end
files = unique(files);
end

function src = cr_read_sources(files)
src = struct('path', {}, 'raw', {}, 'code', {}, 'lines', {}, ...
    'locals', {}, 'assigned', {}, 'isConfigFile', {}, 'usesConfigC', {});
for i = 1:numel(files)
    raw  = fileread(files{i});
    [code, joined] = cr_strip_comments_and_strings(raw);
    [~, base] = fileparts(files{i});

    s.path         = files{i};
    s.raw          = raw;
    s.code         = code;
    s.lines        = cr_splitlines_keep(code);
    s.locals       = cr_local_functions(joined);
    s.assigned     = cr_assigned_names(joined);
    s.isConfigFile = strcmp(base, 'config_emg');
    s.usesConfigC  = cr_uses_config_c(code);
    src(end+1) = s; %#ok<AGROW>
end
end

function tf = cr_uses_config_c(code)
% True unless the file assigns C to something that is not config_emg().
% Some plotting helpers use C as a data variable; their C.<name> references
% are not config reads.
tf = true;
assigns = regexp(code, '(?<![.\w])C\s*=\s*([^;\n]*)', 'tokens');
for k = 1:numel(assigns)
    rhs = assigns{k}{1};
    if ~contains(rhs, 'config_emg')
        tf = false;
        return
    end
end
end

function [paths, lineNums, dynamic] = cr_config_refs(s)
% Every C.<path> in the file, with its line number and whether the next
% access is dynamic (C.a.b.(name)).
paths = {}; lineNums = []; dynamic = logical([]);
for i = 1:numel(s.lines)
    ln = s.lines{i};
    [tok, ends] = regexp(ln, '(?<![.\w])C\.([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*)', ...
        'tokens', 'end');
    for k = 1:numel(tok)
        tail = strtrim(extractAfter(ln, ends(k)));
        paths{end+1, 1}   = tok{k}{1};                     %#ok<AGROW>
        lineNums(end+1,1) = i;                             %#ok<AGROW>
        dynamic(end+1,1)  = startsWith(tail, '.(');        %#ok<AGROW>
    end
end
end

function [ok, firstBad] = cr_resolve_path(C, dotted)
parts = strsplit(dotted, '.');
node = C;
ok = true; firstBad = '';
for i = 1:numel(parts)
    if ~isstruct(node) || ~isfield(node, parts{i})
        ok = false; firstBad = parts{i};
        return
    end
    node = node.(parts{i});
    if numel(node) ~= 1
        return   % struct array: stop walking, treat as resolved
    end
end
end

function names = cr_local_functions(code)
names = {};
tok = regexp(code, '^\s*function\s+([^\n]*)', 'tokens', 'lineanchors');
for k = 1:numel(tok)
    sig = tok{k}{1};
    eqPos = strfind(sig, '=');
    parenPos = strfind(sig, '(');
    if ~isempty(eqPos) && (isempty(parenPos) || eqPos(1) < parenPos(1))
        sig = extractAfter(sig, eqPos(1));
    end
    nm = regexp(strtrim(sig), '^([A-Za-z]\w*)', 'tokens', 'once');
    if ~isempty(nm)
        names{end+1, 1} = nm{1}; %#ok<AGROW>
    end
end
names = unique(names);
end

function names = cr_assigned_names(code)
% Variables bound in this file: plain assignment, multi-output, for-loop
% variable, function inputs, and anonymous-function arguments.
names = {};
t = regexp(code, '(?<![.\w])([A-Za-z]\w*)\s*(?:\([^)\n]*\))?\s*=(?!=)', 'tokens');
names = [names; cr_flat(t)];

t = regexp(code, '\[([^\]\n]*)\]\s*=(?!=)', 'tokens');
for k = 1:numel(t)
    parts = regexp(t{k}{1}, '[A-Za-z]\w*', 'match');
    names = [names; parts(:)]; %#ok<AGROW>
end

t = regexp(code, '(?<![.\w])for\s+\(?\s*([A-Za-z]\w*)', 'tokens');
names = [names; cr_flat(t)];

t = regexp(code, '^\s*function\s+[^\n(]*\(([^)]*)\)', 'tokens', 'lineanchors');
for k = 1:numel(t)
    parts = regexp(t{k}{1}, '[A-Za-z]\w*', 'match');
    names = [names; parts(:)]; %#ok<AGROW>
end

t = regexp(code, '@\s*\(([^)]*)\)', 'tokens');
for k = 1:numel(t)
    parts = regexp(t{k}{1}, '[A-Za-z]\w*', 'match');
    names = [names; parts(:)]; %#ok<AGROW>
end

names = unique(names);
end

function names = cr_method_names()
% Method names of the classes this project calls function-style.
persistent cached
if ~isempty(cached)
    names = cached;
    return
end
names = {};
classes = {'containers.Map', 'table', 'categorical', 'inputParser', ...
    'string', 'datetime', 'duration', 'LinearMixedModel', ...
    'GeneralizedLinearMixedModel', 'matlab.io.datastore.FileSet'};
for k = 1:numel(classes)
    try
        names = [names; cellstr(methods(classes{k}))]; %#ok<AGROW>
    catch
        % class not available in this MATLAB: skip it
    end
end
names = unique(names);
cached = names;
end

function names = cr_called_names(code)
% Identifiers followed by "(" that are not preceded by a dot.
t = regexp(code, '(?<![.\w])([A-Za-z]\w*)\s*\(', 'tokens');
names = unique(cr_flat(t));
end

function out = cr_flat(tokens)
out = cell(numel(tokens), 1);
for k = 1:numel(tokens)
    out{k} = tokens{k}{1};
end
end

function ln = cr_first_line_with(s, name)
ln = 0;
for i = 1:numel(s.lines)
    if ~isempty(regexp(s.lines{i}, ['(?<![.\w])' name '\s*\('], 'once'))
        ln = i;
        return
    end
end
end

function [code, joined] = cr_strip_comments_and_strings(raw)
% Blank out comments and string contents. CODE keeps every character
% position and line break, so line numbers stay correct. JOINED additionally
% merges "..." continuation lines, so multi-line function signatures and
% assignments parse as one statement; its line numbers are meaningless.
lines = cr_splitlines_keep(raw);
cont = false(numel(lines), 1);
inBlock = false;
for i = 1:numel(lines)
    t = strtrim(lines{i});
    if ~inBlock && (strcmp(t, '%{') || strcmp(t, '%%{'))
        inBlock = true;
        lines{i} = blanks(numel(lines{i}));
        continue
    elseif inBlock
        if strcmp(t, '%}')
            inBlock = false;
        end
        lines{i} = blanks(numel(lines{i}));
        continue
    end
    [lines{i}, cont(i)] = cr_strip_line(lines{i});
end
code = strjoin(lines, newline);

jl = lines;
for i = numel(jl)-1:-1:1
    if cont(i)
        jl{i} = [jl{i} ' ' jl{i+1}];
        jl{i+1} = '';
    end
end
joined = strjoin(jl, newline);
end

function [out, continued] = cr_strip_line(line)
out = line;
continued = false;
n = numel(line);
i = 1;
prev = '';
while i <= n
    c = line(i);
    if c == '%'
        out(i:n) = blanks(n - i + 1);
        return
    elseif strncmp(line(i:min(n, i+2)), '...', 3)
        out(i:n) = blanks(n - i + 1);
        continued = true;
        return
    elseif c == ''''
        isTranspose = ~isempty(prev) && ...
            (isletter(prev) || any(prev == '0123456789_)]}.'''));
        if isTranspose
            prev = c; i = i + 1; continue
        end
        j = i + 1;
        while j <= n
            if line(j) == ''''
                if j < n && line(j+1) == ''''
                    j = j + 2; continue
                end
                break
            end
            j = j + 1;
        end
        j = min(j, n);
        out(i:j) = blanks(j - i + 1);
        prev = ''''; i = j + 1; continue
    elseif c == '"'
        j = i + 1;
        while j <= n && line(j) ~= '"'
            j = j + 1;
        end
        j = min(j, n);
        out(i:j) = blanks(j - i + 1);
        prev = '"'; i = j + 1; continue
    end
    if ~isspace(c)
        prev = c;
    end
    i = i + 1;
end
end

function lines = cr_splitlines_keep(txt)
lines = regexp(txt, '\r\n|\n|\r', 'split');
lines = lines(:);
end

function lines = cr_readlines(file)
lines = cr_splitlines_keep(fileread(file));
end

function h = cr_filehash(file)
d = dir(file);
fid = fopen(file, 'r');
bytes = fread(fid, Inf, '*uint8');
fclose(fid);
h = sprintf('%d-%s', d.bytes, mat2str(sum(double(bytes))));
end

% ======================================================================
% Reporting
% ======================================================================

function F = cr_empty_findings()
F = struct('check', {}, 'severity', {}, 'file', {}, 'line', {}, 'message', {});
end

function F = cr_add(F, check, severity, file, line, message)
F(end+1, 1) = struct('check', check, 'severity', severity, ...
    'file', file, 'line', line, 'message', message);
end

function cr_print_report(F, root, opt)
txt = cr_format_report(F, root);
fprintf('%s', txt);
if ~isempty(opt.Save)
    fid = fopen(opt.Save, 'w');
    fprintf(fid, '%s', txt);
    fclose(fid);
    fprintf('\nreport written to %s\n', opt.Save);
end
end

function txt = cr_format_report(F, root)
buf = strings(0, 1);
order = {'config_missing', 'unresolved', 'duplicates', 'config_double', ...
    'checkcode', 'config_dead'};

for k = 1:numel(order)
    name = order{k};
    sel = F(strcmp({F.check}, name));
    if isempty(sel)
        continue
    end
    counts = sel(~strcmp({sel.severity}, 'count'));
    buf(end+1) = sprintf('===== %s (%d) =====', name, numel(counts)); %#ok<AGROW>
    for i = 1:numel(sel)
        s = sel(i);
        if strcmp(s.severity, 'count')
            continue
        end
        loc = cr_relpath_root(s.file, root);
        if s.line > 0
            loc = sprintf('%s:%d', loc, s.line);
        end
        buf(end+1) = sprintf('  [%-7s] %s\n             %s', ...
            s.severity, loc, s.message); %#ok<AGROW>
    end
    buf(end+1) = ""; %#ok<AGROW>
end

nErr = sum(strcmp({F.severity}, 'error'));
nWarn = sum(strcmp({F.severity}, 'warning'));
nInfo = sum(strcmp({F.severity}, 'info'));
ccCount = F(strcmp({F.check}, 'checkcode') & strcmp({F.severity}, 'count'));
nCc = 0;
for i = 1:numel(ccCount)
    v = regexp(ccCount(i).message, '^(\d+)', 'tokens', 'once');
    nCc = nCc + str2double(v{1});
end

buf(end+1) = sprintf('===== summary =====');
buf(end+1) = sprintf('  errors   : %d', nErr);
buf(end+1) = sprintf('  warnings : %d', nWarn);
buf(end+1) = sprintf('  info     : %d', nInfo);
buf(end+1) = sprintf('  Code Analyzer messages across project files: %d', nCc);
buf(end+1) = "";

txt = strjoin(buf, newline);
end

function p = cr_relpath_root(p, root)
if startsWith(p, root)
    p = extractAfter(p, numel(root) + 1);
end
end

function p = cr_relpath(p)
parts = strsplit(p, filesep);
if numel(parts) >= 2
    p = strjoin(parts(max(1, end-1):end), '/');
end
end

% ======================================================================
% Arguments
% ======================================================================

function opt = cr_parse_args(args)
opt.Checks = {};
opt.Save = '';
for i = 1:2:numel(args)
    switch lower(args{i})
        case 'checks'
            opt.Checks = cellstr(args{i+1});
        case 'save'
            opt.Save = args{i+1};
        otherwise
            error('check_repo:badArg', 'Unknown option "%s"', args{i});
    end
end
end

function tf = cr_wants(opt, name)
tf = isempty(opt.Checks) || ismember(name, opt.Checks);
end
