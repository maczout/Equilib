=begin
force_diagram.rb
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

  class ForceDiagram

    def initialize(s)
      @s=s
      @anchor = Anchor.new(self,nil)
      @s.components_map[JM::Equilib::ForceDiagram] = @anchor
    end

    attr_reader :s

    def scale
      sc=@anchor.read_attribute("scale").to_f
      sc=1.0 if sc==0
      sc
    end
    def scale=(f);                  @anchor.write_attribute("scale",f) unless @anchor.nil?;  end

    attr_accessor :anchor

    class Anchor
      include ComponentInstanceWrapper

      def get_ci
        trans = Geom::Transformation.new(Geom::Point3d.new(0,0,0))  # default position at origin
        ci = @c.s.entities.add_instance(get_definition, trans)
        ci.set_attribute("Equilib","uid",ComponentInstanceWrapper.create_uid)
        ci.name = ComponentInstanceWrapper.create_name(@c.s.entities,"Force Diagram Anchor")
        ci
      end

      def get_definition;                           @c.s.model.definitions['Equilib_ForceDiagramAnchor'];  end
      def get_transformation
        # preserve rotation but eliminate scaling
        tr = carefully { @ci.transformation }
        Geom::Transformation.new(tr.xaxis,tr.yaxis,tr.zaxis,tr.origin)
      end

      def position;                                 carefully { @ci.transformation.origin };  end
      def force_uid                                
        u = read_attribute("force_uid")
        u = @c.s.components_map[JM::Equilib::Force].keys[0] if u.nil?
        u
      end
      def force_uid=(u);                            write_attribute("force_uid",u);  end
      def force;                                    @c.s.components_map[JM::Equilib::Force][force_uid];  end
    end

    def clear
      @s.components_map[JM::Equilib::Force].each_value { |f| f.clear_v unless f.fixed? }
      @s.components_map[JM::Equilib::Joint].each_value { |j| j.loop.clear }
    end

    def rebuild
      return if @s.empty? 
      Debug.log "Begin rebuild force diagram #{Time.now}"
      clear
      traverse_joints_and_solve_forces(@s.components_map[JM::Equilib::Joint].values) 
      if @anchor.visible? && @s.status == 'solved' && @s.components_map[JM::Equilib::Force].length>0
        build_loop(@anchor.force.start_joint,@anchor.force,@anchor.position)  
        traverse_joints_and_build_loops(@anchor.force.start_joint)
      end
      Debug.log "End rebuild force diagram #{Time.now}"
      Debug.log ""
    end

    def traverse_joints_and_solve_forces(unsolved_joints)
      Debug.log "ForceDiagram.solve_joints called with #{unsolved_joints.length} unsolved joints"
      unsolved_joints.each { |j| solve_forces j }
      next_unsolved_joints = unsolved_joints.reject { |j| j.solved? }
      if (next_unsolved_joints.length>0) and (next_unsolved_joints.length<unsolved_joints.length)  # brute force recursion
        Debug.log "ForceDiagram.solve_joints recursing with #{next_unsolved_joints.length} unsolved joints"
        return traverse_joints_and_solve_forces(next_unsolved_joints) 
      elsif (next_unsolved_joints.length>0) and (unsolved_joints.length==next_unsolved_joints.length)
        Debug.log "ForceDiagram.solve_joints finished with #{next_unsolved_joints.length} unsolved joints"
        Debug.log ""
        @s.status = 'unsolved'
        return
      else
        Debug.log "ForceDiagram.solve_joints successfully completed"
        Debug.log ""
        @s.status = 'solved'
        return true
      end
    end

    def solve_forces(j)
      uf = j.get_unknown_forces
      num_uf = uf.size
      num_kf = j.get_known_forces.length
      r = j.get_resultant

      if num_uf == 0
        if (r != [0,0,0])  # fail
          Debug.log "#{j.name} overconstrained: sum forces at joint !=0 r==#{r}"
          j.status = 'overconstrained'
          return nil
        end
        # nothing to do
        Debug.log "#{j.name} solved: num_uf==0 r==#{r}"
        j.status = 'solved'
        return true 

      elsif num_uf == 1
        if num_kf == 0
          Debug.log "#{j.name} underconstrained: 1 unknown vector but no known vector"
          j.status = 'underconstrained'
          return nil          
        end
        if (r != [0,0,0]) and !(uf[0].direction.parallel? r)  
          Debug.log "#{j.name} overconstrained: 1 unknown vector not collinear with resultant"
          j.status = 'overconstrained'
          return nil
        end
        # solution trivial
        uf[0].set_v_at(j, r.reverse) 
        Debug.log "#{j.name} solved: num_uf==1 r==#{r} uf[0]==#{uf[0].get_v_at(j)}"
        j.status = 'solved'
        return true  # success

      elsif num_uf == 2
        if (r == [0,0,0])
          Debug.log "#{j.name} underconstrained: 2 unknown vectors but no resultant"
          j.status = 'underconstrained'
          return nil         
        end
        if (uf[0].direction.parallel? uf[1].direction) 
          Debug.log "#{j.name} overconstrained: 2 unknown vectors not linearly independent"
          j.status = 'overconstrained'
          return nil
        end
        if (uf[0].direction.cross(uf[1].direction).dot(r).abs > 1E-12) # "!=0"
          Debug.log "#{j.name} overconstrained: 2 unknown vectors not coplanar with resultant"
          j.status = 'overconstrained'
          return nil
        end
        # linear system has unique solution   
        start_point = [0,0,0]
        end_point = r.to_a 
        int_point = Geom.intersect_line_line([end_point, uf[0].direction], [start_point, uf[1].direction])
        uf[0].set_v_at(j, end_point.vector_to(int_point))
        uf[1].set_v_at(j, int_point.vector_to(start_point))
        Debug.log "#{j.name} solved: num_uf==2 r==#{r} uf[0]==#{uf[0].get_v_at(j)} uf[1]==#{uf[1].get_v_at(j)}"
        j.status = 'solved'
        return true  # success

      elsif num_uf == 3
        if (r == [0,0,0])
          Debug.log "#{j.name} underconstrained: 3 unknown vectors but no resultant"
          j.status = 'underconstrained'
          return nil         
        end
        if (uf[0].direction.cross(uf[1].direction).dot(uf[2].direction).abs < 1E-12)  # "==0"
          Debug.log "#{j.name} overconstrained: 3 unknown not linearly independent"
          j.status = 'overconstrained'
          return nil
        end
        # linear system has unique solution
        start_point = [0,0,0]
        end_point = r.to_a
        int_point_1 = Geom.intersect_line_plane([end_point, uf[0].direction], [start_point, uf[1].direction.cross(uf[2].direction)])
        int_point_2 = Geom.intersect_line_line([int_point_1, uf[1].direction], [start_point, uf[2].direction])
        uf[0].set_v_at(j, end_point.vector_to(int_point_1))
        uf[1].set_v_at(j, int_point_1.vector_to(int_point_2))
        uf[2].set_v_at(j, int_point_2.vector_to(start_point))
        Debug.log "#{j.name} solved: num_uf==3 r==#{r} uf[0]==#{uf[0].get_v_at(j)} uf[1]==#{uf[1].get_v_at(j)} uf[2]==#{uf[2].get_v_at(j)}"
        j.status = 'solved'
        return true  # success
      end
      Debug.log "#{j.name} underconstrained"
      j.status = 'underconstrained' # try again later
      return nil
    end

    
    def build_loop(joint,anchor_force,next_vertex)
      # Assumes @scale matches @s.force_diagram_scale
      sorted_forces = joint.get_forces.sort do |f1,f2|
        # Arrange forces in Cremona configuration
        test = f1.get_angle(@anchor.ci.transformation,JM::Equilib::Force::XZ_PLANE,joint) <=> f2.get_angle(@anchor.ci.transformation,JM::Equilib::Force::XZ_PLANE,joint) 
        if test==0.0
          test = f1.get_angle(@anchor.ci.transformation,JM::Equilib::Force::YZ_PLANE,joint) <=> f2.get_angle(@anchor.ci.transformation,JM::Equilib::Force::YZ_PLANE,joint) #if test==0.0
        end
        test
      end
      anchor_force_index = sorted_forces.index(anchor_force)
      (0..sorted_forces.length-1).each do |i|
        f = sorted_forces[(i+anchor_force_index)%sorted_forces.length]
        #Debug.log f.inspect
        joint.loop[f.uid] = next_vertex
        v = f.get_v_at(joint)
        sc = scale
        v.x *= sc; v.y *= sc; v.z *= sc   # hopefully faster than mucking around with a transformation
        next_vertex = next_vertex + v
      end
      Debug.log "#{joint.inspect}"
    end
    private :build_loop

    def traverse_joints_and_build_loops(from_joint)
      sc = scale
      from_loop = from_joint.loop
      from_joint.loop.each_key do |f_uid|
        f = @s.components_map[JM::Equilib::Force][f_uid]
        if f.internal?
          if f.start_joint == from_joint
            j = f.end_joint
            p = from_loop.value_after(f_uid)
          else
            j = f.start_joint
            p = from_loop.value_after(f_uid)  # value before?
          end
          unless j.loop.complete?
            build_loop(j,f,p)
            traverse_joints_and_build_loops(j)
          end
        end
      end
    end

    def refresh
      if @s.show_force_diagram?
        @anchor.refresh
      else
        @anchor.hide if @anchor.visible?
      end
      @s.components_map[JM::Equilib::Joint].each_value do |j|
        j.loop.each_key do |f_uid|
          f = @s.components_map[JM::Equilib::Force][f_uid]
          if @s.show_force_diagram?
            f.vector.refresh
            f.duplicate_vector.refresh unless f.reciprocal?
          else
            f.vector.hide if f.vector.visible?
            f.duplicate_vector.hide if f.duplicate_vector.visible?
          end
        end
      end      
    end

    def loop_summary
      puts "Loop summary"
      @s.joints_map.each_value do |j|
        j.loop.each_value do |p|
          puts "#{p.x},#{p.y},#{p.z}"
        end
      end
    end
  end

end