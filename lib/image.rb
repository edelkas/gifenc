require 'lzwrb'

module Gifenc
  # Represents a single image. A GIF may contain multiple images, and they need
  # not be animation frames (they could simply be tiles of a static image).
  # Crucially, images can be smaller than the GIF logical screen (canvas), thus
  # being placed at an offset of it, saving space and time, and allowing for more
  # complex compositions. How each image interacts with the previous ones depends
  # on properties like the disposal method ({#disposal}) and the transparency
  # ({#trans_color}).
  #
  # Most methods modifying the image return the image itself, so that they can
  # be chained properly.
  class Image

    # Width of the image in pixels. Use the {#resize} method to change it.
    # @return [Integer] Image width.
    # @see #resize
    attr_reader :width

    # Height of the image in pixels. Use the {#resize} method to change it.
    # @return [Integer] Image height.
    # @see #resize
    attr_reader :height

    # The image's horizontal offset in the GIF's logical screen. Note that the
    # image will be cropped if it overflows the logical screen's boundary.
    # @return [Integer] Image X offset.
    # @see #move
    # @see #place
    attr_accessor :x

    # The image's vertical offset in the GIF's logical screen. Note that the
    # image will be cropped if it overflows the logical screen's boundary.
    # @return [Integer] Image Y offset.
    # @see #move
    # @see #place
    attr_accessor :y

    # Default color of the canvas. This is the initial color of the image, as
    # well as the color that appears in the new regions when the canvas is
    # is enlarged.
    # @return [Integer] Index of the canvas color in the color table.
    attr_accessor :color

    # The local color table to use for this image. If left unspecified (`nil`),
    # the global color table will be used.
    # @return [ColorTable] Local color table.
    attr_accessor :lct

    # Contains the table based image data (the color indexes for each pixel).
    # Use the {#replace} method to bulk change the pixel data.
    # @return [Array<Integer>] Pixel data.
    # @see #replace
    attr_reader :pixels

    # Create a new image or frame. The minimum information required is the
    # width and height, which may be supplied directly, or by providing the
    # bounding box, which also contains the offset of the image in the
    # logical screen.
    # @param width [Integer] Width of the image in pixels.
    # @param height [Integer] Height of the image in pixels.
    # @param x [Integer] Horizontal offset of the image in the logical screen.
    # @param y [Integer] Vertical offset of the image in the logical screen.
    # @param bbox [Array<Integer>] The image's bounding box, which is a tuple
    #   in the form `[X, Y, W, H]`, where `[X, Y]` are the coordinates of its
    #   upper left corner, and `[W, H]` are its width and height, respectively.
    #   This can be provided instead of the first 4 parameters.
    # @param color [Integer] The initial color of the canvas.
    # @param gce [Extension::GraphicControl] An optional {Extension::GraphicControl
    #   Graphic Control Extension} for the image. This extension controls mainly
    #   3 things: the image's *delay* onscreen, the color to use for
    #   *transparency*, and the *disposal* method to employ before displaying
    #   the next image. These things can instead be supplied individually in their
    #   corresponding parameters: `delay`, `trans_color` and `disposal`. Each
    #   individually passed parameter will override the corresponding value in
    #   the GCE, if supplied. If neither a GCE nor any of the 3 individual
    #   parameters is used, then a GCE will not be built, unless the attributes
    #   are written to later.
    # @param delay [Integer] Time, in 1/100ths of a second, to wait before
    #   displaying the next image (see {#delay} for details).
    # @param trans_color [Integer] Index of the color to use for transparency
    #   (see {#trans_color} for details)
    # @param disposal [Integer] The disposal method to use after displaying
    #   this image and before displaying the next one (see {#disposal} for details).
    # @param interlace [Boolean] Whether the pixel data of this image is
    #   interlaced or not.
    # @param lct [ColorTable] Add a Local Color Table to this image, overriding
    #   the global one.
    # @return [Image] The image.
    def initialize(
        width      = nil,
        height     = nil,
        x          = nil,
        y          = nil,
        bbox:        nil,
        color:       DEFAULT_COLOR,
        gce:         nil,
        delay:       nil,
        trans_color: nil,
        disposal:    nil,
        interlace:   DEFAULT_INTERLACE,
        lct:         nil
      )
      # Image attributes
      if bbox
        @x      = bbox[0]
        @y      = bbox[1]
        @width  = bbox[2]
        @height = bbox[3]
      end
      @width     = width  if width
      @height    = height if height
      @x         = x      if x
      @y         = y      if y
      @lct       = lct
      @interlace = interlace

      # Checks
      raise Exception::CanvasError, "The width of the image must be supplied" if !@width
      raise Exception::CanvasError, "The height of the image must be supplied" if !@height
      @x = 0 if !@x
      @y = 0 if !@y

      # Image data
      @color  = color
      @pixels = [@color] * (@width * @height)

      # Extended features
      if gce || delay || trans_color || disposal
        @gce = gce ? gce.dup : Extension::GraphicControl.new
        @gce.delay       = delay       if delay
        @gce.trans_color = trans_color if trans_color
        @gce.disposal    = disposal    if disposal
      end
    end

    # Encode the image data to GIF format and write it to a stream.
    # @param stream [IO] Stream to write the data to.
    # @todo Add support for interlaced images.
    def encode(stream)
      # Optional Graphic Control Extension before image data
      @gce.encode(stream) if @gce

      # Image descriptor
      stream << ','
      stream << [@x, @y, @width, @height].pack('S<4')
      flags = (@interlace ? 1 : 0) << 6
      flags |= @lct.local_flags if @lct
      stream << [flags].pack('C')

      # Local Color Table
      @lct.encode(stream) if @lct

      # LZW-compressed image data
      min_bits = 8 #@lct ? @lct.bit_size : 8
      stream << min_bits.chr
      lzw = LZWrb.new(preset: LZWrb::PRESET_GIF, min_bits: min_bits, verbosity: :minimal)
      stream << Util.blockify(lzw.encode(@pixels.pack('C*')))
    end

    # Create a duplicate copy of this image.
    # @return [Image] The new image.
    def dup
      lct = @lct ? @lct.dup : nil
      gce = @gce ? @gce.dup : nil
      image = Image.new(
        @width, @height, @x, @y,
        color: @color, gce: gce, delay: @delay, trans_color: @trans_color,
        disposal: @disposal, interlace: @interlace, lct: lct
      ).replace(@pixels)
      image
    end

    # Get current delay, in 1/100ths of a second, to display this image before
    # moving on to the next one. Note that very small delays are typically not
    # supported, see {Extension::GraphicControl#delay} for more details.
    # @return [Integer] Time to display the image.
    # @see Extension::GraphicControl#delay
    def delay
      @gce ? @gce.delay : nil
    end

    # Set current delay, in 1/100ths of a second, to display this image before
    # moving on to the next one. Note that very small delays are typically not
    # supported, see {Extension::GraphicControl#delay} for more details.
    # @return (see #delay)
    # @see (see #delay)
    def delay=(value)
      @gce = Extension::GraphicControl.new if !@gce
      @gce.delay = value
    end

    # Get the disposal method of the image, which specifies how to handle the
    # disposal of this image before displaying the next one in the GIF. See
    # {Extension::GraphicControl#disposal} for details about the
    # different disposal methods available.
    # @return [Integer] The current disposal method.
    # @see Extension::GraphicControl#disposal
    def disposal
      @gce ? @gce.disposal : nil
    end

    # Set the disposal method of the image, which specifies how to handle the
    # disposal of this image before displaying the next one in the GIF. See
    # {Extension::GraphicControl#disposal} for details about the
    # different disposal methods available.
    # @return (see #disposal)
    # @see (see #disposal)
    def disposal=(value)
      @gce = Extension::GraphicControl.new if !@gce
      @gce.disposal = value
    end

    # Get the index (in the color table) of the transparent color. Pixels with
    # this color aren't rendered, and instead the background shows through them.
    # See {Extension::GraphicControl#trans_color} for more details.
    # @return [Integer] Index of the transparent color.
    # @see Extension::GraphicControl#trans_color
    def trans_color
      @gce ? @gce.trans_color : nil
    end

    # Set the index (in the color table) of the transparent color. Pixels with
    # this color aren't rendered, and instead the background shows through them.
    # See {Extension::GraphicControl#trans_color} for more details.
    # @return (see #trans_color)
    # @see (see #trans_color)
    def trans_color=(value)
      @gce = Extension::GraphicControl.new if !@gce
      @gce.trans_color = value
    end

    # Fetch one row of pixels from the image.
    # @param row [Integer] The index of the row to fetch.
    # @return [Array<Integer>] The row of pixels.
    # @raise [Exception::CanvasError] If the row is out of bounds.
    def row(row)
      if row < 0 || row >= @height
        raise Exception::CanvasError, "Row out of bounds."
      end
      @pixels[row * @width, @width]
    end

    # Fetch one column of pixels from the image.
    # @param col [Integer] The index of the column to fetch.
    # @return [Array<Integer>] The column of pixels.
    # @raise [Exception::CanvasError] If the column is out of bounds.
    def col(col)
      if col < 0 || col >= @width
        raise Exception::CanvasError, "Column out of bounds."
      end
      @height.times.map{ |r| @pixels[col, r] }
    end

    # Change the pixel data (color indices) of the image. The size of the array
    # must match the current dimensions of the canvas, otherwise a manual resize
    # is first required.
    # @param pixels [Array<Integer>] The new pixel data to fill the canvas.
    # @raise [Exception::CanvasError] If the supplied pixel data length doesn't match the
    #   canvas's current dimensions.
    # @return (see #initialize)
    def replace(pixels)
      if pixels.size != @width * @height
        raise Exception::CanvasError, "Pixel data doesn't match image dimensions. Please\
          resize the image first."
      end
      @pixels = pixels
      self
    end

    # Copy a rectangular region from another image to this one. The offsets and
    # dimensions of the region can be specified.
    # @note The two images are assumed to have the same color table, since what
    #   is copied is the color indexes.
    # @param source [Image] The source image to copy the contents from.
    # @param offset [Array<Integer>] The coordinates of the offset of the region
    #   in the source image.
    # @param dim [Array<Integer>] The dimensions of the region, in the form `[W, H]`,
    #   where W is the width and H is the height of the rectangle to copy.
    # @param dest [Array<Integer>] The coordinates of the destination offset of
    #   the region in this image.
    # @raise [Exception::CanvasError] If the region is out of bounds in either
    #   the source or the destination images.
    # @return (see #initialize)
    def copy(source: nil, offset: [0, 0], dim: [1, 1], dest: [0, 0])
      offset = Geometry::Point.parse(offset)
      dim    = Geometry::Point.parse(dim)
      dest   = Geometry::Point.parse(dest)
      if !source.bound_check(offset) || !source.bound_check(offset + dim - [1, 1])
        raise Exception::CanvasError, "Cannot copy, region out of bounds in source image."
      end
      if !bound_check(dest) || !bound_check(dest + dim - [1, 1])
        raise Exception::CanvasError, "Cannot copy, region out of bounds in destination image."
      end

      dx = dest.x.round
      dy = dest.y.round
      ox = offset.x.round
      oy = offset.y.round
      dim.y.round.times.each{ |y|
        @pixels[(dy + y) * @width + dx, dim.x.round] = source.pixels[(oy + y) * source.width + ox, dim.x.round]
      }

      self
    end

    # Change the image's width and height. If the provided values are smaller,
    # the image is cropped. If they are larger, the image is padded with the
    # color specified by {#color}.
    # @return (see #initialize)
    def resize(width, height)
      @pixels = @pixels.each_slice(@width).map{ |row|
        width > @width ? row + [@color] * (width - @width) : row.take(width)
      }
      @pixels = height > @height ? @pixels + ([@color] * width) * (height - @height) : @pixels.take(height)
      @pixels.flatten!
      self
    end

    # Place the image at a different origin of coordinates.
    # @param x [Integer] New origin horizontal coordinate.
    # @param y [Integer] New origin vertical coordinate.
    # @return (see #initialize)
    # @see #move
    # @raise [Exception::CanvasError] If we're placing the image out of bounds.
    # @todo We're only checking negative out of bounds, what about positive ones?
    def place(x, y)
      raise Exception::CanvasError, "Cannot move image, out of bounds." if @x < 0 || @y < 0
      @x = x
      @y = y
      self
    end

    # Move the image relative to the current position.
    # @param x [Integer] X displacement.
    # @param y [Integer] Y displacement.
    # @return (see #initialize)
    # @see #place
    # @raise [Exception::CanvasError] If the movement would place the image out of bounds.
    # @todo We're only checking negative out of bounds, what about positive ones?
    def move(x, y)
      raise Exception::CanvasError, "Cannot move image, out of bounds." if @x < -x || @y < -y
      @x += x
      @y += y
      self
    end

    # Returns the bounding box of the image. This is a tuple of the form
    # `[X, Y, W, H]`, where `[X, Y]` are the coordinates of its upper left
    # corner - i.e., it's offset in the logical screen - and `[W, H]` are
    # its width and height, respectively, in pixels.
    # @return [Array] The image's bounding box in the format described above.
    def bbox
      [@x, @y, @width, @height]
    end

    # Get the value (color _index_) of a pixel fast (i.e. without bound checks).
    # See also {#get}.
    # @param x [Integer] The X coordinate of the pixel.
    # @param y [Integer] The Y coordinate of the pixel.
    # @return [Integer] The color index of the pixel.
    def [](x, y)
      @pixels[y * @width + x]
    end

    # Set the value (color _index_) of a pixel fast (i.e. without bound checks).
    # See also {#set}.
    # @param x [Integer] The X coordinate of the pixel.
    # @param y [Integer] The Y coordinate of the pixel.
    # @param color [Integer] The new color index of the pixel.
    # @return [Integer] The new color index of the pixel.
    def []=(x, y, color)
      @pixels[y * @width + x] = color & 0xFF
    end

    # Get the values (color _index_) of a list of pixels safely (i.e. with bound
    # checks). For the fast version, see {#[]}.
    # @param points [Array<Array<Integer>>] The list of points whose color should
    #   be retrieved. Must be an array of pairs of coordinates.
    # @return [Array<Integer>] The list of colors, in the same order.
    # @raise [Exception::CanvasError] If any of the specified points is out of bounds.
    def get(points)
      bound_check([points.min_by(&:first)[0], points.min_by(&:last)[1]], false)
      bound_check([points.max_by(&:first)[0], points.max_by(&:last)[1]], false)
      points.map{ |p|
        @pixels[p[1] * @width + p[0]]
      }
    end

    # Set the values (color _index_) of a list of pixels safely (i.e. with bound
    # checks). For the fast version, see {#[]=}.
    # @param points [Array<Array<Integer>>] The list of points whose color to
    #   change. Must be an array of pairs of coordinates.
    # @param colors [Integer, Array<Integer>] The color(s) to assign. If an
    #   integer is passed, then all pixels will be set to the same color.
    #   Alternatively, an array with the same length as the points list must be
    #   passed, and each point will be set to the respective color in the list.
    # @return (see #initialize)
    # @raise [Exception::CanvasError] If any of the specified points is out of bounds.
    def set(points, colors)
      bound_check([points.min_by(&:first)[0], points.min_by(&:last)[1]], false)
      bound_check([points.max_by(&:first)[0], points.max_by(&:last)[1]], false)
      single = colors.is_a?(Integer)
      points.each_with_index{ |p, i|
        @pixels[p[1] * @width + p[0]] = single ? color & 0xFF : colors[i] & 0xFF
      }
      self
    end

    # Draw a straight line connecting 2 points. It requires the startpoint `p1`
    # and _either_ of the following:
    # * The endpoint (`p2`).
    # * The displacement vector (`vector`).
    # * The direction vector (`direction`) and the length (`length`).
    # * The angle (`angle`) and the length (`length`).
    # @param p1 [Array<Integer>] The [X, Y] coordinates of the startpoint.
    # @param p2 [Array<Integer>] The [X, Y] coordinates of the endpoint.
    # @param vector [Array<Integer>] The coordinates of the displacement vector.
    # @param direction [Array<Integer>] The coordinates of the direction vector.
    #   If this method is chosen, the `length` must be provided as well.
    #   Note that this vector will be normalized automatically.
    # @param angle [Float] Angle of the line in radians (0-2Pi).
    #   If this method is chosen, the `length` must be provided as well.
    # @param length [Float] The length of the line. Must be provided if either
    #   the `direction` or the `angle` method is being used.
    # @param color [Integer] Index of the color of the line.
    # @param weight [Integer] Width of the line in pixels.
    # @param anchor [Float] Since the weight can be multiple pixels, this argument
    #   indicates the position of the line with respect to the coordinates. It
    #   must be in the interval [-1, 1]. A value of `0` centers the line in its
    #   width, a value of `-1` draws it on one side, and `1` on the other.
    # @param bbox [Array<Integer>] Bounding box determining the region in which
    #   the line must be contained. Anything outside it won't be drawn. If
    #   `nil`, this defaults to the whole image.
    # @param avoid [Array<Integer>] List of colors over which the line should
    #   NOT be drawn.
    # @return (see #initialize)
    # @raise [Exception::CanvasError] If the line would go out of bounds.
    # @todo Add support for anchors and anti-aliasing, better brushes, etc.
    def line(p1: nil, p2: nil, vector: nil, angle: nil, direction: nil,
      length: nil, color: 0, weight: 1, anchor: 0, bbox: nil, avoid: [])
      # Determine start and end points
      raise Exception::CanvasError, "The line start must be specified." if !p1
      p1 = Geometry::Point.parse(p1)
      if p2
        p2 = Geometry::Point.parse(p2)
      else
        p2 = Geometry.endpoint(
          point: p1, vector: vector, direction: direction,
          angle: angle, length: length
        )
      end

      if (p2 - p1).norm < Geometry::PRECISION
        a = Geometry::ORIGIN
      else
        a = (p2 - p1).normal_right.normalize_inf
        a -= a * (1 - anchor)
      end
      steps = (p2 - p1).norm_inf.ceil + 1
      delta = (p2 - p1) / [(steps - 1), 1].max
      point = p1
      brush = Brush.square(weight, color, [a.x, a.y])
      steps.times.each{ |s|
        brush.draw(point.x.round, point.y.round, self, bbox: bbox, avoid: avoid)
        point += delta
      }

      self
    end

    # Draw a rectangle with border and optional fill.
    # @param x      [Integer] X coordinate of the top-left vertex.
    # @param y      [Integer] Y coordinate of the top-left vertex.
    # @param w      [Integer] Width of the rectangle in pixels.
    # @param h      [Integer] Height of the rectangle in pixels.
    # @param stroke [Integer] Index of the border color.
    # @param fill   [Integer] Index of the fill color (`nil` for no fill).
    # @param weight [Integer] Stroke width of the border in pixels.
    # @param anchor [Float]   Indicates the position of the border with respect
    #   to the rectangle's boundary. Must be between -1 and 1. For example:
    #   * For `0` the border is centered around the boundary.
    #   * For `1` the border is entirely contained within the boundary.
    #   * For `-1` the border is entirely surrounding the boundary.
    # @return (see #initialize)
    # @raise [Exception::CanvasError] If the rectangle would go out of bounds.
    def rect(x, y, w, h, stroke = nil, fill = nil, weight: 1, anchor: 1)
      # Check coordinates
      x = x.round
      y = y.round
      w = w.round
      h = h.round
      x0, y0, x1, y1 = x, y, x + w - 1, y + h - 1
      bound_check([x0, y0])
      bound_check([x1, y1])

      # Fill rectangle, if provided
      if fill
        (x0 .. x1).each{ |x|
          (y0 .. y1).each{ |y|
            @pixels[y * @width + x] = fill
          }
        }
      end

      # Rectangle border
      if stroke
        if anchor != 0
          o = ((weight - 1) / 2.0 * anchor).round
          rect(x + o, y + o, w - 2 * o, h - 2 * o, stroke, weight: weight, anchor: 0)
        else
          points = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
          4.times.each{ |i|
            line(
              p1:     points[i],
              p2:     points[(i + 1) % 4],
              color:  stroke,
              weight: weight,
              anchor: anchor
            )
          }
        end
      end

      self
    end

    # Draw an ellipse with the given properties.
    # @param c [Array<Integer>] The X and Y coordinates of the ellipse's center.
    # @param r [Array<Float>] The semi axes (major and minor) of the ellipse,
    #   in pixels. They can be non-integer, which will affect the intermediate
    #   calculations and result in a different, in-between, shape.
    # @param stroke [Integer] Index of the color of the border. The border is
    #   drawn inside the ellipse, i.e., the supplied axes are not enlarged for
    #   the border. Leave `nil` for no border.
    # @param fill [Integer] Index of the color for the filling of the ellipse.
    #   Leave `nil` for no filling.
    # @param weight [Integer] Thickness of the border, in pixels.
    # @param style [Symbol] Style of the border. If `:smooth`, the border will
    #   approximate an elliptical shape as much as possibe. If `:grid`, each
    #   additional unit of weight is added by simply drawing an additional layer
    #   of points inside the ellipse with the border's color.
    # @return (see #initialize)
    # @raise [Exception::CanvasError] If the ellipse would go out of bounds.
    def ellipse(c, r, stroke = nil, fill = nil, weight: 1, style: :smooth)
      # Parse data
      return self if !stroke && !fill
      a = r[0]
      b = r[1]
      c = Geometry::Point.parse(c).round
      e1 = Geometry::E1
      e2 = Geometry::E2
      upper = (c - e2 * b).round
      lower = (c + e2 * b).round
      left  = (c - e1 * a).round
      right = (c + e1 * a).round
      if !Geometry.bound_check([upper, lower, left, right], self, true)
        raise Exception::CanvasError, "Ellipse out of bounds."
      end
      if stroke
        weight = [weight.to_i, 1].max
        if weight > [a, b].min
          fill = stroke
          stroke = nil
        end
      end
      f = (a.to_f / b) ** 2

      # Fill
      if fill
        b.round.downto(0).each{ |y|
          midpoint1 = ((c.y - y) * @width + c.x).round
          midpoint2 = ((c.y + y) * @width + c.x).round if y > 0
          partial_r = (y > 0 ? (a ** 2 - f * (y - 0.5) ** 2) ** 0.5 : a).round
          @pixels[midpoint1 - partial_r, 2 * partial_r + 1] = [fill] * (2 * partial_r + 1)
          @pixels[midpoint2 - partial_r, 2 * partial_r + 1] = [fill] * (2 * partial_r + 1) if y > 0
        }
      end

      # Stroke
      if stroke
        prev_r = 0
        b.round.downto(0).each{ |y|
          midpoint1 = ((c.y - y) * @width + c.x).round
          midpoint2 = ((c.y + y) * @width + c.x).round if y > 0
          partial_r = (y > 0 ? (a ** 2 - f * (y - 0.5) ** 2) ** 0.5 : a).round
          if style == :grid
            border = [weight + partial_r - prev_r, 1 + partial_r].min
            (0 ... [weight, y + 1].min).each{ |w|
              @pixels[midpoint1 - partial_r                + w * @width, border] = [stroke] * border
              @pixels[midpoint1 + partial_r - (border - 1) + w * @width, border] = [stroke] * border
              @pixels[midpoint2 - partial_r                - w * @width, border] = [stroke] * border if y > 0
              @pixels[midpoint2 + partial_r - (border - 1) - w * @width, border] = [stroke] * border if y > 0
            }
            prev_r = partial_r
          elsif style == :smooth
            a2 = [a - weight, 0].max
            b2 = [b - weight, 0].max
            f2 = (a2.to_f / b2) ** 2
            partial_r2 = (y > 0 ? (a2 ** 2 >= f2 * (y - 0.5) ** 2 ? (a2 ** 2 - f2 * (y - 0.5) ** 2) ** 0.5 : -1) : a2).round
            border = partial_r - partial_r2
            @pixels[midpoint1 - partial_r               , border] = [stroke] * border
            @pixels[midpoint1 + partial_r - (border - 1), border] = [stroke] * border
            @pixels[midpoint2 - partial_r               , border] = [stroke] * border if y > 0
            @pixels[midpoint2 + partial_r - (border - 1), border] = [stroke] * border if y > 0
          end
        }
      end

      self
    end

    # Draw a circle with the given properties.
    # @param c [Array<Integer>] The X and Y coordinates of the circle's center.
    # @param r [Float] The radius of the circle, in pixels. It can be non-integer,
    #   which will affect the intermediate calculations and result in a different
    #   final shape, which is in-between the ones corresponding to the integer
    #   values below and above for the radius.
    # @param stroke [Integer] Index of the color of the border. The border is
    #   drawn inside the circle, i.e., the supplied radius is not enlarged for
    #   the border. Leave `nil` for no border.
    # @param fill [Integer] Index of the color for the filling of the circle.
    #   Leave `nil` for no filling.
    # @param weight [Integer] Thickness of the border, in pixels.
    # @param style [Symbol] Style of the border. If `:smooth`, the border will
    #   approximate a circular shape as much as possible. If `:grid`, each
    #   additional unit of weight is added by simply drawing an additional layer
    #   of points inside the circle with the border's color.
    # @return (see #initialize)
    # @raise [Exception::CanvasError] If the circle would go out of bounds.
    def circle(c, r, stroke = nil, fill = nil, weight: 1, style: :smooth)
      ellipse(c, [r, r], stroke, fill, weight: weight, style: style)
    end

    # Draw a polygonal chain connecting a sequence of points. This simply consists
    # in joining them in order with straight lines.
    # @param points [Array<Point>] The list of points, in order, to join.
    # @param line_color [Integer] The index of the color to use for the lines.
    # @param line_weight [Float] The size of the line stroke, in pixels.
    # @param node_color [Integer] The index of the color to use for the nodes.
    #   Default (`nil`) is the same as the line color.
    # @param node_weight [Float] The radius of the node circles, in pixels. If `0`,
    #   no nodes will be drawn.
    # @return (see #initialize)
    # @raise [Exception::CanvasError] If the chain would go out of bounds. The
    #   segments that are within bounds will be drawn, even if they come after
    #   an out of bounds segment.
    def polygonal(points, line_color: 0, line_weight: 1, node_color: nil,
        node_weight: 0
      )
      node_color = line_color unless node_color
      0.upto(points.size - 2).each{ |i|
        line(p1: points[i], p2: points[i + 1], color: line_color, weight: line_weight) rescue nil
      }
      points.each{ |p| circle(p, node_weight, nil, node_color) }
      self
    end

    # Draw a 2D parameterized curve. A lambda function containing the mathematical
    # expression for each coordinate must be passed.
    # @param func [Lambda] A lambda function that takes in a single floating
    #   point parameter (the time) and outputs the pair of coordinates `[X, Y]`
    #   corresponding to the curve at that given instant.
    # @param from [Float] The starting time to begin plotting the curve, i.e.,
    #   the initial value of the time parameter for the lambda.
    # @param to [Float] The ending time to finish plotting the curve, i.e.,
    #   the final value of the time parameter for the lambda.
    # @param step [Float] The time step to use. The points of the curve resulting
    #   from this time step will be joined via straight lines. The smaller the,
    #   time step, the smoother the curve will look, resolution permitting.
    #   Alternatively, one may supply the `dots` argument.
    # @param dots [Integer] The amount of points to plot. The plotting interval
    #   will be divided into this many segments of equal size, and the resulting
    #   points will be joined via straight lines. The more dots, the smoother the
    #   curve will look. Alternatively, one may supply the `step` argument.
    # @param line_color [Integer] The index of the color to use for the trace.
    # @param line_weight [Float] The size of the brush to use for the trace.
    # @param node_color [Integer] The index of the color to use for the node
    #   circles. If `nil` (default), the line color will be used.
    # @param node_weight [Float] The radius of the node circles. If `0` (default),
    #   nodes joining each segment of the curve will not be drawn.
    # @return (see #initialize)
    # @raise [Exception::CanvasError] If the curve goes out of bounds.
    # @todo Add a way to automatically compute the time step with a reasonable
    #   value, without having to explicitly send the step or the dots.
    def curve(func, from, to, step: nil, dots: nil, line_color: 0, line_weight: 1,
      node_color: nil, node_weight: 0)
      if !step && !dots
        raise Exception::GeometryError, "Cannot infer the curve's drawing density,|
          please specify either the step or the dots argument."
      end
      step = (to - from).abs / (dots + 1) if !step
      points = (from .. to).step(step).map{ |t| func.call(t) }
      node_color = line_color unless node_color
      polygonal(points, line_color: line_color, line_weight: line_weight,
        node_color: node_color, node_weight: node_weight)

      self
    end

    # Draw a general spiral given by its scale functions in either direction.
    # These functions specify, in terms of the time, how the spiral grows
    # horizontally and vertically. For instance, a linear function would yield
    # a spiral of constant growth, i.e., an Archimedean spiral.
    # @param from [Float] The starting time to begin plotting the curve.
    # @param to [Float] The final time to end the plot.
    # @param center [Array<Integer>] The coordinates of the center of the spiral.
    # @param angle [Float] Initial angle of the spiral.
    # @param scale_x [Lambda(Float)] The function that specifies the spiral's
    #   growth in the X direction in terms of time.
    # @param scale_y [Lambda(Float)] The function that specifies the spiral's
    #   growth in the Y direction in terms of time.
    # @param speed [Float] Speed at which the spiral is traversed.
    # @param color [Integer] Index of the line's color.
    # @param weight [Float] Size of the line.
    # @param control_points [Integer] The amount of control points to use per
    #   quadrant when drawing the spiral. The higher, the smoother the curve.
    # @return (see #initialize)
    # @raise [Exception::CanvasError] If the spiral would go out of bounds.
    def spiral_general(
        from, to,
        center: [@width / 2, @height / 2],
        angle: 0,
        scale_x: -> (t) { t },
        scale_y: -> (t) { t },
        speed: 1,
        color: 0,
        weight: 1,
        control_points: 64
      )
      center = Geometry::Point.parse(center)
      curve(
        -> (t) {
          [
            center.x + scale_x.call(t) * Math.cos(angle + speed * t),
            center.y + scale_y.call(t) * Math.sin(angle + speed * t)
          ]
        },
        from, to, step: 2 * Math::PI / control_points,
        line_color: color, line_weight: weight
      )
      self
    end

    # Draw an Archimedean spiral. This type of spiral is the simplest case,
    # which grows at a constant rate on either direction.
    # @param center [Array<Integer>] The coordinates of the center of the spiral.
    # @param step [Float] Distance between spiral's loops.
    # @param loops [Float] How many loops to draw.
    # @param angle [Float] Initial spiral angle.
    # @param color [Integer] Index of the line's color.
    # @param weight [Float] Size of the line.
    # @return (see #initialize)
    # @raise (see #spiral_general)
    def spiral(center, step, loops, angle: 0, color: 0, weight: 1)
      spiral_general(
        0, loops * 2 * Math::PI, center: center, angle: angle,
        scale_x: -> (t) {step * t / (2 * Math::PI) },
        scale_y: -> (t) {step * t / (2 * Math::PI) },
        color: color, weight: weight
      )
    end

    # Represents a type of drawing brush, and encapsulates all the logic necessary
    # to use it, such as the weight, shape, anchor point, color, etc.
    class Brush

      # Actual pixels that form the brush, and that will be drawn when using it.
      # It is an array of pairs of coordinates, representing the X and Y offsets
      # from the drawing point that will be painted. For example, if
      #   `pixels = [[0, -1], [-1, 0], [0, 0], [1, 0], [0, 1]]`
      # then the brush will be a small cross centered at the drawing point.
      # @return [Array<Array<Integer>>] Coordinates of the brush relative to the
      #   drawing point.
      attr_accessor :pixels

      # The index in the color table of the default color to use when painting
      # with this brush. It can be overidden whenever it's actually used.
      # @return [Integer] Default color index.
      attr_accessor :color

      # Creates a square brush of a given size.
      # @param weight [Float] Size of the brush (side of the square) in pixels.
      # @param color [Integer] Index of the color to use as default for drawing
      #   when no explicit color is provided.
      # @param anchor [Array<Float>] The anchor determines the position of the
      #   brush with respect to the drawing coordinates. It goes from [-1, -1]
      #   (up and left) to [1, 1] (right and down). [0, 0]  would mean the brush
      #   is centered.
      # @return [Brush] The new square brush.
      def self.square(weight = 1, color = nil, anchor = [0, 0])
        weight = weight.to_f
        weight = 1.0 if weight < 1.0
        shift_x = ((1 - anchor[0]) * (weight - 1) / 2).round
        shift_y = ((1 - anchor[1]) * (weight - 1) / 2).round
        weight = weight.round

        xlim_inf = -shift_x
        xlim_sup = xlim_inf + weight
        ylim_inf = -shift_y
        ylim_sup = ylim_inf + weight

        new(
          (xlim_inf ... xlim_sup).to_a.product((ylim_inf ... ylim_sup).to_a),
          color
        )
      end

      # Create a new brush by providing the raw pixels that form it. For common
      # shapes, you may instead prefer to use one of the helpers, such as
      # {.square}.
      # @param pixels [Array<Array<Integer>>] Relative coordinates of the pixels
      #   that compose the brush (see {#pixels}).
      # @param color [Integer] Index of default brush color.
      # @return [Brush] The new brush.
      def initialize(pixels, color = nil)
        @pixels = pixels
        @color = color
      end

      # Use the brush to draw once on an image at the specified point. If no
      # color is specified, the brush's default color will be used. A bounding
      # box can be provided to restrict where in the image the drawing may
      # happen. If it's not specified, the whole image will determine this box.
      # @param x [Integer] X coordinate of the drawing point.
      # @param y [Integer] Y coordinate of the drawing point.
      # @param img [Image] Image to draw onto.
      # @param color [Integer] Index of the color in the color table to use.
      # @param bbox [Array<Integer>] Bounding box determining the drawing region,
      #   in the format `[X, Y, W, H]`.
      # @param avoid [Array<Integer>] List of colors over which the brush should
      #   NOT paint.
      def draw(x, y, img, color = @color, bbox: nil, avoid: [])
        raise Exception::CanvasError, "No provided color nor default color found." if !color
        bbox = [0, 0, img.width, img.height] if !bbox
        @pixels.each{ |dx, dy|
          if Geometry.bound_check([[x + dx, y + dy]], bbox, true) && !avoid.include?(img[x + dx, y + dy])
            img[x + dx, y + dy] = color
          end
        }
      end
    end

    # Ensure the given point is within the image's bounds.
    # @param point [Point] The point to check. Can be provided as a tuple of
    #   coordinates `[X, Y]`, or as a {Geometry::Point} object.
    # @param silent [Boolean] Whether to raise an exception or simply return
    #   false if the bound check fails.
    def bound_check(point, silent = true)
      Geometry.bound_check([point], self, silent)
    end

  end
end
