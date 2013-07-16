=begin
ui.rb
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
  class << self

    def reset
      clear_tooltip
      clear_status
      clear_vcb
      Picker.reset
    end

    def load_menus_and_toolbars
      equilib_cmd = UI::Command.new("Equilib") do
        Sketchup.active_model.tools.push_tool JM::Equilib::UI::InspectTool.new unless JM::Equilib::UI.active_tool
      end
      equilib_cmd.menu_text = "Equilib"
      equilib_cmd.set_validation_proc do
        if active_tool
          MF_CHECKED
        else
          MF_UNCHECKED
        end
      end

      refresh_cmd = UI::Command.new("Refresh") do
        JM::Equilib::UI.active_sandbox.rebuild
      end
      refresh_cmd.menu_text = "Refresh"

      refresh_automatically_cmd = UI::Command.new("Refresh Automatically") do
        JM::Equilib::UI.active_sandbox.refresh_automatically = !JM::Equilib::UI.active_sandbox.refresh_automatically?
      end
      refresh_automatically_cmd.menu_text = "Refresh Automatically"
      refresh_automatically_cmd.set_validation_proc do
        if JM::Equilib::UI.active_sandbox.refresh_automatically?
          MF_CHECKED
        else
          MF_UNCHECKED
        end
      end

      visualize_forces_cmd = UI::Command.new("Visualize Forces") do
        JM::Equilib::UI.active_sandbox.visualize_forces = !JM::Equilib::UI.active_sandbox.visualize_forces? 
      end
      visualize_forces_cmd.menu_text = "Visualize Forces"
      visualize_forces_cmd.set_validation_proc do
        if JM::Equilib::UI.active_sandbox.visualize_forces?
          MF_CHECKED
        else
          MF_UNCHECKED
        end
      end

      show_force_diagram_cmd = UI::Command.new("Show Force Diagram") do
        JM::Equilib::UI.active_sandbox.show_force_diagram = !JM::Equilib::UI.active_sandbox.show_force_diagram? 
      end
      show_force_diagram_cmd.menu_text = "Show Force Diagram"
      show_force_diagram_cmd.set_validation_proc do
        if JM::Equilib::UI.active_sandbox.show_force_diagram?
          MF_CHECKED
        else
          MF_UNCHECKED
        end
      end

      export_to_csv_cmd = UI::Command.new("Export to CSV...") do
        root_dir = Sketchup.find_support_file("Plugins/JM/Equilib")
        path_to_save_to = UI.savepanel "Export to CSV", root_dir, "equilib.csv"
        to_file = File.open(path_to_save_to, 'w') do |to_file|
          JM::Equilib::UI.active_sandbox.to_csv { |t| to_file.puts t } 
          to_file.close
        end
      end
      export_to_csv_cmd.menu_text = "Export to CSV..."


      specify_magnitude_cmd = UI::Command.new("Specify Magnitude") do
        JM::Equilib::UI.tools.push_tool JM::Equilib::UI::SpecifyMagnitudeTool.new(JM::Equilib::UI::Picker.c, JM::Equilib::UI::Picker.ip_copy)
      end
      specify_magnitude_cmd.menu_text = "Specify Magnitude"

      specify_line_of_action_cmd = UI::Command.new("Specify Line of Action") do
        JM::Equilib::UI.tools.push_tool JM::Equilib::UI::SpecifyLineOfActionTool.new(JM::Equilib::UI::Picker.c, JM::Equilib::UI::Picker.ip_copy)
      end
      specify_line_of_action_cmd.menu_text = "Specify Line of Action"

      clear_magnitude_cmd = UI::Command.new("Clear Magnitude") do
        JM::Equilib::UI.tools.pop_tool if JM::Equilib::UI.current_tool.is_a? JM::Equilib::UI::SpecifyMagnitudeTool
        JM::Equilib::UI::Picker.c.release_magnitude
        JM::Equilib::Sandbox.active_sandbox.rebuild
      end
      clear_magnitude_cmd.menu_text = "Clear Magnitude"

      equilib_submenu = UI.menu("Plugins").add_submenu("Equilib")
      equilib_submenu.add_item refresh_cmd 
      equilib_submenu.add_separator  
      equilib_submenu.add_item refresh_automatically_cmd 
      equilib_submenu.add_item visualize_forces_cmd
      equilib_submenu.add_item show_force_diagram_cmd
      equilib_submenu.add_separator  
      equilib_submenu.add_item export_to_csv_cmd

      tools_menu = UI.menu("Tools")
      tools_menu.add_separator  
      tools_menu.add_item equilib_cmd

      UI.add_context_menu_handler do |m|
        m.add_separator
        m.add_item Overlay.rebuild_cmd
        case Picker.c
        when JM::Equilib::Force:
          m.add_separator
          unless Picker.c.fixed?
            m.add_item UI.specify_magnitude_cmd
          else
            m.add_item UI.clear_magnitude_cmd
          end
          if Picker.c.external? m.add_item(UI.specify_line_of_action_cmd)
          end
        end
      end
    end

    def active_sandbox;   JM::Equilib::Sandbox.active_sandbox;  end
    def active_model;     JM::Equilib::Sandbox.active_sandbox.model;  end
    def tools;            JM::Equilib::Sandbox.active_sandbox.model.tools;  end
    attr_accessor         :active_tool
    def active_view;      JM::Equilib::Sandbox.active_sandbox.model.active_view;   end

    def set_tooltip(s)
      Sketchup.active_model.active_view.tooltip = s
    end
    def clear_tooltip
      Sketchup.active_model.active_view.tooltip = ""
    end

    def set_status(s)
      Sketchup.set_status_text s, SB_PROMPT
    end
    def clear_status
      Sketchup.set_status_text "", SB_PROMPT
    end

    def set_vcb(l,s)
      use_equilib_units
      Sketchup.set_status_text l, SB_VCB_LABEL
      Sketchup.set_status_text s, SB_VCB_VALUE
    end
    def clear_vcb
      use_sketchup_units
      Sketchup.set_status_text "", SB_VCB_LABEL
      Sketchup.set_status_text "", SB_VCB_VALUE
    end
    def use_equilib_units
      # Change unit options so vcb is compatible with non-length magnitudes (forces, etc)
      return if @user_units_options
      @user_units_options = {}
      @user_units_options["LengthFormat"] = Sketchup.active_model.options["UnitsOptions"]["LengthFormat"]
      @user_units_options["LengthUnit"] = Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]
      @user_units_options["LengthSnapEnabled"] = Sketchup.active_model.options["UnitsOptions"]["LengthSnapEnabled"]
      @user_units_options["LengthPrecision"] = Sketchup.active_model.options["UnitsOptions"]["LengthPrecision"]
      @user_units_options["SuppressUnitsDisplay"] = Sketchup.active_model.options["UnitsOptions"]["SuppressUnitsDisplay"]
      Sketchup.active_model.options["UnitsOptions"]["LengthFormat"]=0 # decimal
      Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]=2  # mm
      Sketchup.active_model.options["UnitsOptions"]["LengthSnapEnabled"]=false # grid snap off
      Sketchup.active_model.options["UnitsOptions"]["LengthPrecision"]=0 # no decimals
      Sketchup.active_model.options["UnitsOptions"]["SuppressUnitsDisplay"]=true # hide "mm"
    end
    def use_sketchup_units
      # Restore user units options for normal display of lengths, etc.
      return unless @user_units_options
      Sketchup.active_model.options["UnitsOptions"]["LengthFormat"]= @user_units_options["LengthFormat"]
      Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]= @user_units_options["LengthUnit"]
      Sketchup.active_model.options["UnitsOptions"]["LengthSnapEnabled"]= @user_units_options["LengthSnapEnabled"]
      Sketchup.active_model.options["UnitsOptions"]["LengthPrecision"]= @user_units_options["LengthPrecision"]
      Sketchup.active_model.options["UnitsOptions"]["SuppressUnitsDisplay"]= @user_units_options["SuppressUnitsDisplay"]
      @user_units_options=nil
    end

  end

end

