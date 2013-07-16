=begin
joint.rb
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

  class Joint
    include ComponentInstanceWrapper

    class << self
      def load(s,ci,vis_ci)
        Joint.new(s,ci,vis_ci)
      end

      def create(s,pos)
        ci = Joint.create_ci(s,pos)
        Joint.new(s,ci)
      end
      def create_ci(s,p)
        trans = Geom::Transformation.new(p)  # temporary until refresh is called
        ci = s.entities.add_instance(s.model.definitions['Equilib_Joint'], trans)  # temporary until refresh is called
        ci.set_attribute("Equilib","uid",ComponentInstanceWrapper.create_uid)
        ci.name = ComponentInstanceWrapper.create_name(s.entities,"J")
        ci
      end
    end

    def initialize(s,ci,vis_ci=nil)
      @s = s
      @ci = ci
      @visualization = Visualization.new(self,vis_ci)
      @loop = JM::Equilib::Joint::Loop.new    
    end

    attr_accessor               :s

    def hide;                   raise "Joint always visible";  end
    def get_definition;         @s.model.definitions['Equilib_Joint'];  end
    def get_transformation;     Geom::Transformation.new(position);  end  
    def get_name_root;          "J";  end 

    def position;               carefully { @ci.transformation.origin };  end
    def position=(p);           carefully { @ci.transformation = get_transformation(p) };  end

    def get_forces;             @s.components_map[JM::Equilib::Force].values.reject { |f| f.start_joint_uid!=uid && f.end_joint_uid!=uid };  end
    def get_unknown_forces;     get_forces.reject { |f| f.v };  end
    def get_known_forces;       get_forces.reject { |f| f.v.nil? };  end
    def get_average_direction
      direction = get_forces.inject(Geom::Vector3d.new(0,0,0)) do |sum,f| 
        sum = sum + f.direction.normalize
      end
      direction.normalize
    end
    def get_resultant;          get_known_forces.inject(Geom::Vector3d.new(0,0,0)) { |sum,f| sum + f.get_v_at(self) };  end
    def get_max_magnitude;      get_known_forces.inject(0) { |max,f| [max, f.magnitude.to_f.abs].max };  end

    def status;                 read_attribute("status");  end
    def status=(s);             write_attribute("status",s);  end
    def clear_status;           self.status=nil;  end
    def solved?;                status=='solved';  end
    def check_solved?;          get_unknown_forces.length==0 && self.get_resultant==[0,0,0];  end
    def overconstrained?;       status=='overconstrained';  end
    def underconstrained?;      status=='underconstrained';  end

    attr_reader                 :loop 
    class Loop  # Ordered hash functionality
      def initialize
        @i={}
        @k=[]
        @v=[]
      end

      def [](k)
        @v[@i[k]]
      end
      def value_after(k)
        @v[(@i[k]+1) % length]
      end
      def value_before(k)
        @v[(@i[k]-1) % length]
      end
      
      def []=(k,v)
        @i[k] = length
        @k << k
        @v << v
      end

      def clear
        @i.clear
        @k.clear
        @v.clear
      end

      def length;     @k.length;  end
      def complete?;    length!=0;  end  # Assumes that will only be called when loops are empty
      
      def keys;  @k;  end
      def values;  @v;  end

      def each
        (0..length-1).each do |i|
          yield @k[i], @v[i]
        end
      end
      def each_key
        (0..length-1).each do |i|
          yield @k[i]
        end
      end
      def each_value
        (0..length-1).each do |i|
          yield @v[i]
        end
      end
    end

   
    attr_accessor :visualization

    class Visualization
      include ComponentInstanceWrapper

      class << self
        def diameter;             Sandbox.active_sandbox.model.definitions['Equilib_JointVisualization'].bounds.width;  end

        attr_accessor             :diameter_scale
        attr_accessor             :min_diameter
        attr_accessor             :max_diameter

        attr_accessor             :colours
      end

      def get_definition;       @c.s.model.definitions['Equilib_JointVisualization'];  end

      @diameter_scale           = 1.33*0.005
      @min_diameter             = 1.33*1.0
      @max_diameter             = 1.33*10.0
      def get_transformation
        location = Geom::Transformation.new(@c.position)
        scale = [[@c.get_max_magnitude*Visualization.diameter_scale,Visualization.min_diameter].max,Visualization.max_diameter].min/Visualization.diameter
        scaling = Geom::Transformation.scaling(scale,scale,scale)  
        location*scaling
      end
      
      @colours                  = {}
      @colours[true]            = Sketchup::Color.new(102,102,102)
      @colours[false]           = Sketchup::Color.new(206,206,206)
      def get_material;         highlighted? ? ComponentInstanceWrapper.highlight_colour : Visualization.colours[@c.solved?];  end

      def get_alpha;            0.5;  end      
      
      def get_name_root;                                  "#{@c.name} Visualization";  end

      def diameter;             carefully { @ci.bounds.width };  end
    end
    
    def inspect
      s = super + "{"
      loop.each do |k,v|
        s = s+@s.components_map[JM::Equilib::Force][k].name+v.to_s+","
      end
      s.strip + "}"
    end
    
  end

end