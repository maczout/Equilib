=begin
copmponent_instance_wrapper.rb
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


module JM::Equilib::ComponentInstanceWrapper

  class << self
    def create_name(entities,from,index=nil)
      if index.nil?
        str = from
        index = 0
      else
        str = "#{from} \##{index}"
      end
      hash = entities.reject{|e| e.class != Sketchup::ComponentInstance}.inject({}){|h,e| h[e.name] = e; h}
      if hash.has_key?(str)
        index=index+1
        self.create_name(entities, from, index) # finite number of components in entities
      else
        return str
      end
    end

    def create_uid;             "#{Time.now.usec}#{rand(1000000)}".to_i.to_s(16);  end
    def get_uid(e)
      if e.respond_to? :get_attribute  
        e.get_attribute(:Equilib.to_s,:uid.to_s,nil)
      else
        nil
      end
    end

    @highlight_colour           = Sketchup::Color.new(255,255,0)
  end


  def initialize(c,ci)
    @c = c # equilib component
    @ci = ci
  end

  attr_accessor :c

  attr_accessor :ci
  def carefully
    begin
      r = yield
    rescue TypeError
      @c.s.rebuild_components_map
      r = yield
    end
    r
  end

  def visible?;         @ci;  end

  def name;             carefully { @ci.name };  end
  def name=(n);         carefully { @ci.name = n };  end

  def uid;              read_attribute("uid");  end

  def ==(c);            c.respond_to?(:uid) ? self.uid == c.uid : nil;  end

  def highlighted?;     JM::Equilib::UI::Picker.c == self;  end

  def read_attribute(key)
    carefully do
      a = @ci.get_attribute(:Equilib.to_s,key,nil)
      a != "" ? a : nil
    end
  end
  def write_attribute(key,value)
    carefully do
      value = "" if value.nil?
      @ci.set_attribute(:Equilib.to_s,key,value.to_s)
      value
    end
  end

  def get_ci
    ci = @c.s.entities.add_instance(get_definition, get_transformation)  
    ci.set_attribute("Equilib","uid",@c.uid)
    ci.name = JM::Equilib::ComponentInstanceWrapper.create_name(@c.s.entities,get_name_root)
    ci
  end
  def get_material;                             nil;  end
  def get_alpha;                                nil;  end
  
  def refresh
    carefully do
      if !@ci
        @ci = get_ci
      else
        @ci.definition = get_definition
        @ci.transformation = get_transformation
      end
      @ci.material = get_material unless get_material.nil?
      @ci.material.alpha = get_alpha unless get_alpha.nil?
    end
  end
  def hide;             @c.s.entities.erase_entities(@ci);  end   # assumes @ci exists


  def inspect;          "<#{self.class.name}:#{self.uid}>";  end
end