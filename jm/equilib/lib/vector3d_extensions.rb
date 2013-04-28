=begin
vector3d_extensions.rb
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


class Geom::Vector3d
  def length_jm
    # No string formatting
    Math.sqrt(x*x+y*y+z*z)
  end
  
  def length_jm=(m)
    length=m/25.4
  end
  
  def to_p3d
    Geom::Point3d.new(x,y,z)
  end
    
  def to_s
    "(#{"%.1f" % x},#{"%.1f" % y},#{"%.1f" % z})"
  end
end