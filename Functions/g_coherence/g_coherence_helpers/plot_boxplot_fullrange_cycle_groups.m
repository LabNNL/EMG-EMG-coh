function plot_boxplot_fullrange_cycle_groups(COHERENCE_RESULTS, outDir)

    vals_real_outer = [];
    vals_analysis_outer = [];
    vals_analysis_middle = [];

    subjFields = fieldnames(COHERENCE_RESULTS);

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};
        condFields = fieldnames(COHERENCE_RESULTS.(subjID));
        for ic = 1:numel(condFields)
            cond = condFields{ic};
            legFields = fieldnames(COHERENCE_RESULTS.(subjID).(cond));
            for il = 1:numel(legFields)
                leg = legFields{il};
                pairFields = fieldnames(COHERENCE_RESULTS.(subjID).(cond).(leg));
                for ip = 1:numel(pairFields)
                    pairName = pairFields{ip};

                    R = COHERENCE_RESULTS.(subjID).(cond).(leg).(pairName);
                    if isempty(R) || ~isfield(R, 'CycleBandCoherence'), continue; end
                    C = R.CycleBandCoherence;
                    if ~isfield(C, 'FullRange') || all(isnan(C.FullRange)), continue; end

                    x = C.FullRange(:);

                    vals_real_outer      = [vals_real_outer;      x(logical(C.mask_real_outer(:)))]; %#ok<AGROW>
                    vals_analysis_outer  = [vals_analysis_outer;  x(logical(C.mask_analysis_outer(:)))]; %#ok<AGROW>
                    vals_analysis_middle = [vals_analysis_middle; x(logical(C.mask_analysis_middle(:)))]; %#ok<AGROW>
                end
            end
        end
    end

    y = [vals_real_outer; vals_analysis_outer; vals_analysis_middle];
    g = [repmat({'Orig outer'}, numel(vals_real_outer),1); ...
         repmat({'Retained outer'}, numel(vals_analysis_outer),1); ...
         repmat({'Retained middle'}, numel(vals_analysis_middle),1)];

    fig = figure('Visible','off','Color','w','Position',[100 100 700 500]);
    boxchart(categorical(g), y);
    ylabel('Full-range cycle coherence');
    title('Full-range cycle coherence by cycle group');
    grid on; box on;

    saveas(fig, fullfile(outDir, 'BOXPLOT_FULLRANGE_CYCLE_GROUPS.png'));
    close(fig);
end