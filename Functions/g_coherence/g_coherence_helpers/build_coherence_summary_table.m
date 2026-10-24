function T = build_coherence_summary_table(COHERENCE_RESULTS, C, summaryScalarVars, W, metricSourcesToSave)

    if nargin < 5 || isempty(metricSourcesToSave)
        metricSourcesToSave = "sig";
    end

    sources = lower(string(metricSourcesToSave));

    T = table();

    for isrc = 1:numel(sources)
        metricSource = sources(isrc);

        G = build_group_plot_struct(COHERENCE_RESULTS, C, W, metricSource);

        if isempty(G)
            continue;
        end

        SUMMARY_ROWS = cell(numel(G), 6 + numel(summaryScalarVars));

        for iRow = 1:numel(G)

            rowVals = cell(1, 6 + numel(summaryScalarVars));

            rowVals(1:6) = { ...
                G(iRow).subject, ...
                G(iRow).age_group, ...
                G(iRow).condition, ...
                G(iRow).leg, ...
                G(iRow).pair_name, ...
                metricSource};

            for iv = 1:numel(summaryScalarVars)
                vname = summaryScalarVars{iv};

                if isfield(G(iRow), vname)
                    rowVals{6+iv} = G(iRow).(vname);
                else
                    rowVals{6+iv} = NaN;
                end
            end

            SUMMARY_ROWS(iRow,:) = rowVals;
        end

        Tsrc = cell2table(SUMMARY_ROWS, 'VariableNames', ...
            [{'subject','age_group','condition','leg','pair_name','metric_source'}, summaryScalarVars]);

        T = [T; Tsrc]; %#ok<AGROW>
    end
end

