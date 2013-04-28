=begin
picker.rb
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


module JM::Equilib::UI::Picker
  class << self

    def reset
      # clear the InputPoint and picked component
      if @ip
        @ip.clear 
      else
        @ip = Sketchup::InputPoint.new
      end  
      @c=nil
      @last_pos = nil
      @draw_ip = false
      puts caller
    end

    attr_accessor :c
    attr_accessor :ip
    attr_accessor :last_pos
    attr_accessor :draw_ip

    def ip_copy
      ip = Sketchup::InputPoint.new
      ip.copy! @ip
    end


    def pick(view,x,y,ip0=nil)
      # Try to pick an equilib component with PickHelper
      ph = view.pick_helper
      ph.do_pick x,y
      e = ph.best_picked
      uid = JM::Equilib::ComponentInstanceWrapper.get_uid(e)
      puts uid
      @c = JM::Equilib::Sandbox.active_sandbox.components_map[JM::Equilib::Joint][uid]
      @c = JM::Equilib::Sandbox.active_sandbox.components_map[JM::Equilib::Force][uid] unless @c
      if @c 
        if @c.is_a? JM::Equilib::Joint
          # We have an Equilib Joint - custom inferencing
          @ip.copy! Sketchup::InputPoint.new(self.c.position) 
          view.tooltip = self.c.name
          @last_pos = @ip.position
          @draw_ip = false
        elsif @c.is_a? JM::Equilib::Force
          @ip.pick(view,x,y,ip0)
          view.tooltip = ""
          @last_pos = @ip.position
          @ip.clear
          @draw_ip = false
        end
      else
        # Otherwise - normal inferencing (with some overrides)
        @ip.pick(view,x,y,ip0)
        view.tooltip = @ip.tooltip
        @last_pos = @ip.position
        @draw_ip = true
      end
      JM::Equilib::Debug.log "pick @c=#{@c} @ip0=#{@ip0.position if @ip0} @ip=#{@ip.position if @ip} @last_pos=#{@last_pos}"
      return @last_pos
    end
  end
end

