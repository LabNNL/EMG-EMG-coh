function T = build_mixed_spm_result_table(spmMixedInfo, pairName)
%BUILD_MIXED_SPM_RESULT_TABLE  Mixed age x condition spectrum SPM as a table.
%
%   T = build_mixed_spm_result_table(spmMixedInfo, pairName)
%
% One row per significant cluster, or a single row per effect when an effect
% has no clusters, so that "tested and found nothing" is distinguishable from
% "not tested". Columns:
%   pair, effect, ok, n_subjects, n_rows, n_clusters, cluster, p
%
% This mirrors what print_mixed_spm_result_summary writes to the console. That
% summary was console-only, and the project has no diary, so the result of the
% one spectrum test that does work was not recorded anywhere.

effectNames  = {'AGE main effect', 'CONDITION main effect', 'AGE x CONDITION interaction'};
effectFields = {'spmi_age', 'spmi_condition', 'spmi_interaction'};

pair = string(pairName);
rows = cell(0, 1);

if isempty(spmMixedInfo) || ~isfield(spmMixedInfo, 'ok') || ~spmMixedInfo.ok
    T = one_row(pair, "(all)", false, NaN, NaN, NaN, NaN, NaN);
    return
end

nSubj = get_num(spmMixedInfo, 'n_subjects');
nRows = get_num(spmMixedInfo, 'n_rows');

for i = 1:numel(effectFields)
    f = effectFields{i};
    name = string(effectNames{i});

    if ~isfield(spmMixedInfo, f) || isempty(spmMixedInfo.(f))
        rows{end+1, 1} = one_row(pair, name, false, nSubj, nRows, NaN, NaN, NaN); %#ok<AGROW>
        continue
    end

    try
        clusters = spmMixedInfo.(f).clusters;
    catch
        rows{end+1, 1} = one_row(pair, name, false, nSubj, nRows, NaN, NaN, NaN); %#ok<AGROW>
        continue
    end

    nCl = numel(clusters);
    if nCl == 0
        rows{end+1, 1} = one_row(pair, name, true, nSubj, nRows, 0, NaN, NaN); %#ok<AGROW>
        continue
    end

    for ic = 1:nCl
        c = clusters(ic);
        pval = NaN;
        if isprop(c, 'P')
            pval = c.P;
        elseif isprop(c, 'p')
            pval = c.p;
        end
        rows{end+1, 1} = one_row(pair, name, true, nSubj, nRows, nCl, ic, pval); %#ok<AGROW>
    end
end

T = vertcat(rows{:});
end

function T = one_row(pair, effect, ok, nSubj, nRows, nCl, cluster, pval)
T = table(pair, effect, logical(ok), nSubj, nRows, nCl, cluster, pval, ...
    'VariableNames', {'pair', 'effect', 'ok', 'n_subjects', 'n_rows', ...
                      'n_clusters', 'cluster', 'p'});
end

function v = get_num(S, f)
if isfield(S, f) && ~isempty(S.(f))
    v = double(S.(f));
else
    v = NaN;
end
end
