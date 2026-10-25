function moved = archive_stale_h_outputs(dirs, runStart, resultsRoot, archiveRoot)
% Moves files that this run of stage h did not rewrite (last modified before
% runStart) out of Results/ into
%   <archiveRoot>/<path under resultsRoot>/_stale_<yyyymmdd_HHMMSS>/
% (attic/ResultsArchive by default, git-ignored), keeping their relative
% paths, and writes a manifest there. Nothing is deleted, and Results/ only
% holds what the last run wrote.
%
% Without this, tables and figures from older settings (e.g. another
% coherence source or the categorical model) sit next to the current ones
% and look current.

    moved = table('Size', [0 3], 'VariableTypes', {'string','string','datetime'}, ...
        'VariableNames', {'from','to','last_modified'});
    stamp = string(datetime(runStart, 'Format', 'yyyyMMdd_HHmmss'));
    resultsRoot = string(resultsRoot);

    for d = string(dirs(:))'
        if ~isfolder(d), continue; end
        F = dir(fullfile(d, '**', '*'));
        F = F(~[F.isdir]);
        staleDir = fullfile(archiveRoot, extractAfter(d, strlength(resultsRoot) + 1), "_stale_" + stamp);
        for k = 1:numel(F)
            src = string(fullfile(F(k).folder, F(k).name));
            rel = extractAfter(src, strlength(d) + 1);
            if startsWith(F(k).name, '.') || contains(rel, "_stale_") || contains(rel, "_archive")
                continue;
            end
            t = datetime(F(k).datenum, 'ConvertFrom', 'datenum');
            if t >= runStart, continue; end
            dst = fullfile(staleDir, rel);
            if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
            movefile(src, dst);
            moved(end+1, :) = {src, string(dst), t}; %#ok<AGROW>
        end
        if any(startsWith(moved.to, staleDir))
            writetable(moved(startsWith(moved.to, staleDir), :), fullfile(staleDir, 'MANIFEST.csv'));
            fprintf('Moved %d stale file(s) from %s to %s\n', sum(startsWith(moved.to, staleDir)), d, staleDir);
        end
    end
end
