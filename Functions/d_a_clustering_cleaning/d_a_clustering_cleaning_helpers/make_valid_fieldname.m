function out = make_valid_fieldname(x)
    out = matlab.lang.makeValidName(char(string(x)));
end
