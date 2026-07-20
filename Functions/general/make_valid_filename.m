function out = make_valid_filename(x)
    out = matlab.lang.makeValidName(char(string(x)));
end
