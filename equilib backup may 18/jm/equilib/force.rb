=begin
force.rb
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

  class Force 
    include ComponentInstanceWrapper

    PULLING                     = +1
    TENSION                     = +1
    PUSHING                     = -1
    COMPRESSION                 = -1

    YZ_PLANE                    = 0
    XZ_PLANE                    = 1
    XY_PLANE                    = 2

    class << self      
      def length;                 Sandbox.active_sandbox.model.definitions['Equilib_Force'].bounds.depth;  end

      def load(s,ci,vis_ci,vec_ci,dupvec_ci)
        f = Force.new(s,ci,vis_ci,vec_ci,dupvec_ci)
        f.magnitude = f.fixed_magnitude
        f
      end

      def create_internal(s,sj,ej)
        ci = Force.create_internal_ci(s,sj,ej)
        Force.new(s,ci)
      end
      def create_internal_ci(s,sj,ej)
        v = ej.position-sj.position
        location = Geom::Transformation.new(sj.position,v)
        z_scale = v.length_jm/Force.length
        scaling = Geom::Transformation.scaling(1,1,z_scale)
        trans = location*scaling  # temporary transformation until refresh is called
        ci = s.entities.add_instance(s.model.definitions['Equilib_Force'], trans)
        ci.set_attribute("Equilib","uid",ComponentInstanceWrapper.create_uid)
        ci.set_attribute("Equilib","start_joint_uid",sj.uid)
        ci.set_attribute("Equilib","end_joint_uid",ej.uid)
        ci.name = ComponentInstanceWrapper.create_name(s.entities,"F")
        ci
      end
      
      def create_external(s,sj,dir)
        ci = Force.create_external_ci(s,sj,dir)
        Force.new(s,ci)
      end
      def create_external_ci(s,sj,dir)
        trans = Geom::Transformation.new(sj.position,dir) # temporary transformation until refresh is called
        ci = s.entities.add_instance(s.model.definitions['Equilib_Force'], trans)
        ci.set_attribute("Equilib","uid",ComponentInstanceWrapper.create_uid)
        ci.set_attribute("Equilib","start_joint_uid",sj.uid)
        ci.set_attribute("Equilib","end_joint_uid","Body")
        ci.name = ComponentInstanceWrapper.create_name(s.entities,"F")
        ci
      end
    end

    def initialize(s,ci,vis_ci=nil,vec_ci=nil,dupvec_ci=nil)
      @s = s
      @v = nil
      @ci=ci
      @visualization = Visualization.new(self,vis_ci) 
      @vector = Vector.new(self,vec_ci) 
      @duplicate_vector = DuplicateVector.new(self,dupvec_ci) 
    end

    attr_accessor               :s

    def show;                   refresh;  end
    def hide;                   raise "Force always visible";  end
    def get_definition;         @s.model.definitions['Equilib_Force'];  end
    def get_transformation
      if internal?
        p0 = start_joint.position
        v = end_joint.position-p0
        location = Geom::Transformation.new(p0,v)
        z_scale = v.length_jm/Force.length
        scaling = Geom::Transformation.scaling(1,1,z_scale)
      else
        p0 = start_joint.position
        v = direction
        location = Geom::Transformation.new(p0,v)
        z_scale = calculate_external_length/JM::Equilib::Force.length
        scaling = Geom::Transformation.scaling(1,1,z_scale)
      end
      location*scaling
    end
    def calculate_external_length;      [@visualization.calculate_joint_offset(start_joint)+@visualization.calculate_external_length,10.0].max;   end
      
    def line_of_action;         carefully { [@ci.transformation.origin, @ci.transformation.zaxis] };  end
    def direction;              carefully { @ci.transformation.zaxis };  end    
    def direction=(d)
      raise "Can't set direction of internal force" if internal?
      carefully do
        @ci.transformation = Geom::Transformation.new(start_joint.position, d)
      end
    end

    def get_name_root;          "F";  end 

    def start_joint_uid;        read_attribute("start_joint_uid");  end
    def start_joint_uid=(u);    write_attribute("start_joint_uid",u);  end
    def start_joint;            @s.components_map[JM::Equilib::Joint][start_joint_uid];  end

    def end_joint_uid;          read_attribute("end_joint_uid");  end
    def end_joint_uid=(u);      write_attribute("end_joint_uid",u);  end
    def end_joint;              @s.components_map[JM::Equilib::Joint][end_joint_uid];  end

    def other_joint(j);         j.uid==start_joint_uid ? end_joint : start_joint;  end

    def internal?;              end_joint_uid!="Body";  end
    def external?;              end_joint_uid=="Body";  end
    
    def get_angle(tr,flat_index,j)
      # Transform into provided coordinate system
      v_prime = direction.clone
      v_prime.reverse! unless j==self.start_joint
      v_prime.reverse! if (external? && pushing?)
      v_prime.transform!(tr.inverse)
      v_prime[flat_index] = 0
      v_prime.normalize!
      return nil unless v_prime.valid?
      # Project to x-y plane
      zero_axis = Geom::Vector3d.new
      zero_axis[(flat_index-1)%3] = 1
      ang = zero_axis.angle_between(v_prime)
      if v_prime[(flat_index+1)%3]<0
        ang = (2*Math::PI - ang) 
      end
      ang
    end
    def length;                 carefully { @ci.transformation.scaleZ * Force.length };  end

    attr_accessor               :v # taken at start joint, scaled to force diagram scale
    def get_v_at(j)
      return if @v.nil?
      if j==start_joint 
        @v.clone 
      else
        @v.reverse
      end
    end
    def set_v_at(j,v)
      raise "v must be parallel to loa" unless v.parallel? direction
      @v = (j==start_joint ? v.clone : v.reverse)
    end
    def clear_v;                @v=nil;  end

    def magnitude
      return if @v.nil?
      (@v.samedirection?(direction) ? @v.length_jm : -@v.length_jm) / @s.force_diagram.scale
    end
    def magnitude=(m)
      unless m.nil?
        @v = direction.clone
        @v.reverse! if m<0
        @v.length = m.abs
      else
        clear_v
      end
    end
    def pulling?;               magnitude.to_f>0;  end    
    alias :tension?             :pulling?
    def pushing?;               magnitude.to_f<0;  end
    alias :compression?         :pushing?
    def sign;                   magnitude.to_f<=>0;  end
    def zero?;                  magnitude.to_f==0;  end

    def fixed_magnitude;        read_attribute("fixed_magnitude").to_f;  end
    def fixed_magnitude=(m);    write_attribute("fixed_magnitude",m);  end

    def status;                 read_attribute("status");  end
    def status=(s);             write_attribute("status",s);  end
    def clear_status           
      self.status=nil 
      self.fixed_magnitude=nil
    end
    def fixed?;                 status=='fixed';  end     
    def fix                   
      self.status='fixed'
      self.fixed_magnitude=magnitude
    end
    def assumed?;               status=='assumed';  end   
    def assume;                 self.status='assumed';  end

    def reciprocal?;            (start_joint.loop.value_after(uid) == end_joint.loop[uid]);  end


    attr_accessor                   :visualization

    class Visualization 
      include ComponentInstanceWrapper

      class << self
        # assumes external visualization definitions have same bounding box as internal
        def length;                             Sandbox.active_sandbox.model.definitions['Equilib_ForceInternalVisualization'].bounds.depth;  end
        ## HACK - should be tied to bounds.width but for some reason does not work
        def diameter;                           Sandbox.active_sandbox.model.definitions['Equilib_ForceInternalVisualization'].bounds.depth;  end

        attr_accessor                           :definition_names

        attr_accessor                           :diameter_scale
        attr_accessor                           :min_diameter
        attr_accessor                           :max_diameter
        attr_accessor                           :saturation_force

        attr_accessor                           :colours

        attr_accessor                           :alphas
      end

      @definition_names                                   = {}
      @definition_names[true]                             = 'Equilib_ForceInternalVisualization'
      @definition_names[false]                            = 'Equilib_ForceExternalVisualization'
      def get_definition;                                 @c.s.model.definitions[Visualization.definition_names[@c.internal?]];  end

      @diameter_scale                                     = 0.005
      @min_diameter                                       = 0.0
      @max_diameter                                       = 10.0
      @saturation_force                                   = Visualization.max_diameter/Visualization.diameter_scale
      def get_transformation
        # pull force visualization away from joint visualization for cleaner appearance
        if @c.internal?
          jov = @c.direction.clone
          jov.length = calculate_joint_offset(@c.start_joint)
          sp = @c.start_joint.position + jov
          jov = @c.direction.clone
          jov.length = calculate_joint_offset(@c.end_joint)
          ep = c.end_joint.position - jov
          z_axis = @c.direction.clone
          location = Geom::Transformation.new(sp,z_axis)
          xy_scale = calculate_diameter/Visualization.diameter
          z_scale = (ep-sp).length_jm/Visualization.length
          scaling = Geom::Transformation.scaling(xy_scale,xy_scale,z_scale)  
        else
          xy_scale = calculate_diameter/Visualization.diameter
          z_scale = calculate_external_length/Visualization.length
          scaling = Geom::Transformation.scaling(xy_scale,xy_scale,z_scale)  
          jov = @c.direction.clone
          jov.length = calculate_joint_offset(@c.start_joint)
          sp = @c.start_joint.position + jov
          if @c.pushing?
            jov.length = z_scale
            sp = sp + jov
          end
          z_axis = @c.direction.clone
          z_axis.reverse! if @c.pushing?
          location = Geom::Transformation.new(sp,z_axis)
        end
        location*scaling
      end
      def calculate_joint_offset(j);                      j.visualization.diameter/1.33;  end      
      def calculate_diameter;                             [Visualization.min_diameter,[Visualization.max_diameter,Visualization.diameter_scale*@c.magnitude.to_f.abs].min].max;  end
      def calculate_external_length;                      calculate_diameter*3;  end

      # need to differentiate colours by status so alphas render properly
      @colours                                            = {}
      @colours[true]                                      = {}
      @colours[true]['fixed']                             = {-1=>Sketchup::Color.new(255,254,0), 0=>Sketchup::Color.new(254,255,0), +1=>Sketchup::Color.new(254,254,0)}
      @colours[true]['assumed']                           = {-1=>Sketchup::Color.new(253,253,0), 0=>Sketchup::Color.new(253,254,0), +1=>Sketchup::Color.new(254,253,0)}
      @colours[true].default                              = {-1=>Sketchup::Color.new(253,255,0), 0=>Sketchup::Color.new(255,253,0), +1=>Sketchup::Color.new(252,253,0)}
      @colours[false]                                     = {}
      @colours[false]['fixed']                            = {-1=>Sketchup::Color.new(0,103,255), 0=>Sketchup::Color.new(205,205,205), +1=>Sketchup::Color.new(255,0,52)}
      @colours[false]['assumed']                          = {-1=>Sketchup::Color.new(0,101,255), 0=>Sketchup::Color.new(203,203,203), +1=>Sketchup::Color.new(255,0,50)}
      @colours[false].default                             = {-1=>Sketchup::Color.new(0,102,255), 0=>Sketchup::Color.new(204,204,204), +1=>Sketchup::Color.new(255,0,51)}
      def get_material;                                   Visualization.colours[highlighted?][@c.status][@c.sign];  end

      @alphas                                             = {'fixed'=>1.0, 'assumed'=>0.25}
      @alphas.default                                     = 0.5
      def get_alpha;                                      Visualization.alphas[@c.status];  end

      def get_name_root;                                  "#{@c.name} Visualization";  end

      def diameter;                                       carefully { @ci.bounds.height };  end
    end


    attr_accessor                              :vector

    class Vector 
      include ComponentInstanceWrapper

      class << self
        def length;               Sandbox.active_sandbox.model.definitions['Equilib_ForceVector'].bounds.depth;  end
      end

      def line_of_action;         carefully { [@ci.transformation.origin, @ci.transformation.zaxis] };  end

      def get_definition;         @c.s.model.definitions['Equilib_ForceVector'];  end
      def get_transformation
        v = @c.v
        location = Geom::Transformation.new(@c.start_joint.loop[@c.uid],v)
        z_scale = v.length_jm / Vector.length
        scaling = Geom::Transformation.scaling(1,1,z_scale)
        location*scaling
      end
      def get_name_root;                                  "#{@c.name} Vector";  end
    end


    attr_accessor                               :duplicate_vector

    class DuplicateVector < Vector
      class << self
        def length;               Sandbox.active_sandbox.model.definitions['Equilib_ForceDuplicateVector'].bounds.depth;  end
      end

      def get_definition;         @c.s.model.definitions['Equilib_ForceDuplicateVector'];  end
      def get_transformation
        v = @c.v
        location = Geom::Transformation.new(@c.end_joint.loop.value_after(@c.uid),@c.get_v_at(@c.end_joint))
        z_scale = v.length_jm/Vector.length
        scaling = Geom::Transformation.scaling(1,1,z_scale)
        location*scaling
      end
      def get_name_root;                                  "#{@c.name} Vector (Duplicate)";  end
    end


    def inspect;          "#{super}#{self.v}";  end

  end
end