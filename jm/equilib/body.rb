=begin
body.rb
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

  class Body < Joint
    def initialize(s)
      @s=s
      @loop = Loop.new
      @node = nil
      @visualization = nil
    end
    
    def uid;                    "Body";  end
    
    def name;                   "Body";  end
    def name=(n);               end  # don't do anything

    def status;                 @s.read_attribute("body_status");  end
    def status=(s);             @s.write_attribute("body_status",s);  end
  end

end