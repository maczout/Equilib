=begin
add_force_tool.rb
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

require 'sketchup.rb'


module JM::Equilib::UI

  class AddForceTool  < Tool

    def initialize(j0)
      @j0 = j0
    end
    
    def reset(view)
      @ip0 = Sketchup::InputPoint.new(@j0.position)
      @internal = (Picker.c != @j0)
      @loa = @j0.get_average_direction 
      @loa = Geom::Vector3d.new(1,0,0) if !@loa.valid?
      @loa.length = JM::Equilib::Force.length
      @p0 = @j0.position
      @p = @p0+@loa
      super(view)
    end

    def bake(view)
      if @internal
        j1 = (Picker.c.is_a? JM::Equilib::Joint) ? Picker.c : JM::Equilib::UI.active_sandbox.add_joint(Picker.last_pos)
        f = JM::Equilib::UI.active_sandbox.add_internal_force(@j0,j1)
        @j0.s.rebuild
        @j0=j1
        reset(view)
      else
        f = JM::Equilib::Sandbox.active_sandbox.add_force(@j0,@loa)  
        @j0.s.rebuild
        JM::Equilib::UI.tools.pop_tool
        JM::Equilib::UI.tools.push_tool SpecifyLineOfActionTool.new(@f)
      end
    end

    def activate
      super
      update_status_bar
    end

    def update_status_bar
      JM::Equilib::UI.set_status "Click to add #{@internal ? 'internal' : 'external'} force."
    end

    def draw_ip?;  Picker.ip.display?;  end
    
    def draw(view)
      super(view)
      if @internal
        view.set_color_from_line(@ip0.position, Picker.last_pos)
        view.line_stipple = "."
        view.draw_line @ip0.position, Picker.last_pos
        p0 = Picker.last_pos
        view.line_stipple = "."
        p = view.screen_coords p0
        joint_radius = 4.0
        number_of_vertices = 8
        angle_increment = 2.0*Math::PI/number_of_vertices
        vertices = []
        for i in 0..number_of_vertices-1
          theta = angle_increment*i
          vertices[i] = Geom::Point3d.new(p.x+joint_radius*Math.cos(theta), p.y-joint_radius*Math.sin(theta))
        end
        view.draw2d GL_LINE_LOOP, vertices
        Picker.ip.draw(view) if Picker.ip.display?
        update_status_bar
      else
        view.line_stipple = "."
        view.drawing_color = 0
        view.draw_line @p0,@p
      end
      update_status_bar
    end

    def onCancel(reason, view)
      JM::Equilib::UI.tools.pop_tool
    end

    def onKeyDown(key, repeat, flags, view)
      case key
      when 13:    # ENTER
        bake(view)
      end
    end

    def onLButtonDown(flags, x, y, view)
      bake(view)
    end

    def onMouseMove(flags, x, y, view)
      Picker.pick(view,x,y,@ip0)
      @internal = (Picker.c != @j0)
      view.invalidate
    end

  end 
end