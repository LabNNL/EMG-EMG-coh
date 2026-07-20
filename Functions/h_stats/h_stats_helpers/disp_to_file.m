function disp_to_file(fid, X)
    fprintf(fid, '%s\n', evalc('disp(X)'));
end