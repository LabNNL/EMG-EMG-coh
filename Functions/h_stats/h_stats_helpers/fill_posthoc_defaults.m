function cfg = fill_posthoc_defaults(cfg)

    if ~isfield(cfg, 'mode') || isempty(cfg.mode)
        cfg.mode = 'adaptive';
    end
    if ~isfield(cfg, 'min_n_parametric') || isempty(cfg.min_n_parametric)
        cfg.min_n_parametric = 8;
    end
    if ~isfield(cfg, 'outlier_z_thresh') || isempty(cfg.outlier_z_thresh)
        cfg.outlier_z_thresh = 3.5;
    end
    if ~isfield(cfg, 'use_normality_test') || isempty(cfg.use_normality_test)
        cfg.use_normality_test = false;
    end
    if ~isfield(cfg, 'normality_alpha') || isempty(cfg.normality_alpha)
        cfg.normality_alpha = 0.05;
    end
end