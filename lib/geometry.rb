module Gifenc
  # This module encapsulates all the necessary geometric functionality, and
  # more generally, all mathematical methods that may be useful for several
  # tasks of the library, such as drawing, resampling etc.
  module Geometry

    # Finds the endpoint of a line given the startpoint `point` and _either_:
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
    #   the `diretion` or the `angle` method is being used.
    # @return [Array<Integer>] The [X, Y] coordinates of the line's endpoint.
    # @raise [Exception::CanvasError] If the supplied parameters don't suffice
    #   to determine a line (e.g. provided the `angle` but not the `length`).
    def self.endpoint(
        point: nil, vector: nil, direction: nil, angle: nil, length: nil
      )
      raise Exception::CanvasError, "The line start must be specified." if !point
      if vector
        x1 = x0 + vector[0]
        y1 = y0 + vector[1]
      else
        raise Exception::CanvasError, "Either the endpoint, the vector or the length must be provided." if !length
        if direction
          mod = Math.sqrt(direction[0] ** 2 + direction[1] ** 2)
          direction[0] /= mod
          direction[1] /= mod
        else
          raise Exception::CanvasError, "The angle must be specified if no direction is provided." if !angle
          direction = [Math.cos(angle), Math.sin(angle)]
        end
        x1 = (point[0] + length * direction[0]).to_i
        y1 = (point[1] + length * direction[1]).to_i
      end
      [x1, y1]
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
      outer_points = points.select{ |p|
        !p[0].between?(bbox[0], bbox[0] + bbox[2]) ||
        !p[1].between?(bbox[1], bbox[1] + bbox[3])
      }
      if outer_points.size > 0
        return false if silent
        points_str = outer_points.take(3).map{ |p| "(#{p[0]}, #{p[1]})" }
                                 .join(', ') + '...'
        raise Exception::CanvasError, "Out of bounds pixels found: #{points_str}"
      end
      true
    end

  end
end
