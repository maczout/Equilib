=begin
form_diagram.rb
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

  class FormDiagram
    def initialize(s);          @s = s;  end

    def refresh
      @s.components_map[JM::Equilib::Joint].each_value do |j|
        j.refresh
        if @s.visualize_forces?
          j.visualization.refresh
        else
          j.visualization.hide if j.visualization.visible?
        end
      end
      @s.components_map[JM::Equilib::Force].each_value do |f|
        f.refresh
        if @s.visualize_forces?
          f.visualization.refresh
        else
          f.visualization.hide if f.visualization.visible?
        end
      end
    end
  end

end