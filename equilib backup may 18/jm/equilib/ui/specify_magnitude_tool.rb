=begin
specify_magnitude.rb
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


module JM::Equilib::UI

  class SpecifyMagnitudeTool  < Tool

    def initialize(force)
      @c0 = force
      @scroll_length = 200
      @max_force = JM::Equilib::Force::Visualization.saturation_force
      @snap_radius = 5.0
      @force_increment = 10.0
      @release_radius = 20.0
      @default_force = force.magnitude.to_f
    end

    def onViewChanged(view)
       reset view
       super(view)
    end

    def bound_ordinate(z)
      o = [[z,@scroll_length/2].min,-@scroll_length/2].max
    end
    private :bound_ordinate

    def snap_ordinate(z)
      z = @default_ordinate if (z-@default_ordinate).abs<@snap_radius
      z = 0 if z.abs<@snap_radius
      z
    end
    private :snap_ordinate

    def get_ordinate(magnitude)
      o = bound_ordinate(magnitude / (@max_force/(@scroll_length/2)).abs)
    end
    private :get_ordinate

    def get_magnitude(ordinate)
      m = ordinate * (@max_force/(@scroll_length/2)).abs
      m.round.to_f
    end
    private :get_magnitude


    def reset(view)
      if @c0.internal?
        origin_3d = Geom::Point3d.linear_combination(0.5,@c0.start_joint.position, 0.5, @c0.end_joint.position)
      else
        origin_3d = @c0.start_joint.position
      end
      origin = view.screen_coords(origin_3d)
      origin.z = 0
      perp_dirn = view.screen_coords(Geom::Point3d.new(0,0,0) + @c0.direction)-view.screen_coords(Geom::Point3d.new(0,0,0))
      zaxis = Geom::Vector3d.new(-perp_dirn.y, perp_dirn.x, 0).normalize
      @scroll_to_xy = Geom::Transformation.new(origin,zaxis)
      @xy_to_scroll = @scroll_to_xy.inverse

      @right=zaxis.x<=>0
      @up=-zaxis.y<=>0

      @default_ordinate = get_ordinate(@default_force)
      @ordinate = @default_ordinate
      @magnitude = @default_force

      super(view)
    end


    def bake
      @c0.magnitude = @magnitude
      @magnitude ? @c0.fix : @c0.clear_status;
      @c0.s.rebuild
      Picker.reset
      JM::Equilib::UI.tools.pop_tool
    end


    def activate
      super
      update_status_bar
    end

    def update_status_bar
      JM::Equilib::UI.set_status "Adjust magnitude with cursor or ↑,↓ to nudge. TAB to key magnitude in VCB. 'x' to release."
      JM::Equilib::UI.set_vcb "#{@c0.name} = ", @magnitude.nil? ? "(release)" : ("%.2f" % @magnitude)
    end

    def draw(view)
      super(view)

      # scrollbar
      upper_bound = Geom::Point3d.new(0,0,@scroll_length/2).transform @scroll_to_xy
      lower_bound = Geom::Point3d.new(0,0,-@scroll_length/2).transform @scroll_to_xy
      view.line_width = 1
      view.line_stipple = "-"
      view.drawing_color = "black"
      view.draw2d(GL_LINES, [lower_bound, upper_bound])

      # zero ordinate
      default_ordinate_l = Geom::Point3d.new(-4,0,0).transform @scroll_to_xy
      default_ordinate_r = Geom::Point3d.new(0,0,0).transform @scroll_to_xy
      view.line_width = 1
      view.line_stipple = "-"
      view.drawing_color = "black"
      view.draw2d(GL_LINES, [default_ordinate_l, default_ordinate_r])        

      # default ordinate
      if(@default_ordinate != 0)
        default_ordinate_l = Geom::Point3d.new(-4,0,@default_ordinate).transform @scroll_to_xy
        default_ordinate_r = Geom::Point3d.new(0,0,@default_ordinate).transform @scroll_to_xy
        view.line_width = 1
        view.line_stipple = "-"
        view.drawing_color = "black"
        view.draw2d(GL_LINES, [default_ordinate_l, default_ordinate_r])
      end

      # marker
      unless @magnitude.nil?
        ordinate_l = Geom::Point3d.new(0,0,@ordinate).transform @scroll_to_xy
        ordinate_r = Geom::Point3d.new(8,0,@ordinate).transform @scroll_to_xy
        view.line_width = 2
        view.line_stipple = ""
        view.drawing_color = JM::Equilib::Force::Visualization.colours[false]['fixed'][@ordinate<=>0]
        view.draw2d(GL_LINES, [ordinate_l, ordinate_r])
      end

      update_status_bar
    end


    def enableVCB?
      true
    end


    # onCancel is called when the user hits the escape key
    def onCancel(reason, view)
      JM::Equilib::UI.tools.pop_tool
    end



    def onMouseMove(flags,x,y,view)
      p = Geom::Point3d.new(x,y,0).transform @xy_to_scroll
      unbounded_ordinate = p.z
      @ordinate = snap_ordinate(bound_ordinate(p.z))
      unless ((unbounded_ordinate-@ordinate).abs > @release_radius)
        @magnitude = get_magnitude(@ordinate)
      else
        @magnitude = nil
      end
      view.invalidate
    end


    def onKeyDown(key, repeat, flags, view)
      unless @magnitude.nil?
        case key
        when VK_LEFT:
          @magnitude = [@magnitude - @right*@force_increment, -@max_force].max
          @ordinate = get_ordinate(@magnitude)
          view.invalidate
        when VK_DOWN:
          @magnitude = [@magnitude - @up*@force_increment, -@max_force].max
          @ordinate = get_ordinate(@magnitude)
          view.invalidate
        when VK_RIGHT:
          @magnitude = [@magnitude + @right*@force_increment, @max_force].min
          @ordinate = get_ordinate(@magnitude)
          view.invalidate
        when VK_UP:
          @magnitude = [@magnitude + @up*@force_increment, @max_force].min
          @ordinate = get_ordinate(@magnitude)
          view.invalidate
        when 13:    # ENTER
          bake
        when 120:
          @magnitude = nil
          bake
        end
      else
        # will release
        case key
        when 13,120: # ENTER
          bake
        end
      end
    end


    attr_accessor :release

    def onLButtonDown(flags,x,y,view)
      bake
    end


    def onUserText(text, view)
      if text.numeric_jm?
        @magnitude = text.to_f
        bake
      else
        Overlay.display_force_in_vcb @c0, get_magnitude(@ordinate)
      end
    end


  end

end


