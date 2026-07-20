function lme = write_lme_report(T, dvName, formula, outTxt)

    fid = fopen(outTxt, 'w');
    if fid == -1
        warning('Could not open model report file:\n%s', outTxt);
        return;
    end

    fprintf(fid, 'Dependent variable: %s\n', dvName);
    fprintf(fid, 'Formula: %s\n\n', formula);
    fprintf(fid, 'N rows: %d\n', height(T));
    fprintf(fid, 'N subjects: %d\n\n', numel(unique(T.subject)));

    try
        lme = fitlme(T, formula);

        fprintf(fid, '===== MODEL SUMMARY =====\n');
        fprintf(fid, '%s\n\n', evalc('disp(lme)'));

        fprintf(fid, '===== FIXED EFFECTS =====\n');
        fprintf(fid, '%s\n\n', evalc('disp(lme.Coefficients)'));

        fprintf(fid, '===== ANOVA =====\n');
        fprintf(fid, '%s\n\n', evalc('disp(anova(lme))'));

    catch ME
        fprintf(fid, 'Model failed.\n');
        fprintf(fid, '%s\n', ME.message);
    end

    fclose(fid);
end