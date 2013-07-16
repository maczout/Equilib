=begin
inspect_tool.rb
Copyright Jamie McIntyre 2013

TThis file is part of Equilib. Equilib is a plugin for doing graphic statics in SketchUp.  
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

  class InspectTool  < Tool

    def update_status_bar
      case Picker.c
      when NilClass:
        JM::Equilib::UI.clear_vcb
        JM::Equilib::UI.set_status "Click to add joint."
      when JM::Equilib::Joint:
        JM::Equilib::UI.set_vcb "#{Picker.c.name} is ", Picker.c.status
        JM::Equilib::UI.set_status "Click to start force."          
      when JM::Equilib::Force:
        JM::Equilib::UI.set_vcb "#{Picker.c.name} = ", ("%.2f" % Picker.c.magnitude.to_f)
        if Picker.c.internal?
          JM::Equilib::UI.set_status "Click to specify magnitude"          
        else
          if @alt_toggle
            JM::Equilib::UI.set_status "Click to specify magnitude. ALT for more..."          
          else
            JM::Equilib::UI.set_status "Click to specify direction. ALT for more..."                 
          end
        end
      end
    end
    
    def draw(view)
      super(view)
      update_status_bar
    end
    
    def reset(view)
      @alt_toggle=true
      super(view)
    end
    
    def onCancel(reason, view)
      # ...do nothing.
    end

    def onKeyDown(key, repeat, flags, view)
      case key
      when VK_ALT:
        @alt_toggle = !@alt_toggle 
      end
    end

    def onLButtonDown(flags,x,y,view)
      Picker.pick(view,x,y)
      return if Picker.ip.nil? # This prevents adding force to force???
      case Picker.c
      when NilClass
        j0 = JM::Equilib::UI.active_sandbox.add_joint(Picker.last_pos)
        JM::Equilib::UI.active_sandbox.refresh
        JM::Equilib::UI.tools.push_tool AddForceTool.new(j0)
      when JM::Equilib::Joint:
        JM::Equilib::UI.tools.push_tool AddForceTool.new(Picker.c)
      when JM::Equilib::Force:
        if Picker.c.internal?
          JM::Equilib::UI.tools.push_tool SpecifyMagnitudeTool.new(Picker.c)
        else
          if @alt_toggle
            JM::Equilib::UI.tools.push_tool SpecifyMagnitudeTool.new(Picker.c)
          else
            JM::Equilib::UI.tools.push_tool SpecifyLineOfActionTool.new(Picker.c)
          end
        end
      end
    end

    def onMouseMove(flags, x, y, view)
      Picker.pick(view,x,y)
      view.invalidate
    end


  end 

end

