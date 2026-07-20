function activeRules = get_active_cycle_policy_rules(cycle_policy)

    activeRules = strings(0,1);

    if isfield(cycle_policy, 'require_at_least_one_burst') && cycle_policy.require_at_least_one_burst
        activeRules(end+1) = "require_at_least_one_burst";
    end

    if isfield(cycle_policy, 'require_at_least_one_good_burst') && cycle_policy.require_at_least_one_good_burst
        activeRules(end+1) = "require_at_least_one_good_burst";
    end

    if isfield(cycle_policy, 'reject_if_any_bad_burst') && cycle_policy.reject_if_any_bad_burst
        activeRules(end+1) = "reject_if_any_bad_burst";
    end

    if isfield(cycle_policy, 'reject_if_bad_burst_fraction_over') && cycle_policy.reject_if_bad_burst_fraction_over
        activeRules(end+1) = sprintf("reject_if_bad_burst_fraction_over(>%.3f)", ...
            cycle_policy.parameters.max_bad_burst_fraction);
    end

    if isfield(cycle_policy, 'reject_if_in_phase_of_interest') && cycle_policy.reject_if_in_phase_of_interest
        activeRules(end+1) = "reject_if_in_phase_of_interest";
    end

    if isfield(cycle_policy, 'reject_if_in_phase_of_interest_padded_for_wavelet_analysis') && ...
            cycle_policy.reject_if_in_phase_of_interest_padded_for_wavelet_analysis
        activeRules(end+1) = "reject_if_in_phase_of_interest_padded_for_wavelet_analysis";
    end

    if isfield(cycle_policy, 'reject_flatline_cycles') && cycle_policy.reject_flatline_cycles
        if isfield(cycle_policy, 'parameters') && isfield(cycle_policy.parameters, 'flatline_method')
            activeRules(end+1) = "reject_flatline_cycles(" + string(cycle_policy.parameters.flatline_method) + ")";
        else
            activeRules(end+1) = "reject_flatline_cycles";
        end
    end

    if isfield(cycle_policy, 'reject_if_flatline_fraction_over') && cycle_policy.reject_if_flatline_fraction_over
        activeRules(end+1) = sprintf("reject_if_flatline_fraction_over(>%.3f)", ...
            cycle_policy.parameters.max_flatline_fraction);
    end

    if isempty(activeRules)
        activeRules = "none";
    end
end
