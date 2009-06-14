#!/usr/bin/env ruby

# A translation of Chipmunk's Moon Buggy tutorial code to ruby.

require 'enumerator'
require 'gosu'
require 'chipmunk_object'
require 'chipmunk_adjust'
require 'draw_primitives'

module MoonBuggy
  
  # This is the main Gosu window, of course. It's also going to be in charge
  # of the main Chipmunk Space, which is used to keep track of objects.
  class MainWindow < Gosu::Window
    
    # This is a helper module used to draw outlines of Shape objects in Gosu.
    include DrawPrimitives
    
    def initialize
      super(640,480,false)
      
      # Set the caption just like in the original...
      self.caption = "Press mouse button to play"
      
      # Here we create a Chipmunk space. Spaces are used to track movement and
      # collision of objects in chipmunk.
      @space = CP::Space.new
      
      # The higher you set this value, the more accurate Chipmunk's
      # calculations will be, and the more CPU cycles they will use. It's a
      # tradeoff. However, when using Chipmunk with Ruby, most of performance
      # limitations come from Ruby itself, not Chipmunk, so there's little to
      # lose in setting this fairly high.
      @space.iterations = 20
      
      # In addition to iterations, you'll want to set other properties of the
      # space such as the amount of gravity, or the amount of damping. In this
      # case, we'll just set the gravity.  
      
      # Note that gravity gets set to a CP::Vec2 object. These are Chipmunk
      # Vectors, and you'll be seeing a lot of them. This one has no x
      # component, and a y-component of -900.0, so it points straight down.
      @space.gravity = CP::Vec2.new(0.0,-900.0)
      
      # This step is optional. While you don't have to resize the spatial
      # hashes, doing so can greatly increase the speed of the collision
      # detection. The first number should be the expected average size of
      # the objects you are going to have, the second number is related to
      # the number of objects you are putting. In general, if you have more
      # objects, you want the number to be bigger, but only to a
      # point. Finding good numbers to use here is largely going to be guess
      # and check.
      @space.resize_static_hash(50.0,2000)
      @space.resize_active_hash(50.0,100)
      
      # Here I create the Terrain and Buggy objects, and add them to space.
      # You can see the individual Terrain and Buggy classes for the details
      # on those objects.
      @terrain = Terrain.new
      @space.add_object(@terrain)
      
      @buggy = Buggy.new(CP::Vec2.new(100.0,800.0))
      @space.add_object(@buggy)
      
      # This value will be the number of Chipmunk calculation steps
      # we use per Gosu update. Like iterations, the more of them you have,
      # the more accurate the simulation, and the more CPU cycles it uses.
      @substeps = 3
      
      # @dt is the amount of time between each substep.
      @dt = (1.0/60.0) / @substeps
      
    end
    
    def button_down(id)
      case id
      when Gosu::KbEscape
        close
      when Gosu::KbP
        # This resets the Buggy to it's starting position and orientation.
        @buggy.reset_p(CP::Vec2.new(100.0,800.0))
      end
    end
    
    # This is a quick method to tell if the mouse-button is being pressed, and
    # in turn whether the buggy's 'gas pedal' is down. I've factored it out
    # into a method so that if I want to make it more complex in the future 
    # (such as allowing multiple speeds), I can do so easily.
    def input_power
      self.button_down?(Gosu::MsLeft) ? 1.0 : 0.0
    end
    
    # Here we update the Buggy (see the buggy class for what happens there),
    # and then step the space, so that it can do it's various physics-y things
    # like calculating and applying forces and trajectories.
    def update
      @substeps.times do
        @buggy.update(self)
        @space.step(@dt)
      end
    end
    
    # Here, we paint a white background, draw the terrain, and draw the buggy.
    # Simple! We clip it to the inside of the view port so we don't waste time
    # drawing terrain that isn't in view.
    def draw
      self.clip_to(0,0,self.width,self.height) do
        self.draw_rect(0,0,self.width,self.height,Gosu::white)
        @terrain.draw(self)
        @buggy.draw(self)
      end
    end
    
    # These methods returns the chipmunk-space x and y coordinates that should
    # be drawn in the center of the screen. In this case, the screen will
    # always be centered on the buggy.
    def centerx
      @buggy.chassis.body.p.x
    end

    def centery 
      @buggy.chassis.body.p.y
    end
    
  end


  # This class represents our Buggy!
  class Buggy
    
    # We include CP::Object to get some nice functionality that saves us lots
    # of time. Using CP::Object means we don't need to keep a list of every
    # single Chipmunk primitive around in order to add, remove or draw related
    # primitives at the same time.
    include CP::Object
    
    attr_reader :chassis, :wheel1, :wheel2
    
    # P is for position!
    def initialize(p)
      @wheel_offset_x = 40.0
      @wheel_offset_y = 30.0
      
      # Here we create a new Chassis object, centered at p.
      @chassis = Chassis.new(p)
      
      # Now we make two Wheels, one in front of, and one behind, the chassis.
      # Note that we can add vectors together with +, unlike in C which uses
      # the cpvecadd(vec1,vec2) function.
      @wheel1  = Wheel.new(p + CP::Vec2.new(-@wheel_offset_x,-@wheel_offset_y))
      @wheel2  = Wheel.new(p + CP::Vec2.new( @wheel_offset_x,-@wheel_offset_y))
      
      # Now we create two PinJoint constraints. These each connect a wheel
      # to the Chassis. Constraints apply to CP::Body primitives, not
      # CP::Objects, so we have to make sure to use the body accessor. A pin
      # joint, incidentally, makes sure the two bodies always remain the same
      # distance from one another, but they can rotate freely.
      @joint1  = CP::Constraint::PinJoint.new(@chassis.body,@wheel1.body,CP.vzero,CP.vzero)
      @joint2  = CP::Constraint::PinJoint.new(@chassis.body,@wheel2.body,CP.vzero,CP.vzero)
      
      # Here, we construct two DampedSpring constraints to act as the buggy's
      # suspension. Again, connect two CP::Body primitives, not CP::Objects.
      # DampedSprings take a lot of parameters, so take a look at Chipmunk's
      # documentation for the details.
      @spring1 = CP::Constraint::DampedSpring.new(@chassis.body,@wheel1.body,
                                                  CP::Vec2.new(-40.0, 40.0),
                                                  CP.vzero,70.0,400.0,1.5)
      @spring2 = CP::Constraint::DampedSpring.new(@chassis.body,@wheel2.body,
                                                  CP::Vec2.new( 40.0, 40.0),
                                                  CP.vzero,70.0,400.0,1.5)
      
      # You need to call this method, supplying all of the primitives and
      # sub-objects that make up this CP::Object, in order for CP::Object to
      # work correctly.
      init_chipmunk_object(@chassis,@wheel1,@wheel2,@joint1,@joint2,@spring1,@spring2)
      
    end
    
    # This method simply moves the buggy back to it's starting position, and
    # turns it upright. Useful if you're playing around and you get flipped
    # over, or fall off the world.
    def reset_p(p)
      @chassis.body.p = p
      @wheel1.body.p = (p + CP::Vec2.new(-@wheel_offset_x,-@wheel_offset_y))
      @wheel2.body.p = (p + CP::Vec2.new( @wheel_offset_x,-@wheel_offset_y))
    end
    
    # This is the Buggy's update method.
    def update(window)
      # In Chipmunk, the forces and torques on a body are not reset
      # every step. If you keep accumulating forces on an object, it
      # will quickly explode. Comment this lines out to see what I
      # mean. On a CP::Object such as our Buggy, this method just calls
      # reset_forces on all of the CP::Body primitves it's responsible for.
      # On a CP::Body object, reset_forces simply zeros the forces and torques
      # applied to that body.
      self.reset_forces
      
      # We need to calculate how much torque to apply to the wheel. The
      # following equation roughly simulates a motor with a top speed.
      max_w = -100.0
      torque = 60000.0 * [((@wheel1.body.w - window.input_power*max_w)/max_w),1.0].min
      
      # Apply the torque to both the chassis and the wheel in opposite directions.
      @wheel1.body.t += torque
      @chassis.body.t -= torque
    end
  end
  
  # Here's our Chassis class.
  class Chassis
    # Once again we include CP::Object.
    include CP::Object
    
    attr_reader :body, :shape, :verts
    def initialize(p)
      
      # These are the vertexes that will be used to create the chassis' shape.
      # You *MUST* specify them in a conterclockwise order, and they *MUST*
      # form a convex polygon (no dents). If you need a non-convex polygon,
      # simply attach more than one shape to the body.
      @verts = [
        CP::Vec2.new(-18,-18),
        CP::Vec2.new(-18, 18),
        CP::Vec2.new( 18, 18),
        CP::Vec2.new( 18,-18)
      ]
      
      # Here's the mass. Pretty simple.
      @mass = 5.0
      
      # The moment of inertia (usually written simply as 'i') is like the
      # mass of an object, but applied to its rotation. An object with a
      # higher moment of inertia is harder to spin. Chipmunk has a couple
      # of helper functions to help you calculate these. It's a very good
      # idea to use these functions rather than guessing at the correct
      # value if you want your objects to react realistically. Note that you
      # can make an object which never spins, if you need one, by supplying
      # Float::INFINITY for the moment of inertia.
      @moment = CP.moment_for_poly(@mass,@verts,CP.vzero)
      
      #Create the rigid body for our buggy with the mass and moment of inertia
      # we calculated.
      @body = CP::Body.new(@mass,@moment)
      
      # As usual, after creating a Chipmunk primitve, you'll want to set its
      # properties. Here, we set the Chassis' position to the vector that was
      # passed into the constructor.
      @body.p = p
      
      # Now we get to make the Shape primitive which tells Chipmunk how our
      # chassis is, well, shaped. Ours is a square, a CP::Shape::Poly with the
      # vectors we made earlier.
      @shape = CP::Shape::Poly.new(@body,@verts,CP.vzero)
      
      # Like bodies, CP::Shape has some attributes you can set. Here, we set
      # the chassis's coefficient of friction, u (usually a Greek 'mu', which
      # looks rather like a u when lowercase).
      @shape.u = 0.5
      
      # Once again we initialize our CP::Object, this time using Chipmunk
      # primitives instead of composite objects.
      init_chipmunk_object(@body,@shape)
    end
  end
  
  # Here's the wheel class.
  class Wheel
    include CP::Object
    
    attr_reader :body, :shape
    def initialize(p)
      
      # Here we define the values we need to make a wheel. Since a wheel
      # is a circle instead of a polygon, we need a radius, rather than
      # an array of vectors.
      @radius = 15.0
      @mass = 1.0
      @moment = CP.moment_for_circle(@mass,@radius,0.0,CP.vzero)
      
      # As in the case of the chassis, we create the CP::Body component,
      # set its position, create the CP::Shape component (now a circle),
      # and set its coefficient of friction.
      @body = CP::Body.new(@mass,@moment)
      @body.p = p
      
      @shape = CP::Shape::Circle.new(@body,@radius,CP.vzero)
      @shape.u = 1.5
      
      # And once again, initialize our CP::Object.
      init_chipmunk_object(@body,@shape)
    end
  end
  
  # Here's our Terrain class.
  class Terrain
    include CP::Object
    
    # The constructor for Terrain takes an array of floats representing the
    # height of the terrain at that point. It defaults to the DefaultTerrainData
    # constant, defined below.
    def initialize(terrain_data = DefaultTerrainData)
      
      # For our terrain, we use a Chipmunk StaticBody primitive. Static
      # bodies are just like bodies, but they represent objects that never
      # move. In this case, the ground. Note that the key feature of
      # a CP::StaticBody is that Space#add_object will skip over StaticBodies.
      # They're still around to affect the world because their associated
      # CP::Shape objects *are* added to the space. The body can't be added to
      # the space because otherwise it would be effected by gravity.
      # Don't use Space#add_body to add a static body yourself!
      @body = CP::StaticBody.new
      
      # Here we take the array of points passed in and transform it into an
      # array of line segements.
      @shapes = terrain_data.enum_for(:each_with_index).map do |datum,i|
        CP::Vec2.new(i*50.0,datum)
      end.enum_cons(2).map do |a,b|
        seg = CP::StaticShape::Segment.new(@body,a,b,0.0)
        seg.u = 1.0
        seg
      end
      
      # One last time, initialize our body and line segments.
      init_chipmunk_object(@body,*@shapes)
    end
    
    # This is the default terrain height data.
    DefaultTerrainData = [
       660.00, 660.00, 660.00, 660.00, 673.21, 688.42, 694.56, 692.55,
       685.40, 676.12, 667.75, 662.45, 658.93, 655.42, 650.17, 641.49,
       627.92, 610.08, 589.01, 565.71, 541.23, 516.58, 492.56, 469.57,
       447.97, 428.13, 410.60, 397.25, 392.66, 394.89, 400.70, 406.82,
       410.93, 413.87, 416.91, 421.30, 428.24, 436.05, 440.41, 437.09,
       421.93, 394.41, 355.57, 308.78, 257.99, 207.18, 160.31, 120.81,
       89.20, 65.17, 48.43, 38.67, 36.68, 45.03, 64.17, 92.26, 128.76,
       173.27, 224.20, 278.84, 334.48, 388.43, 438.31, 483.95, 525.96,
       564.95, 601.54, 633.88, 655.05, 665.87, 667.79, 662.25, 650.01,
       629.92, 604.68, 577.50, 551.55, 529.69, 512.49, 502.04, 500.20,
       502.72, 508.57, 518.31, 531.15, 545.99, 561.70, 577.30, 593.74,
       610.97, 628.13, 644.35, 658.81, 672.13, 684.78, 696.72, 708.00,
       718.65, 728.17, 736.14, 742.62, 747.63, 751.20, 752.58, 750.20,
       743.02, 730.05, 709.98, 682.99, 651.49, 616.61, 579.47, 541.18,
       503.87, 471.12, 444.10, 423.86, 411.44, 407.95, 414.29, 430.28,
       453.64, 482.36, 514.10, 545.66, 577.48, 610.42, 645.32, 682.66,
       719.61, 754.76, 787.26, 816.26, 840.95, 861.10, 876.94, 888.71,
       896.61, 900.84, 900.46, 894.59, 882.69, 864.24, 838.69, 805.77,
       765.56, 718.19, 670.07, 626.07, 586.87, 551.65, 518.20, 484.33,
       447.81, 408.39, 367.51, 324.70, 279.44, 231.25, 181.20, 134.59,
       96.96, 66.40, 40.75, 18.74, 1.97, -8.96, -13.56, -11.33, -2.28,
       11.64, 29.88, 52.04, 78.07, 108.53, 139.94, 171.90, 204.54,
       238.00, 272.25, 305.61, 336.90, 365.19, 389.61, 409.28, 424.38,
       434.79, 438.85, 437.12, 431.08, 422.77, 412.26, 398.92, 382.10,
       361.16, 336.82, 311.06, 285.61, 262.18, 242.50
    ]
  end 
end

MoonBuggy::MainWindow.new.show