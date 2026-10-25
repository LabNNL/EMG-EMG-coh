function log_rows = save_concat_qc_plot(log_rows, concat_sig, segs, subjID, cond, leg, mus, PNG_DIR)
%SAVE_CONCAT_QC_PLOT Save QC figure for concatenated EMG signal with cycle boundaries.
%
% Inputs:
%   log_rows - existing log cell array
%   concat_sig - concatenated signal vector
%   segs     - cell array of cycle segments used to build concat_sig
%   subjID   - participant ID
%   cond     - condition
%   leg      - left/right
%   mus      - muscle name
%   PNG_DIR  - output folder for QC figures
%
% Output:
%   log_rows - updated log cell array

    try
        fig = figure('Visible','off','Color','w');
        plot(concat_sig, 'LineWidth', 0.5);
        hold on;

        seg_lengths = cellfun(@numel, segs(:));
        cycle_ends = cumsum(seg_lengths);
        cycle_starts = [1; cycle_ends(1:end-1) + 1];

        for ii = 1:numel(cycle_starts)
            xline(cycle_starts(ii), '--', ...
                'Color', [0.65 0.65 0.65], ...
                'LineWidth', 0.8);
        end

        hold off;

        title(sprintf('EMG Brut Concaténé | %s | %s | %s | %s', subjID, cond, leg, mus), ...
            'Interpreter', 'none');
        xlabel('Samples', 'Interpreter', 'none');
        ylabel('Amplitude', 'Interpreter', 'none');

        save_path = fullfile(PNG_DIR, sprintf('%s_%s_%s_%s.png', subjID, cond, leg, mus));
        saveas(fig, save_path);
        close(fig);

    catch ME
        warning('Erreur figure %s %s %s %s : %s', subjID, cond, leg, mus, ME.message);
        log_rows = append_log(log_rows, ...
            'WARN', 'FIGURE_SAVE_ERROR', subjID, cond, '', leg, mus, ...
            '', '', ME.identifier, ME.message);
    end
end