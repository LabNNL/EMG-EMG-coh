function disp_tree(x, maxDepth, name)
%DISP_TREE Pretty display of nested MATLAB variables like a tree.
%
% Usage:
%   disp_tree(S)
%   disp_tree(S, 3)
%   disp_tree(S, 3, 'MY_STRUCT')
%
% Inputs:
%   x        : any MATLAB variable (struct, cell, numeric, table, etc.)
%   maxDepth : maximum recursion depth (default = 3)
%   name     : root name to display (default = input variable name if possible)
%
% Examples:
%   data = load('myfile.mat');
%   disp_tree(data)
%
%   S.a.b = rand(10,1);
%   S.a.c = {'hello', 42};
%   disp_tree(S, 4, 'S')
%
% Notes:
% - Works especially well for structs returned by load().
% - Avoid using very large maxDepth on huge nested variables.

    if nargin < 2 || isempty(maxDepth)
        maxDepth = 3;
    end

    if nargin < 3 || isempty(name)
        name = inputname(1);
        if isempty(name)
            name = 'root';
        end
    end

    fprintf('\n=== Variable tree ===\n');
    print_node(x, name, 0, maxDepth);
    fprintf('=====================\n\n');
end


function print_node(x, nodeName, level, maxDepth)
    indent = repmat('  ', 1, level);

    % Print current node summary
    fprintf('%s- %s: %s\n', indent, nodeName, describe_value(x));

    % Stop if depth limit reached
    if level >= maxDepth
        return;
    end

    % Recurse depending on type
    if isstruct(x)
        print_struct_children(x, level, maxDepth);

    elseif iscell(x)
        print_cell_children(x, level, maxDepth);

    elseif istable(x)
        print_table_children(x, level, maxDepth);

    % for objects, optionally inspect public properties
    elseif isobject(x) && isscalar(x)
        print_object_children(x, level, maxDepth);
    end
end


function print_struct_children(S, level, maxDepth)
    indent = repmat('  ', 1, level + 1);

    if isempty(S)
        return;
    end

    fn = fieldnames(S);

    % Struct array
    if numel(S) > 1
        fprintf('%s(struct array with %d elements)\n', indent, numel(S));

        % show only first few elements for readability
        nShow = min(numel(S), 3);
        for k = 1:nShow
            print_node(S(k), sprintf('(%d)', k), level + 1, maxDepth);
        end
        if numel(S) > nShow
            fprintf('%s... (%d more elements)\n', indent, numel(S) - nShow);
        end
        return;
    end

    % Scalar struct
    for i = 1:numel(fn)
        field = fn{i};

        % safer field access
        try
            value = S.(field);
            print_node(value, field, level + 1, maxDepth);
        catch ME
            fprintf('%s- %s: <error accessing field: %s>\n', indent, field, ME.message);
        end
    end
end


function print_cell_children(C, level, maxDepth)
    indent = repmat('  ', 1, level + 1);

    if isempty(C)
        return;
    end

    n = numel(C);
    nShow = min(n, 5);

    for i = 1:nShow
        try
            print_node(C{i}, sprintf('{%d}', i), level + 1, maxDepth);
        catch ME
            fprintf('%s- {%d}: <error accessing cell: %s>\n', indent, i, ME.message);
        end
    end

    if n > nShow
        fprintf('%s... (%d more cells)\n', indent, n - nShow);
    end
end


function print_table_children(T, level, ~)
    indent = repmat('  ', 1, level + 1);

    vars = T.Properties.VariableNames;
    nVars = numel(vars);

    fprintf('%sVariables:\n', indent);
    for i = 1:nVars
        v = T.(vars{i});
        fprintf('%s  - %s: %s\n', indent, vars{i}, describe_value(v));
    end
end


function print_object_children(obj, level, maxDepth)
    indent = repmat('  ', 1, level + 1);

    try
        props = properties(obj);
    catch
        return;
    end

    nShow = min(numel(props), 10);

    for i = 1:nShow
        p = props{i};
        try
            value = obj.(p);
            print_node(value, p, level + 1, maxDepth);
        catch ME
            fprintf('%s- %s: <error accessing property: %s>\n', indent, p, ME.message);
        end
    end

    if numel(props) > nShow
        fprintf('%s... (%d more properties)\n', indent, numel(props) - nShow);
    end
end


function s = describe_value(x)
% Return a compact one-line description of x

    cls = class(x);
    sz  = size(x);
    szStr = size_to_string(sz);

    if isstruct(x)
        if isempty(x)
            s = sprintf('empty struct %s', szStr);
        else
            f = fieldnames(x);
            s = sprintf('struct %s with %d field(s)', szStr, numel(f));
        end

    elseif iscell(x)
        s = sprintf('cell %s', szStr);

    elseif istable(x)
        s = sprintf('table %s', szStr);

    elseif isnumeric(x) || islogical(x)
        if isscalar(x)
            if isnumeric(x)
                s = sprintf('%s scalar = %g', cls, x);
            else
                s = sprintf('%s scalar = %d', cls, x);
            end
        else
            s = sprintf('%s %s', cls, szStr);
        end

    elseif ischar(x)
        s = sprintf('char %s', szStr);

    elseif isstring(x)
        if isscalar(x)
            s = sprintf('string scalar = "%s"', x);
        else
            s = sprintf('string %s', szStr);
        end

    elseif isa(x, 'function_handle')
        s = sprintf('function_handle: %s', func2str(x));

    elseif isobject(x)
        s = sprintf('%s object %s', cls, szStr);

    else
        s = sprintf('%s %s', cls, szStr);
    end
end


function s = size_to_string(sz)
    s = sprintf('%dx', sz);
    s(end) = [];
    s = ['[' s ']'];
end