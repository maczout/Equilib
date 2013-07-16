=begin
string.rb
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

class String
  
  # Monkey patch
  def to_camelcase
    self.split(/[^a-z0-9]/i).map{|w| w.capitalize}.join 
  end
  
  def to_lowercase
    self.split(/[^A-Z0-9]/i).map{|w| w.downcase + "_"}.join.chop
  end
  
  def to_f_jm
    return nil if self == ""
    return self.to_f
  end
  
  def to_b_jm
    return false if self == "false"
    return true
  end
  
    def numeric_jm?
      Float(self) != nil rescue false
    end
end