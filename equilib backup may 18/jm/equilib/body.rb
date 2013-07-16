=begin
body.rb
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

  class Body < Joint
    def initialize(s)
      @s=s
      @loop = Loop.new
      @ci = nil
      @node = nil
      @visualization = nil
    end
    
    def c;                      @s;  end
    def uid;                    "Body";  end
    
    def name;                   "Body";  end
    def name=(n);               raise "Can't set name of Body"; end

    def get_definition;         nil;  end
    def get_transformation;     nil;  end  

    def position;               nil;  end
    def position=(p);           raise "Can't set position of body"; end

    def status;                 @s.read_attribute("body_status");  end
    def status=(s);             @s.write_attribute("body_status",s);  end
    
    def refresh;                end  # for compatibility with ForceDiagram.refresh
    
    def plane
      points = []
      get_forces.each do |f| 
        points << f.start_joint.position
        points << f.start_joint.position + f.direction
      end
      return nil if points.length < 3
      n = (points[1]-points[0])*(points[2]-points[0])
      points.each { |p| return nil unless p.on_plane?([points[0],n]) }
      return [points[0],n]
    end
    alias :planar? :plane
    
    def unidirectional?
      forces = get_forces
      return nil if forces.length == 0
      forces.each do |f|
        return false unless f.direction.parallel? forces[0]
      end
      return true
    end
    
    
    def solve
      uf = get_unknown_forces
      num_uf = uf.size
      num_kf = get_known_forces.length
      r = get_resultant

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

    
  end

end