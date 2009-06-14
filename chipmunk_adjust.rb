require 'chipmunk_object'

# This file adds some useful accessors to chipmunk that are present in the C
# Structs but not available in ruby. Note of course that we aren't accessing
# the C Structs directly here, but since the values we are trying to keep
# track of do not change over the life of a body or shape, it works out fine.
# Also added dispatching for drawing shapes, to make things neater and not
# require typechecking the shape to find out what draw method to use.
module CP
  def self.vzero
    CP::Vec2.new(0.0,0.0)
  end
  module Shape
    class Circle
      attr_reader :radius, :center
      alias_method :orig_init, :initialize
      def initialize(body, radius, center)
        @radius, @center = radius, center
        orig_init(body,radius,center)
      end
      def draw(window)
        window.draw_circle_shape(self)
      end
    end
  
    class Segment
      attr_reader :a, :b, :radius
      alias_method :orig_init, :initialize
      def initialize(body, a, b, radius)
        @a, @b, @radius = a, b, radius
        orig_init(body,a,b,radius)
      end
      def draw(window)
        window.draw_segment_shape(self)
      end
    end
    
    class Poly
      attr_reader :verts, :offset
      alias_method :orig_init, :initialize
      def initialize(body, verts, offset)
        @verts, @offset = verts, offset
        orig_init(body,verts,offset)
      end
      def draw(window)
        window.draw_poly_shape(self)
      end
    end
  end
  class Body
    def draw(window)
      window.draw_vertex(self.p.x,self.p.y)
    end
  end
  module Object
    def draw(window)
      @chipmunk_objects.each do |obj|
        obj.draw(window) if obj.is_a?(Shape) || obj.is_a?(Body)
      end
    end
    def reset_forces
      @chipmunk_objects.each do |obj|
        obj.reset_forces if obj.is_a?(Body)
      end
    end
  end
end
