=begin
specify_line_of_action.rb
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

  class SpecifyLineOfActionTool  < Tool

    def initialize(extf)
      @extf = extf
      @ip0 = Sketchup::InputPoint.new(@extf.start_joint.position)
      
      @inferences = []
      @inferences[0] = [@extf.direction,"default"]
      @inferences[1] = [Geom::Vector3d.new(1,0,0),"On Red Axis"]
      @inferences[2] = [Geom::Vector3d.new(0,1,0),"On Blue Axis"]
      @inferences[3] = [Geom::Vector3d.new(0,0,1),"On Green Axis"]
    end


    def bake
      @extf.direction = @loa
      @extf.s.rebuild
      Picker.reset
      JM::Equilib::UI.tools.pop_tool
    end

    def activate
      super
      update_status_bar
    end

    def update_status_bar
      JM::Equilib::UI.set_status "Click to specify line of action. ↑ or ↓ to flip direction. TAB to cycle through inferences."
    end

    def update_loa(v=nil)
      unless v
        # get from Sketchup
        @loa = Picker.last_pos - @extf.start_joint.position
        if @loa.valid?
          @loa.length = @extf.calculate_external_length
          @loa.reverse! if @reverse
          @current_inference_index = 0
        else
          @loa = @inferences[0][0]
          @loa.length = @extf.calculate_external_length
        end
      else
        # get from preset inference
        @loa = @inferences[v][0]
        @loa.length = @extf.calculate_external_length
        @loa.reverse! if @reverse
      end
    end


    def reset(view)
      @current_inference_index=0
      @reverse = false
      update_loa @current_inference_index
      super(view)
    end

    def draw_ip?;  Picker.ip.display?;  end


    def draw(view)
      super(view)

      p0 = @extf.start_joint.position
      p = p0 + @loa
      view.draw_line p0,p
      
      p = Picker.last_pos
      view.line_stipple = "."
      view.set_color_from_line(@ip0, Picker.ip) if Picker.ip.valid?
      view.draw_line p0,p 
      
      Picker.ip.draw(view) if Picker.ip.display?
      
      update_status_bar
    end
    

    def onKeyDown(key, repeat, flags, view)
      case key
      when VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN:
        @reverse = !@reverse
        @loa.reverse!
        view.invalidate

      when 9:  #tab
        @current_inference_index = (@current_inference_index+1) % @inferences.size
        update_loa @current_inference_index
        JM::Equilib::UI.set_tooltip (@inferences[@current_inference_index][1])
        view.invalidate
        
      when 13:    # ENTER
        bake
        
      end
    end


    # onCancel is called when the user hits the escape key
    def onCancel(reason, view)
      JM::Equilib::UI.tools.pop_tool
    end


    def onKeyUp(key, repeat, flags, view)
      case key
      when 9:  #tab only works onKeyUp
        @current_inference_index = (@current_inference_index+1) % @inferences.size
        update_loa @current_inference_index
        JM::Equilib::UI.set_tooltip (@inferences[@current_inference_index][1])
        view.invalidate
      end
    end


    def onLButtonDown(flags, x, y, view)
      bake
    end


    def onMouseMove(flags, x, y, view)
      Picker.pick(view,x,y,@ip0)
      update_loa
      view.invalidate
    end


  end 

end