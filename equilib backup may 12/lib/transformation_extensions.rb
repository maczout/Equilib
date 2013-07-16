### transformation.extensions.rb (c) TIG 2009-2011
### From original ideas by TBD and others ? ### TIG 20091010
### The euler rotation ideas from Dave Burdick 20100324
### It extends the methods for Geom::Transformation...
### The built-in method "object.transformation.origin" return a point3d 
###   that is the object's origin/insertion: the new method 
###   object.transformation.getX etc returns the X location of the  
###   object [or Y or Z].
### The setX(x) resets the X value of the object [or Y or Z]: it 
###   returns a new transformation that can then be used to reset the 
###   original transformation; thus:
###   object.transformation=object.transformation.setX(another_object.transformation.getX)
###   - here it makes the object's X = another_object's X ; 
###     it also could be given a float, e.g. 12.345 or a 'variable'...
### The object.transformation.scaleX etc returns the scale on that axis.
### The object.transformation.rotX etc returns the rotation on that axis
###   in radians: use ... .rotX.radians to get it in degrees...
### It uses different names to TBD's, e.g. 'rotZ' instead of 'zrot' etc.
### Note the capitalization... this is because some 'compiled scripts' 
### use 'rotz' already etc - [and they return the rotation in degrees!]
### object.transformation.rotXYZ
###   returns a 3 item array giving the rotations in x/y/z
### object.transformation.rot_a
###   returns an 11 item array of the transformation's rotation/scaling 
###   - it can be used to extract some data more easily or as below...
### object.transformation=object.transformation.rotation_from_rot_a(another_object.transformation.rot_a) 
###   this applies another_object's 'rot_a' to change the object.
### object.transformation=object.transformation.rotation_from(another_object.transformation) 
###   this applies another_object's rotation/scaling to the object.
###   it returns a new transformation that can then be used to reset the original...
### object.transformation=object.transformation.origin_from(another_object.transformation) 
###   this applies another_object's origin/location to the object.
###   it returns a new transformation that can then be used to reset the original...
### object.transformation=object.transformation.rotation_from_xyz([xrot,yrot,zrot])
###   this applies a 3 item array of x/y/z rotations about the model's x/y/z-axes, 
###   this could also be the array returned by rotXYZ.
###   it returns a new transformation that can then be used to reset the original...
### object.transformation=object.transformation.rotation_from_xyz_locally([xrot,yrot,zrot])
###   this applies a 3 item array of x/y/z rotations about the objects's x/y/z-axes, 
###   this could also be the array returned by rotXYZ.
###   it returns a new transformation that can then be used to reset the original...
###
### updated 20110209 TIG
###
class Geom::Transformation
  def euler_angle(xyz=[])
       m = self.xaxis.to_a + self.yaxis.to_a + self.zaxis.to_a
       if m[6] != 1 and m[6]!= 1
          ry = -Math.asin(m[6])
          rx = Math.atan2(m[7]/Math.cos(ry),m[8]/Math.cos(ry))
          rz = Math.atan2(m[3]/Math.cos(ry),m[0]/Math.cos(ry))
       else
          rz = 0
          phi = Math.atan2(m[1],m[2])
          if m[6] == -1
             ry = Math::PI/2
             rx = rz + phi
          else
             ry = -Math::PI/2
             rx = -rz + phi
          end
       end   
       return -rx if xyz==0
       return -ry if xyz==1
       return -rz if xyz==2
       return [-rx,-ry,-rz] if xyz==[]
  end
  def getX
    self.to_a[12]
  end
  def getY
    self.to_a[13]
  end
  def getZ
    self.to_a[14]
  end
  def setX(x)
    if not x.class==Float and not x.class==Integer
      puts "Transformation::setX( ) expects a Float or Integer."
      return nil
    end#if
    x=x.to_f
    t=self.to_a
    t[12]=x
    return self.set!(t)
  end
  def setY(y)
    if not y.class==Float and not y.class==Integer
      puts "Transformation::setY( ) expects a Float or Integer."
      return nil
    end#if
    y=y.to_f
    t=self.to_a
    t[13]=y
    return self.set!(t)
  end
  def setZ(z)
    if not z.class==Float and not z.class==Integer
      puts "Transformation::setZ( ) expects a Float or Integer."
      return nil
    end#if
    z=z.to_f
    t=self.to_a
    t[14]=z
    return self.set!(t)
  end
  def scaleX
    Math.sqrt(self.to_a[0]**2+self.to_a[1]**2+self.to_a[2]**2)
  end
  def scaleY
    Math.sqrt(self.to_a[4]**2+self.to_a[5]**2+self.to_a[6]**2)
  end
  def scaleZ
    Math.sqrt(self.to_a[8]**2+self.to_a[9]**2+self.to_a[10]**2)
  end
  def rotX
    #(Math.atan2(self.to_a[9],self.to_a[10]))
     #Math.acos(self.to_a[5])
     euler_angle(0)
  end
  def rotY
    #(Math.arcsin(self.to_a[8]))
    #Math.acos(self.to_a[0])
    euler_angle(1)
  end
  def rotZ
    #(-Math.atan2(self.to_a[4],self.to_a[0]))
    #Math.asin(self.to_a[4])
    euler_angle(2)
  end
  def rotXYZ
    euler_angle
  end
  def rot_a ### rotation matrix 4x3 3 and 7 are nil
    t=self.to_a
    r=[]
    [0,1,2,3,4,5,6,7,8,9,10].each{|i|r[i]=t[i]}
    r[3]=nil
    r[7]=nil
    return r
  end
  def rotation_from_xyz(xyz)
    if not xyz.class==Array and not xyz[2] and not xyz[0].class==Float and not xyz[1].class==Float and not xyz[2].class==Float
      puts "Transformation::rotation_from_xyz( ) expects a 3 Item Array of Angles [as Floats]."
      return nil
    end#if
    tx=Geom::Transformation.rotation(self.origin,X_AXIS,xyz[0])
    ty=Geom::Transformation.rotation(self.origin,Y_AXIS,xyz[1])
    tz=Geom::Transformation.rotation(self.origin,Z_AXIS,xyz[2])
    t=(tx*ty*tz)
    return self.set!(t)
  end
  def rotation_from_xyz_locally(xyz)
    if not xyz.class==Array and not xyz[2] and not xyz[0].class==Float and not xyz[1].class==Float and not xyz[2].class==Float
      puts "Transformation::rotation_from_xyz_locally( ) expects a 3 Item Array of Angles [as Floats]."
      return nil
    end#if
    tx=Geom::Transformation.rotation(self.origin,self.xaxis,xyz[0])
    ty=Geom::Transformation.rotation(self.origin,self.yaxis,xyz[1])
    tz=Geom::Transformation.rotation(self.origin,self.zaxis,xyz[2])
    t=(tx*ty*tz)
    return self.set!(t)
  end
  def rotation_from_rot_a(rot_a)
    if not rot_a.class==Array and not rot_a[10]
      puts "Transformation::rotation_from_rot_a( ) expects an 11 Item Array."
      return nil
    end#if
    t=self.to_a
    [0,1,2,4,5,6,8,9,10].each{|i|t[i]=rot_a[i].to_f}
    return self.set!(t)
  end
  def rotation_from(trans)
    if not trans.class==Geom::Transformation
      puts "Transformation::rotation_from( ) expects a Sketchup::Transformation."
      return nil
    end#if
    t=self.to_a
    tt=trans.to_a
    [0,1,2,4,5,6,8,9,10].each{|i|t[i]=tt[i].to_f}
    return self.set!(t)
  end
  def origin_from(trans)
    if not trans.class==Geom::Transformation
      puts "Transformation::origin_from( ) expects a Sketchup::Transformation."
      return nil
    end#if
    t=self.to_a
    tt=trans.to_a
    [12,13,14].each{|i|t[i]=tt[i].to_f}
    return self.set!(t)
  end
end#class
###
