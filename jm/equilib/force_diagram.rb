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
      sc=read_attribute("scale").to_f
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
      def primary_plane;                            carefully { @ci.transformation.yaxis };  end        
      def secondary_plane;                          carefully { @ci.transformation.xaxis };  end

      def force_uid;                                read_attribute("force_uid");  end
      def force_uid=(u);                            write_attribute("force_uid",u);  end
      def force;                                    @c.s.components_map[JM::Equilib::Force][force_uid];  end
    end

    def clear
      @s.components_map[JM::Equilib::Force].each_value { |f| f.v=nil unless f.fixed? }
      @s.components_map[JM::Equilib::Joint].each_value { |j| j.loop.clear }
    end

    def rebuild
      return if @s.empty? 
      Debug.log "Begin rebuild force diagram #{Time.now}"
      clear
      traverse_joints_and_solve_forces(@s,components_map[JM::Equilib::Joint].values) 
      if visible?
        build_loop(anchor_force.start_joint_uid,anchor_force,origin)  
        traverse_joints_and_build_loops(anchor_force.start_joint_uid)
      end
      Debug.log "End rebuild force diagram #{Time.now}"
      Debug.log ""
    end

    def traverse_joints_and_solve_forces(unsolved_joints)
      Debug.log "ForceDiagram.solve_joints called with #{unsolved_joints.length} unsolved joints"
      unsolved_joints.each { |u,j| solve_forces j }
      next_unsolved_joints = unsolved_joints.reject { |u,j| j.solved? }
      if (next_unsolved_joints.length>0) and (next_unsolved_joints.length<unsolved_joints.length)  # brute force recursion
        Debug.log "ForceDiagram.solve_joints recursing with #{next_unsolved_joints.length} unsolved joints"
        return traverse_joints_and_solve_forces(next_unsolved_joints) 
      elsif (next_unsolved_joints.length>0) and (unsolved_joints.length==next_unsolved_joints.length)
        Debug.log "ForceDiagram.solve_joints finished with #{next_unsolved_joints.length} unsolved joints"
        self.status = UNSOLVED
        return
      else
        Debug.log "ForceDiagram.solve_joints successfully completed"
        self.status = SOLVED
        return true
      end
    end

    def solve_forces(j)
      uf = j.get_unknown_forces.values
      num_uf = uf.size
      num_kf = j.get_known_forces.length
      r = j.get_resultant

      if num_uf == 0
        if (r != [0,0,0])  # fail
          Debug.log "#{name} overconstrained: sum forces at joint !=0 r==#{r}"
          self.status = OVERCONSTRAINED
          return nil
        end
        # nothing to do
        Debug.log "#{name} solved: num_uf==0 r==#{r}"
        j.clear_status
        return true 

      elsif num_uf == 1
        if num_kf == 0
          Debug.log "#{name} underconstrained: 1 unknown vector but no known vector"
          j.status = UNDERCONSTRAINED
          return nil          
        end
        if (r != [0,0,0]) and !(uf[0].direction.parallel? r)  
          Debug.log "#{name} overconstrained: 1 unknown vector not collinear with resultant"
          j.status = OVERCONSTRAINED
          return nil
        end
        # solution trivial
        uf[0].set_v_at(j, r.reverse) 
        Debug.log "#{name} solved: num_uf==1 r==#{r} uf[0]==#{uf[0].get_v_at(j)}"
        self.clear_status
        return true  # success

      elsif num_uf == 2
        if (r == [0,0,0])
          Debug.log "#{name} underconstrained: 2 unknown vectors but no resultant"
          j.status = UNDERCONSTRAINED
          return nil         
        end
        if (uf[0].direction.parallel? uf[1].direction) 
          Debug.log "#{name} overconstrained: 2 unknown vectors not linearly independent"
          j.status = OVERCONSTRAINED
          return nil
        end
        if (uf[0].direction.cross(uf[1].direction).dot(r).abs > 1E-12) # "!=0"
          Debug.log "#{name} overconstrained: 2 unknown vectors not coplanar with resultant"
          j.status = OVERCONSTRAINED
          return nil
        end
        # linear system has unique solution   
        start_point = [0,0,0]
        end_point = r.to_a 
        int_point = Geom.intersect_line_line([end_point, uf[0].direction], [start_point, uf[1].direction])
        uf[0].set_v_at(j, end_point.vector_to(int_point))
        uf[1].set_v_at(j, int_point.vector_to(start_point))
        Debug.log "#{name} solved: num_uf==2 r==#{r} uf[0]==#{uf[0].vector.get_v_at(j)} uf[1]==#{uf[1].vector.get_v_at(j)}"
        j.clear_status
        return true  # success

      elsif num_uf == 3
        if (r == [0,0,0])
          Debug.log "#{name} underconstrained: 3 unknown vectors but no resultant"
          j.status = UNDERCONSTRAINED
          return nil         
        end
        if (uf[0].direction.cross(uf[1].direction).dot(uf[2].direction).abs < 1E-12)  # "==0"
          Debug.log "#{name} overconstrained: 3 unknown not linearly independent"
          j.status = OVERCONSTRAINED
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
        Debug.log "#{name} solved: num_uf==3 r==#{r} uf[0]==#{uf[0].get_v_at(j)} uf[1]==#{uf[1].get_v_at(j)} uf[2]==#{uf[2].get_v_at(j)}"
        j.clear_status
        return true  # success
      end
      Debug.log "#{name} underconstrained"
      j.status = UNDERCONSTRAINED # try again later
      return nil
    end

    def build_loop(joint,anchor_force,origin)
      # Assumes @scale matches @s.force_diagram_scale
      Debug.log "Build #{joint.name}"
      sorted_forces = joint.forces.values.sort do |f1,f2|
        # Need to arrange forces properly to get correct configuration of Cremona Diagram
        test = f1.angle(primary_plane,joint) <=> f2.angle(primary_plane,joint)  
        test = f1.angle(secondary_plane,joint) <=> f2.angle(secondary_plane,joint) if test==0.0
        test
      end
      anchor_force_index = sorted_forces.index(anchor_force)
      (0..sorted_forces.length-1).each do |i|
        f = sorted_forces[(i+anchor_force_index)%sorted_forces.length]
        joint.loop[f.uid] = next_vertex
        v = f.get_v_at(joint)
        v.x *= @scale; v.y *= @scale; v.z *= @scale   # hopefully faster than mucking around with a transformation
        next_vertex = next_vertex + v
      end
    end
    private :build_loop

    def traverse_and_build_loops(from_joint)
      Debug.log "Traverse from #{from_joint.name}"
      @scale = @s.force_diagram_scale
      from_loop = from_joint.loop
      from_joint.loop.each_key do |f|
        if f.internal?
          if f.start_joint == from_joint
            j = f.end_joint
            p = from_loop.value_after(f)
          else
            j = f.start_joint
            p = from_loop[f]
          end
          unless j.loop.complete?
            build_loop(j,f,p)
            traverse_and_build_loops(j)
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
        j.loop.each_key do |f|
          if @s.show_force_diagram?
            f.vector.refresh
            f.dup_vector.refresh unless f.reciprocal?
          else
            f.vector.hide if f.vector.visible?
            f.dup_vector.hide if f.dup_vector.visible?
          end
        end
      end      
    end

  end

end