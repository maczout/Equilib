=begin
loader.rb
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


unless file_loaded?(__FILE__)

  module JM
    module Equilib
      module UI
      end
    end
  end

  require 'sketchup'

  require 'jm/equilib/component_instance_wrapper.rb'
  require 'jm/equilib/form_diagram.rb'
  require 'jm/equilib/force_diagram.rb'
  require 'jm/equilib/joint.rb'
  require 'jm/equilib/body.rb'
  require 'jm/equilib/force.rb'
  require 'jm/equilib/sandbox.rb'

  require 'jm/equilib/ui/ui.rb'
  require 'jm/equilib/ui/picker.rb'
  require 'jm/equilib/ui/tool.rb'
  require 'jm/equilib/ui/inspect_tool.rb'
  require 'jm/equilib/ui/add_force_tool.rb'
  require 'jm/equilib/ui/specify_line_of_action_tool.rb'
  require 'jm/equilib/ui/specify_magnitude_tool.rb'

  require 'jm/equilib/lib/string.rb'
  require 'jm/equilib/lib/transformation_extensions.rb'
  require 'jm/equilib/lib/point3d_extensions.rb'
  require 'jm/equilib/lib/vector3d_extensions.rb'

  require 'jm/equilib/debug.rb'
  
  # This will not work on the Mac version with multiple windows open
  Dir["#{File.dirname(__FILE__)}/component/*.skp"].each { |p| Sketchup.active_model.definitions.load p }

  JM::Equilib::UI.load_menus_and_toolbars
  JM::Equilib::UI.reset
  
  JM::Equilib::Sandbox.active_sandbox = JM::Equilib::Sandbox.new(Sketchup.active_model.entities)
  $s = JM::Equilib::Sandbox.active_sandbox;

end

