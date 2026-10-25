function h_cycle_triplets(COH_DEFAULT, C, HC)
% H_CYCLE_TRIPLETS  Band coherence over the gait cycle, by age group and condition.
% Runs when HC.analysis.make_cycle_triplets.

    %% ===================== CYCLE-PERCENTAGE TRIPLETS =====================

    if HC.analysis.make_cycle_triplets

        fprintf('\nGenerating cycle-percentage coherence triplets...\n');

        cycleTripletDir = fullfile(HC.io.plots_dir, 'cycle_triplets');
        if ~exist(cycleTripletDir, 'dir')
            mkdir(cycleTripletDir);
        end

        T_cycle_row = build_cycle_triplet_table_from_results( COH_DEFAULT, C, HC);

        if isempty(T_cycle_row)
            warning('No cycle-triplet rows could be built. Skipping cycle triplets.');
        else
            writetable(flatten_cycle_triplet_table(T_cycle_row), fullfile(cycleTripletDir, 'T_cycle_row_flat.csv'));

            if HC.analysis.cycle_triplet_average_legs
                T_cycle_subj = average_cycle_triplet_legs(T_cycle_row);
            else
                T_cycle_subj = T_cycle_row;
            end

            writetable(flatten_cycle_triplet_table(T_cycle_subj), fullfile(cycleTripletDir, 'T_cycle_subject_flat.csv'));

            pairList = categories(removecats(T_cycle_subj.pair_name));

            for ip = 1:numel(pairList)
                pairName = pairList{ip};
                Tp = T_cycle_subj(T_cycle_subj.pair_name == pairName, :);

                if isempty(Tp)
                    continue;
                end

                % ---------- by age ----------
                fig1 = figure('Visible', HC.plot.cycle_triplets.visible, 'Color', 'w', 'Position', [100 100 1650 520]);

                make_cycle_triplet_figure( fig1, Tp, pairName, 'age_group', cellstr(C.plotting.age_order), @(x)get_age_color(x,C), C, HC, 'Age group');

                saveas(fig1, fullfile(cycleTripletDir, sprintf('CYCLE_TRIPLET__%s__BY_AGE__%s.png', char(string(pairName)), HC.analysis.cycle_triplet_source)));
                close(fig1);

                % ---------- by condition ----------
                fig2 = figure('Visible', HC.plot.cycle_triplets.visible, 'Color', 'w', 'Position', [100 100 1650 520]);

                make_cycle_triplet_figure( fig2, Tp, pairName, 'condition', cellstr(C.plotting.condition_order), @(x)get_condition_color(x,C), C, HC, 'Condition');

                saveas(fig2, fullfile(cycleTripletDir, sprintf('CYCLE_TRIPLET__%s__BY_CONDITION__%s.png', char(string(pairName)), HC.analysis.cycle_triplet_source)));
                close(fig2);
            end
        end
    end
end
