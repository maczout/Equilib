=begin
point3d_extensions.rb
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


class Geom::Point3d
  def *(sc)
    return Geom::Point3d.new(x * sc, y * sc, z * sc) if sc.is_a? Numeric
    raise "Can only multiply point by scalar"
  end
  
  def to_s
    "(#{"%.1f" % self.x},#{"%.1f" % self.y},#{"%.1f" % self.z})"
  end
  
  def to_v3d
    Geom::Vector3d.new(x,y,z)
  end
end