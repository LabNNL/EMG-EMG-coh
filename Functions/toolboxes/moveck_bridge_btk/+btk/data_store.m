classdef data_store < SwigRef
  methods
    function this = swig_this(self)
      this = btkMEX(3, self);
    end
    function self = data_store(varargin)
      if nargin==1 && strcmp(class(varargin{1}),'SwigRef')
        if ~isnull(varargin{1})
          self.swigPtr = varargin{1}.swigPtr;
        end
      else
        tmp = btkMEX(5, varargin{:});
        self.swigPtr = tmp.swigPtr;
        tmp.SwigClear();
      end
    end
    function delete(self)
      if self.swigPtr
        btkMEX(6, self);
        self.SwigClear();
      end
    end
  end
  methods(Static)
  end
end
