=begin
sandbox.rb
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

  class Sandbox

    class << self
      attr_accessor :active_sandbox

      @definition_names_map = {}
      @definition_names_map['Equilib_Force'] = JM::Equilib::Force
      @definition_names_map['Equilib_ForceInternalVisualization'] = JM::Equilib::Force::Visualization
      @definition_names_map['Equilib_ForceExternalPushVisualization'] = JM::Equilib::Force::Visualization
      @definition_names_map['Equilib_ForceExternalPushVisualization'] = JM::Equilib::Force::Visualization
      @definition_names_map['Equilib_ForceExternalPullVisualization'] = JM::Equilib::Force::Visualization
      @definition_names_map['Equilib_ForceVector'] = JM::Equilib::Force::Vector
      @definition_names_map['Equilib_ForceDuplicateVector'] = JM::Equilib::Force::DuplicateVector
      @definition_names_map['Equilib_Joint'] = JM::Equilib::Joint
      @definition_names_map['Equilib_JointVisualization'] = JM::Equilib::Joint::Visualization
      @definition_names_map['Equilib_ForceDiagramAnchor'] = JM::Equilib::ForceDiagram::Anchor
      attr_reader :definition_name_map
    end

    def initialize(e)
      @entities = e
      @components_map = {}
      @components_map[JM::Equilib::Force] = {}
      @components_map[JM::Equilib::Joint] = {}
      
      @body = Body.new(self)
      @form_diagram = FormDiagram.new(self)
      @force_diagram = ForceDiagram.new(self)
      
      self.refresh_automatically = true if read_attribute("refresh_automatically").nil?
      self.visualize_forces = true if read_attribute("visualize_forces").nil?
      self.show_force_diagram = true if read_attribute("show_force_diagram").nil?
    end

    attr_reader   :entities

    def model;    @entities.model;  end
    def parent;   @entities.parent;  end

    def name;     @entities.parent.name;  end
    def name=(n); @entities.parent.name=n;  end

    def read_attribute(key)
      a = parent.get_attribute(:Equilib.to_s,key,nil)
      a != "" ? a : nil
    end
    def write_attribute(key,value)
      value = "" if value.nil?
      parent.set_attribute(:Equilib.to_s,key,value.to_s)
    end

    def refresh_automatically?;         read_attribute("refresh_automatically").to_b_jm;  end
    def refresh_automatically=(b);      write_attribute("refresh_automatically",b);  end

    def visualize_forces?;              read_attribute("visualize_forces").to_b_jm;  end
    def visualize_forces=(b);           write_attribute("visualize_forces",b);  end

    def show_force_diagram?;            read_attribute("show_force_diagram").to_b_jm;  end
    def show_force_diagram=(b);         write_attribute("show_force_diagram",b);  end

    attr_reader :body

    attr_reader :form_diagram
    attr_reader :force_diagram

    def refresh
      # Refresh updates visual representation of data structure
      @form_diagram.refresh
      @force_diagram.refresh
    end

    def rebuild(force_solve=false)
      # Rebuild updates data structure
      rebuild_components_map
      @form_diagram.rebuild
      @force_diagram.rebuild if (refresh_automatically? || force_solve)
    end 

    attr_reader           :components_map
    def joints_map;       @components_map[JM::Equilib::Joint];  end
    def forces_map;       @components_map[JM::Equilib::Force];  end
    def empty?;           @components_map[JM::Equilib::Joint].empty?;  end

    def rebuild_components_map
      # Sketchup tends to "pull the rug" from under the diagram by changing Entity 
      # objects on the fly, which breaks the linkages between Sketchup and Equilib.
      # User can also inadvertently delete entities or add extraneous entities that
      # Equilib doesn't know how to handle.
      # Rebuilding the the components map ensures that Equilib can reliably analyze
      # and manipulate the Sketchup environment.

      @components_map.clear

      em = get_entities_map
      em[JM::Equilib::Force].each do |uid,ci_loa|
        @components_map[JM::Equilib::Force][uid] = Force.load(self,ci_loa,em[JM::Equilib::Force::Visualization][uid],em[JM::Equilib::Force::Vector][uid],em[Force::DuplicateVector][uid])
      end
      em[JM::Equilib::Force::Visualization].each do |uid,ci_vis|
        # rescue
        @components_map[JM::Equilib::Force][uid] = Force.load(self,nil,ci_vis,em[JM::Equilib::Force::Vector][uid],em[JM::Equilib::Force::DuplicateVector][uid]) unless @components_map[JM::Equilib::Force].has_key? uid
      end
      em[JM::Equilib::Force::Vector].each do |uid,ci_vec|
        # can't rescue - delete
        @entities.erase_entities ci_vec unless @components_map.has_key? uid
      end
      em[JM::Equilib::Force::DuplicateVector].each do |uid,ci_vec_dup|
        # can't rescue - delete
        @entities.erase_entities ci_vec_dup unless @components_map.has_key? uid
      end

      em[JM::Equilib::Joint].each do |uid,ci_n|
        @components_map[JM::Equilib::Joint][uid] = Joint.load(self,ci_n,em[JM::Equilib::Joint::Visualization][uid])
      end
      em[JM::Equilib::Joint::Visualization].each do |uid,ci_vis|
        # rescue
        @components_map[JM::Equilib::Joint][uid] = Joint.load(self,nil,ci_vis) unless @components_map[JM::Equilib::Joint].has_key? uid
      end
      @components_map[JM::Equilib::Joint][@body.uid] = @body

      k = em[JM::Equilib::ForceDiagram::Anchor].keys[0]
      ci_a = em[JM::Equilib::ForceDiagram::Anchor].delete(k)
      @force_diagram.anchor.ci = ci_a
      @components_map[JM::Equilib::ForceDiagram][k] = @force_diagram.anchor
      em[JM::Equilib::ForceDiagram::Anchor].each_value do |ci_a|
        # only need one anchor - delete
        @entities.erase_entities ci_a
      end
    end

    def get_entities_map
      em = Hash.new {|h,k| h[k]=Hash.new(&h.default_proc) }
      @entities.each do |e|
        uid = ComponentInstanceWrapper.get_uid(e)
        em[Sandbox.definition_name_map[e.definition.name]][uid] = e if uid
      end
      em
    end
    private :get_entities_map


    def add_joint(pos)
      j = Joint.create(self,pos)
      self.components_map[JM::Equilib::Joint][j.uid] = j
      j
    end
    def remove_joint(j)
      j.forces.each { |f| remove_force(f) }
      j.erase
      j.visualization.erase if j.visualization.ci
      @components_map[JM::Equilib::Joint].delete(j.uid)
    end

    def add_internal_force(sj,ej)
      f = Force.create(self,sj,ej)
      self.components_map[JM::Equilib::Force][f.uid] = f
      f
    end   
    def add_external_force(sj,direct)
      f = add_internal_force(sj,@body)
      f.end_joint.position = sp+direct
      f
    end
    def remove_force(f)
      f.erase
      f.visualization.erase if f.visualization.ci
      f.vector.erase if f.vector.ci
      @components_map[JM::Equilib::Force].delete(f.uid)
    end


    def to_s
      i = ""
      to_csv {|l| i = i + l + "\n"}
      i
    end

    def to_csv
      yield "Equilib Summary v0.9 (c) 2013 Jamie McIntyre"
      yield ""
      yield "Nodes"
      yield "name,x,y,z,status"
      @joints_map.each do |k,n|
        yield "#{n.name},#{n.position.x.to_f},#{n.position.y.to_f},#{n.position.z.to_f},#{n.status}"
      end
      yield ""
      yield "Internal Forces"
      yield "name,start_joint,end_joint,magnitude,status"
      internal_forces=@forces_map.values.select { |f| f.is_a? InternalForce }
      internal_forces.each do |intf|
        yield "#{intf.name},#{intf.start_joint.name},#{intf.end_joint.name},#{intf.magnitude},#{intf.status}"
      end
      yield ""
      yield "External Forces"
      yield "name,start_joint,direction_x,direction_y,direction_z,magnitude,status"
      external_forces=@forces_map.values.select { |f| f.is_a? ExternalForce }
      external_forces.each do |extf|
        dir = extf.direction
        yield "#{extf.name},#{extf.start_joint.name},#{dir.x.to_f},#{dir.y.to_f},#{dir.z.to_f},#{extf.magnitude},#{extf.status}"
      end
    end

  end
  
end