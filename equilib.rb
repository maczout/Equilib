=begin
equilib.rb
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

# Run within SketchUp as an extension
require 'extensions.rb'
ext = SketchupExtension.new 'Equilib', 'jm/equilib/loader.rb'
ext.creator     = 'Jamie McInyre'
ext.version     = '0.5'
ext.copyright   = '2013'
ext.description = 'Equilib is a plugin for doing graphic statics in SketchUp.  
More information: http://www.graphicstatics.net/'
Sketchup.register_extension ext, true

