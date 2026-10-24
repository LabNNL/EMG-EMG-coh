% Dead diagnostic code lifted out of k_plot_activation_profiles.m.
%
% diagnose_random_activation_examples was only ever reached from a
% commented-out call, and it is the sole caller of
% diagnose_activation_profile_start, which in turn calls
% get_toe_fraction_from_valid_cycles -- a function that is not defined
% anywhere in the project, so this chain could never have run.
%
% get_cell_field_or_empty, get_max_len and legend_if_needed came along
% because nothing else used them.
%
% Not on the MATLAB path. To revive any of this you also need to write
% get_toe_fraction_from_valid_cycles(VC, idx, defaultFraction).

function diagnose_random_activation_examples(TD, muscleName, nExamples, cycleIdxList, varargin)
    p = inputParser;
    addParameter(p, 'seed', 1);
    parse(p, varargin{:});
    seed = p.Results.seed;

    rng(seed);

    subjFields = fieldnames(TD);
    candidates = {};

    for iS = 1:numel(subjFields)
        subjID = subjFields{iS};
        condFields = fieldnames(TD.(subjID));

        for ic = 1:numel(condFields)
            cond = condFields{ic};
            legFields = fieldnames(TD.(subjID).(cond));

            for il = 1:numel(legFields)
                leg = legFields{il};

                if ~isfield(TD.(subjID).(cond).(leg), char(muscleName))
                    continue;
                end

                S = TD.(subjID).(cond).(leg).(char(muscleName));
                if ~isfield(S, 'valid_cycles') || isempty(S.valid_cycles) || isempty(S.valid_cycles.cycle_number)
                    continue;
                end

                candidates(end+1,:) = {subjID, cond, leg}; %#ok<AGROW>
            end
        end
    end

    if isempty(candidates)
        error('No candidates found for muscle %s.', muscleName);
    end

    nExamples = min(nExamples, size(candidates,1));
    idxPick = randperm(size(candidates,1), nExamples);

    for i = 1:nExamples
        subjID = candidates{idxPick(i), 1};
        cond   = candidates{idxPick(i), 2};
        leg    = candidates{idxPick(i), 3};

        fprintf('\nRandom example %d/%d: %s | %s | %s | %s\n', i, nExamples, subjID, cond, leg, muscleName);

        diagnose_activation_profile_start( TD, subjID, cond, leg, char(muscleName), cycleIdxList);
    end
end

function diagnose_activation_profile_start(TD, subjID, cond, leg, mf, cycleIdxList, varargin)

    p = inputParser;
    addParameter(p, 'zoom_fraction', 0.15);
    parse(p, varargin{:});
    zoom_fraction = p.Results.zoom_fraction;

    assert(isfield(TD, subjID), 'Subject not found.');
    assert(isfield(TD.(subjID), cond), 'Condition not found.');
    assert(isfield(TD.(subjID).(cond), leg), 'Leg not found.');
    assert(isfield(TD.(subjID).(cond).(leg), mf), 'Muscle not found.');

    S = TD.(subjID).(cond).(leg).(mf);
    assert(isfield(S,'valid_cycles') && ~isempty(S.valid_cycles), 'No valid cycles found.');

    VC = S.valid_cycles;
    nAvail = numel(VC.cycle_number);

    nReq = numel(cycleIdxList);
    nRows = nReq;
    nCols = 4;

    fig = figure('Color','w','Position',[100 100 1500 max(350,260*nRows)]);
    tl = tiledlayout(nRows, nCols, 'TileSpacing','compact', 'Padding','compact');
    title(tl, sprintf('Diagnostic | %s | %s | %s | %s', subjID, cond, leg, mf), 'Interpreter','none');

    for i = 1:nReq
        idx = cycleIdxList(i);
        if idx < 1 || idx > nAvail
            warning('Cycle index %d out of range. Skipping.', idx);
            continue;
        end

        x_bp   = get_cell_field_or_empty(VC, 'bandpassed', idx);
        x_rect = get_cell_field_or_empty(VC, 'rectified', idx);
        x_env  = get_cell_field_or_empty(VC, 'envelope', idx);

        x_tn_bp  = get_cell_field_or_empty(VC, 'time_normalized_bandpassed', idx);
        x_tn_env = get_cell_field_or_empty(VC, 'time_normalized_envelope', idx);

        toeFrac = get_toe_fraction_from_valid_cycles(VC, idx, 0.60);

        ax = nexttile; hold(ax,'on');
        if ~isempty(x_bp), plot(ax, x_bp, 'b', 'LineWidth', 1); end
        title(ax, sprintf('Cycle %d | bandpassed', idx));
        grid(ax,'on');

        ax = nexttile; hold(ax,'on');
        if ~isempty(x_rect), plot(ax, x_rect, 'Color', [0.6 0.6 0.6], 'LineWidth', 1); end
        if ~isempty(x_env),  plot(ax, x_env,  'r', 'LineWidth', 2); end
        title(ax, 'rectified + envelope');
        legend_if_needed(ax, {'rectified','envelope'}, [~isempty(x_rect), ~isempty(x_env)]);
        grid(ax,'on');

        ax = nexttile; hold(ax,'on');
        if ~isempty(x_tn_bp),  plot(ax, linspace(0,100,numel(x_tn_bp)),  x_tn_bp,  'b', 'LineWidth', 1); end
        if ~isempty(x_tn_env), plot(ax, linspace(0,100,numel(x_tn_env)), x_tn_env, 'r', 'LineWidth', 2); end
        xline(ax, 100*toeFrac, '--', 'Color', [0.4 0.4 0.4], 'HandleVisibility','off');
        title(ax, 'time-normalized');
        xlabel(ax, 'Cycle (%)');
        legend_if_needed(ax, {'tn bandpassed','tn envelope'}, [~isempty(x_tn_bp), ~isempty(x_tn_env)]);
        grid(ax,'on');

        ax = nexttile; hold(ax,'on');
        nZoom = max(5, round(zoom_fraction * get_max_len(x_bp, x_rect, x_env)));

        if ~isempty(x_bp)
            n1 = min(numel(x_bp), nZoom);
            plot(ax, 1:n1, x_bp(1:n1), 'b', 'LineWidth', 1);
        end
        if ~isempty(x_rect)
            n1 = min(numel(x_rect), nZoom);
            plot(ax, 1:n1, x_rect(1:n1), 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
        end
        if ~isempty(x_env)
            n1 = min(numel(x_env), nZoom);
            plot(ax, 1:n1, x_env(1:n1), 'r', 'LineWidth', 2);
        end

        title(ax, sprintf('start zoom (first %.0f%%)', 100*zoom_fraction));
        legend_if_needed(ax, {'bp','rect','env'}, [~isempty(x_bp), ~isempty(x_rect), ~isempty(x_env)]);
        grid(ax,'on');
    end
end

function x = get_cell_field_or_empty(S, fn, idx)
    if isfield(S, fn) && numel(S.(fn)) >= idx && ~isempty(S.(fn){idx})
        x = S.(fn){idx}(:);
    else
        x = [];
    end
end

function n = get_max_len(varargin)
    lens = zeros(numel(varargin),1);
    for i = 1:numel(varargin)
        if ~isempty(varargin{i})
            lens(i) = numel(varargin{i});
        end
    end
    n = max(lens);
    if n == 0, n = 10; end
end

function legend_if_needed(ax, labels, keepMask)
    labels = labels(keepMask);
    if ~isempty(labels)
        legend(ax, labels, 'Location','best');
    end
end
