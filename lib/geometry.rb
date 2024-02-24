module Gifenc
  # This module encapsulates all the necessary geometric functionality, and
  # more generally, all mathematical methods that may be useful for several
  # tasks of the library, such as drawing, resampling, etc.
  module Geometry

    # Represents a point in the plane. It's essentially a wrapper for an integer
    # array with 2 elements (the coordinates) and many geometric methods that
    # aid working with them. It is used indistinctly for both points and vectors.
    # @todo Add reflections, dot product and projections, and implement this class
    #    in drawing methods such as line or rect.
    class Point

      # The X coordinate of the point.
      # @return [Integer] X coordinate.
      attr_accessor :x

      # The Y coordinate of the point.
      # @return [Integer] Y coordinate.
      attr_accessor :y

      # Parse a point from an arbitrary argument. It accepts either:
      # * A point object, in which case it returns itself.
      # * An array, in which case it creates a new point whose coordinates are
      #   the values of the array.
      # @param point [Point,Array<Integer>] The parameter to parse the point from.
      # @return [Point] The parsed point object.
      # @raise [Exception::GeometryError] When a point couldn't be parsed from the supplied
      #   argument.
      def self.parse(point)
        if point.is_a?(Point)
          point
        elsif point.is_a?(Array)
          Point.new(point[0], point[1])
        else
          raise Exception::GeometryError, "Couldn't parse point from argument."
        end
      end

      # Create a new point given its coordinates. The coordinates are assumed to
      # be the Cartesian coordinates with respect to the same axes as the desired
      # image, and they need not be integers (though they'll be casted as such
      # when actually drawing them).
      # @param x [Float] The X coordinate of the point.
      # @param y [Float] The Y coordinate of the point.
      def initialize(x, y)
        @x = x.to_f
        @y = y.to_f
      end

      # Compute the left-hand (CCW) normal vector.
      # @return [Point] The left-hand normal vector.
      # @see #normal_right
      def normal_left
        Point.new(@y, -@x)
      end

      # Compute the right-hand (CW) normal vector.
      # @return [Point] The right-hand normal vector.
      # @see #normal_left
      def normal_right
        Point.new(-@y, @x)
      end

      alias_method :normal, :normal_right

      # Compute the p-norm of the vector. It should be `p>0`.
      # @param p [Float] The parameter of the norm.
      # @return [Float] The p-norm of the vector.
      # @see #norm_1
      # @see #norm
      # @see #norm_inf
      def norm_p(p = 2)
        (@x.abs ** p + @y.abs ** p) ** (1.0 / p)
      end

      # Shortcut to compute the 1-norm of the vector.
      # @return [Float] The 1-norm of the vector.
      # @see #norm_p
      def norm_1
        (@x.abs + @y.abs).to_f
      end

      # Shortcut to compute the euclidean norm of the vector.
      # @return [Float] The euclidean norm of the vector.
      # @see #norm_p
      def norm
        norm_p(2)
      end

      alias_method :norm_2, :norm

      # Shortcut to compute the infinity (maximum) norm of the vector.
      # @return [Float] The infinity norm of the vector.
      # @see #norm_p
      def norm_inf
        [@x.abs, @y.abs].max.to_f
      end

      # Normalize the vector with respect to the p-norm. It should be `p>0`.
      # @param (see #norm_p)
      # @return [Point] The normalized vector.
      # @see #normalize_1
      # @see #normalize
      # @see #normalize_inf
      # @raise [Exception::GeometryError] If trying to normalize the null vector.
      def normalize_p(p)
        normalize_gen(norm_p(p))
      end

      # Shotcut to normalize the vector with respect to the 1-norm.
      # @return (see #normalize_p)
      # @see #normalize_p
      # @raise [Exception::GeometryError] If trying to normalize the null vector.
      def normalize_1
        normalize_p(1)
      end

      # Shotcut to normalize the vector with respect to the euclidean norm.
      # @return (see #normalize_p)
      # @see #normalize_p
      # @raise [Exception::GeometryError] If trying to normalize the null vector.
      def normalize
        normalize_p(2)
      end

      alias_method :normalize_2, :normalize

      # Shotcut to normalize the vector with respect to the infinity norm.
      # @return (see #normalize_p)
      # @see #normalize_p
      # @raise [Exception::GeometryError] If trying to normalize the null vector.
      def normalize_inf
        normalize_gen(norm_inf)
      end

      # Add another point to this one.
      # @param p [Point] The other point.
      # @return [Point] The new point.
      def +(p)
        p = Point.parse(p)
        Point.new(@x + p.x, @y + p.y)
      end

      # Make all coordinates positive. This is equivalent to reflecting the
      # point about the coordinate axes until it is in the first quadrant.
      # @return (see #+)
      def +@
        Point.new(@x.abs, @y.abs)
      end

      # Subtract another point to this one.
      # @param (see #+)
      # @return (see #+)
      def -(p)
        p = Point.parse(p)
        Point.new(@x - p.x, @y - p.y)
      end

      # Take the opposite point with respect to the origin. This is equivalent
      # to performing half a rotation about the origin.
      # @return (see #-)
      def -@
        Point.new(-@x, -@y)
      end

      # Scale the point by a factor.
      # @param s [Float] The factor to scale the point.
      # @return (see #+)
      def *(s)
        Point.new(@x * s, @y * s)
      end

      # Scale the point by the inverse of a factor.
      # @param (see #*)
      # @return (see #+)
      def /(s)
        Point.new(@x / s, @y / s)
      end

      # Rotate the point by a certain angle about a given center.
      # @param angle [Float] The angle to rotate the point, in radians.
      # @param center [Point] The point to rotate about.
      # @return (see #+)
      def rotate(angle, center = ORIGIN)
        center = Point.parse(center)
        x_old = @x - center.x
        y_old = @y - center.y
        sin = Math.sin(angle)
        cos = Math.cos(angle)
        x = x_old * cos - y_old * sin
        y = x_old * sin + y_old * cos
        Point.new(x + center.x, y + center.y)
      end

      # Shortcut to rotate the point 90 degrees counterclockwise about a given
      #   center.
      # @param center [Point] The point to rotate about.
      # @return (see #+)
      def rotate_left(center = ORIGIN)
        rotate(-Math::PI / 2, center)
      end

      # Shortcut to rotate the point 90 degrees clockwise about a given center.
      # @param (see #rotate_left)
      # @return (see #+)
      def rotate_right(center = ORIGIN)
        rotate(Math::PI / 2, center)
      end

      # Shortcut to rotate the point 180 degrees about a given center.
      # @param (see #rotate_left)
      # @return (see #+)
      def rotate_180(center = ORIGIN)
        rotate(Math::PI, center)
      end

      alias_method :translate, :+
      alias_method :scale, :*

      # Convert to integer point by rounding the coordinates.
      # @return (see #+)
      # @see #to_i
      # @see #floor
      # @see #ceil
      def round
        Point.new(@x.round, @y.round)
      end

      # Convert to integer point by taking the integer part of the coordinates.
      # @return (see #+)
      # @see #floor
      # @see #ceil
      # @see #round
      def to_i
        Point.new(@x.to_i, @y.to_i)
      end

      alias_method :truncate, :to_i

      # Convert to integer point by taking the floor part of the coordinates.
      # @return (see #+)
      # @see #to_i
      # @see #ceil
      # @see #round
      def floor
        Point.new(@x.floor, @y.floor)
      end

      # Convert to integer point by taking the ceiling part of the coordinates.
      # @return (see #+)
      # @see #to_i
      # @see #floor
      # @see #round
      def ceil
        Point.new(@x.ceil, @y.ceil)
      end

      # Format the point's coordinates in the usual form.
      # @return [String] The formatted point.
      def to_s
        "(#{@x}, #{@y})"
      end

      private

      # Normalize the vector with respect to an arbitrary norm.
      def normalize_gen(norm)
        raise Exception::GeometryError, "Cannot normalize null vector." if norm < PRECISION
        Point.new(@x / norm, @y / norm)
      end

    end # Class Point

    # Precision of the floating point math. Anything below this threshold will
    # be considered 0.
    # @return [Float] Floating point math precision.
    PRECISION = 1E-7

    # The point representing the origin of coordinates.
    # @return [Point] Origin of coordinates.
    ORIGIN = Point.new(0, 0)

    # The point representing the first vector of the canonical base.
    # @return [Point] First canonical vector.
    E1 = Point.new(1, 0)

    # The point representing the second vector of the canonical base.
    # @return [Point] Second canonical vector.
    E2 = Point.new(0, 1)

    # Finds the endpoint of a line given the startpoint and something else.
    # Namely, either of the following:
    # * The displacement vector (`vector`).
    # * The direction vector (`direction`) and the length (`length`).
    # * The angle (`angle`) and the length (`length`).
    # @param point [Array<Integer>] The [X, Y] coordinates of the startpoint.
    # @param vector [Array<Integer>] The coordinates of the displacement vector.
    # @param direction [Array<Integer>] The coordinates of the direction vector.
    #   If this method is chosen, the `length` must be provided as well.
    #   Note that this vector will be normalized automatically.
    # @param angle [Float] Angle of the line in radians (0-2Pi).
    #   If this method is chosen, the `length` must be provided as well.
    # @param length [Float] The length of the line. Must be provided if either
    #   the `direction` or the `angle` method is being used.
    # @return [Array<Integer>] The [X, Y] coordinates of the line's endpoint.
    # @raise [Exception::CanvasError] If the supplied parameters don't suffice
    #   to determine a line (e.g. provided the `angle` but not the `length`).
    def self.endpoint(
        point: nil, vector: nil, direction: nil, angle: nil, length: nil
      )
      raise Exception::CanvasError, "The line start must be specified." if !point
      point = Point.parse(point)
      if vector
        vector = Point.parse(vector)
        x1 = point.x + vector.x
        y1 = point.y + vector.y
      else
        raise Exception::CanvasError, "Either the endpoint, the vector or the length must be provided." if !length
        if direction
          direction = Point.parse(direction).normalize
        else
          raise Exception::CanvasError, "The angle must be specified if no direction is provided." if !angle
          direction = Point.new([Math.cos(angle), Math.sin(angle)])
        end
        x1 = (point.x + length * direction.x).to_i
        y1 = (point.y + length * direction.y).to_i
      end
      Point.new([x1, y1])
    end

    # Finds the bounding box of a set of points, i.e., the minimal rectangle
    # containing all specified points.
    # @param points [Array<Array<Integer>>] The list of points, each provided as
    #   a tuple of coordinates [X, Y].
    # @param pad [Integer] The amount of extra padding pixels to take on each
    #   side of the rectangle. If negative, the rectangle will be smaller and thus
    #   not contain all points.
    # @return [Array<Integer>] Bounding box in the form `[X, Y, W, H]`, where
    #   `[X, Y]` are the coordinates of the upper left corner of the rectangle,
    #   and `[W, H]` are its width and height, respectively.
    def self.bbox(points, pad = 0)
      x0 = points.min_by(&:first)[0] - pad
      y0 = points.min_by(&:last)[1] - pad
      x1 = points.max_by(&:first)[0] + pad
      y1 = points.max_by(&:last)[1] + pad
      [x0, y0, x1 - x0 + 1, y1 - y0 + 1]
    end

    # Translate a set of points according to a fixed vector. Given a list of
    # points `P1, ... , Pn` and a translation vector `t`, this method will
    # return the transformed list of points `P1 + t, ... , Pn + t`.
    # @param points [Array<Array<Integer>>] The list of points, each provided as
    #   a tuple of coordinates [X, Y].
    # @param vector [Array<Integer>] The translation vector to apply to all
    #   the supplied points.
    # @return [Array<Array<Integer>>] The list of translated points.
    def self.translate(points, vector)
      points.map{ |p| [p[0] + vector[0], p[1] + vector[1]] }
    end

    # Computes the coordinates of a list of points relative to a provided bbox.
    # This can be useful when we have the coordinates relative to the whole
    # logical screen, but we want to use them in an image that doesn't cover the
    # whole canvas. We can simply provide the bounding box of the image, that
    # specifies the image's offset and dimensions, and this will transform the
    # coordinates so that they can be used in the image with the same result.
    # In practice, this simply translates the points by subtracting the upper
    # left corner of the bounding box.
    # @param points [Array<Array<Integer>>] The list of points, each provided as
    #   a tuple of coordinates [X, Y].
    # @param bbox [Array<Integer>] The bounding box in the form `[X, Y, W, H]`,
    #   where `[X, Y]` are the coordinates of the upper left corner of the
    #   rectangle, and `[W, H]` are its width and height, respectively.
    # @return [Array<Array<Integer>>] The list of transformed points.
    def self.transform(points, bbox)
      translate(points, [-bbox[0], -bbox[1]])
    end

    # Checks if a list of points is entirely contained in the specified bounding
    # box.
    # @param (see #transform)
    # @param silent [Boolean] Whether to raise an exception or simply return
    #   false when the check is failed.
    # @return [Boolean] Whether all points are contained in the bounding box or not.
    # @raise [Exception::CanvasError] If the points are not contained in the
    #   bounding box and `silent` has not been set.
    def self.bound_check(points, bbox, silent = false)
      points.map!{ |p| Point.parse(p) }
      outer_points = points.select{ |p|
        !p.x.between?(bbox[0], bbox[0] + bbox[2] - 1) ||
        !p.y.between?(bbox[1], bbox[1] + bbox[3] - 1)
      }
      if outer_points.size > 0
        return false if silent
        points_str = outer_points.take(3).map{ |p| "(#{p.x}, #{p.y})" }
                                 .join(', ') + '...'
        raise Exception::CanvasError, "Out of bounds pixels found: #{points_str}"
      end
      true
    end

  end # Module Geometry
end # Module Gifenc