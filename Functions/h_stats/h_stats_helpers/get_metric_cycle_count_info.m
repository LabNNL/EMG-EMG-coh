function info = get_metric_cycle_count_info(R, coherenceSource)

    info = struct();
    info.n_available = NaN;
    info.n_used_for_metric = NaN;
    info.source = "";

    if isempty(R)
        info.source = "empty_result";
        return;
    end

    if isfield(R, 'n_cycles_used') && ~isempty(R.n_cycles_used)
        info.n_available = double(R.n_cycles_used);

    elseif isfield(R, 'cycle_equalization') && isfield(R.cycle_equalization, 'N_available_before_equalization') && ~isempty(R.cycle_equalization.N_available_before_equalization)

        info.n_available = double(R.cycle_equalization.N_available_before_equalization);
    end

    src = lower(string(coherenceSource));

    switch src

        case {"raw", "sig", "sig_common_threshold", "zcoh_bokil", "surrogate_delta", "cycle_bias_corrected"}

            % These sources are based on the normal coherence estimate computed
            % from all retained analysis cycles.
            %
            % sig_common_threshold changes the threshold, not the coherence estimate.
            % zcoh_bokil normalizes the raw coherence using n/df, but the map is still
            % based on the retained cycles.
            % surrogate_delta should use the same number of cycles as the real/surrogate
            % computation; if stored separately later, this can be refined.
            info.n_used_for_metric = info.n_available;
            info.source = "available_retained_cycles";

        case {"equalized", "sig_equalized"}

            % These sources are computed after selecting an equalized subset of cycles.
            if isfield(R, 'n_cycles_equalized_used') && ~isempty(R.n_cycles_equalized_used) && isfinite(double(R.n_cycles_equalized_used))

                info.n_used_for_metric = double(R.n_cycles_equalized_used);
                info.source = "R.n_cycles_equalized_used";

            elseif isfield(R, 'Metrics') && isfield(R.Metrics, 'info') && isfield(R.Metrics.info, 'N_equalized_used') && ~isempty(R.Metrics.info.N_equalized_used) && isfinite(double(R.Metrics.info.N_equalized_used))

                info.n_used_for_metric = double(R.Metrics.info.N_equalized_used);
                info.source = "R.Metrics.info.N_equalized_used";

            elseif isfield(R, 'cycle_equalization') && isfield(R.cycle_equalization, 'N_used_after_equalization') && ~isempty(R.cycle_equalization.N_used_after_equalization) && isfinite(double(R.cycle_equalization.N_used_after_equalization))

                info.n_used_for_metric = double(R.cycle_equalization.N_used_after_equalization);
                info.source = "R.cycle_equalization.N_used_after_equalization";

            else
                info.n_used_for_metric = info.n_available;
                info.source = "fallback_available_retained_cycles";
            end

        otherwise

            warning('Unknown coherence_source for cycle-count info: %s. Falling back to available cycles.', src);
            info.n_used_for_metric = info.n_available;
            info.source = "fallback_available_retained_cycles";
    end
end