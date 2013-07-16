=begin
force.rb
Copyright Jamie McIntyre 2013

This file is part of Equilib. Equilib is a plugin for doing graphic statics in SketchUp.  
More information: http://www.graphicstatics.net/

Equilib is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Equilib is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Equilib.  If not, see <http://www.gnu.org/licenses/>.
=end


require 'sketchup'


module JM::Equilib

  class Joint
    def initialize(s,p)
      @p = p     
      @forces=[]
    end
    
    attr_reader                 :forces

    def fixed_forces;           @f.reject { |f| f.free?; };  end
    def free_forces;            @f.reject { |f| f.fixed?; };  end

    def unsolved_forces;        @f.reject { |f| f.solved? };  end
    def solved_forces;          @f.reject { |f| f.unsolved? };  end      
    def resultant;              solved_forces.inject(Geom::Vector3d.new(0,0,0)) { |sum,f| sum + f._v };  end
    def underconstrained?
      # move checks here
    end
    def overconstrained?
      # move checks here
    end
    def solved?;                unsolved_forces.length==0 && resultant==[0,0,0];  end

    def max_magnitude;          solved_forces.inject(0) { |max,f| [max, f.magnitude.abs].max };  end
    
    def method_missing(sym, *args, &block)
      # Acts like a Geom::Point3d
      @p.send sym, *args, &block
    end
  end


  class Force 
    def initialize(p,v,_v=nil)
      @p = p
      @v = v
      @_p = nil
      @_v = _v
      @fixed = !_v.nil?
      @assumed = false
    end

    attr_reader                 :uid
    
    attr_accessor               :p
    attr_accessor               :v
    def p1;                     @p+@v;  end
    def line_of_action;         [@p,@v];  end

    def parallel?(v);           v ? !@v.cross(v).valid? : nil;  end
    def samedirection?(v);      v ? !@v.cross(v).valid? && @v.dot(v)>0 : nil;  end
    
    def length;                 Math.sqrt(@v.x**2+@v.y**2+@v.z**2);  end
    def length=(l);             @v.length = l.abs;  end

    attr_accessor               :_p
    attr_accessor               :_v
    def _p1                     @_p+@_v;  end
    def loop_segment;           [@_p,@_v];  end

    def solve(_v)               raise "must be parallel to loa" unless parallel? _v;  @_v = _v;  end  
    def solved?;                @_v;  end
    def unsolved?;              !@_v;  end
    def magnitude;              samedirection?(@_v) ? Math.sqrt(@_v.x**2+@_v.y**2+@_v.z**2) : -Math.sqrt(@_v.x**2+@_v.y**2+@_v.z**2);  end
    def magnitude=(m);          @_v.length=m.abs;  @_v.reverse! if m<0;  end
    PULLING                     = +1
    TENSION                     = +1
    def pulling?;               samedirection?(@_v);  end    
    alias :tension?             :pulling?
    PUSHING                     = -1
    COMPRESSION                 = -1
    def pushing?;               !samedirection?(@_v);  end
    alias :compression?         :pushing?
    def sign;                   samedirection?(@_v) ? PULLING : PUSHING;  end

    def complete(_p)            @_p = p;  end
    def complete?;              @_v && @_p;  end
    def incomplete?;            !@_v && !@_p;  end

    def clear;                  @_v=nil;  @_p.nil;  end    
  
    attr_accessor               :fixed
    attr_accessor               :assumed
    
    def +(f)
      # Assumes both forces are solved
      p = Geom.intersect_line_line(line_of_action,f.line_of_action)
      v = @_v+f._v
      Force.new(p,v)  
      ### FIX
    end
    
    def *(s)
      # Assumes force is solved
      f = clone
      _v = (s>0 ? @_v.clone : @_v.reverse)
      _v.length = f.magnitude.abs
      Force.new(p,v,_v)
      ## FIXXXX
    end

  end
end
