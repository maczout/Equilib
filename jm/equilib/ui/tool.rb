=begin
tool.rb
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

  class Tool  < Sketchup::ViewObserver

    def activate
      JM::Equilib::UI.active_tool = self
      JM::Equilib::UI.active_view.add_observer self
      reset JM::Equilib::UI.active_view
    end

    def resume(view)
      JM::Equilib::UI.active_tool = self
      reset view
    end

    def reset(view)
      JM::Equilib::UI.clear_tooltip
      JM::Equilib::UI.clear_status
      JM::Equilib::UI.clear_vcb
      view.invalidate
    end

    def deactivate(view)
      JM::Equilib::UI.active_tool = nil
      view.remove_observer self
      view.invalidate
    end

    def draw(view)
      JM::Equilib::UI.active_sandbox.refresh
    end

    def enableVCB?
      false
    end

    def onViewChanged(view)
      view.invalidate
    end

  end

end





