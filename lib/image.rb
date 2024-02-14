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
      )
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
      @pixels[y * width + x]
    end

    # Set the value (color _index_) of a pixel fast (i.e. without bound checks).
    # See also {#set}.
    # @param x [Integer] The X coordinate of the pixel.
    # @param y [Integer] The Y coordinate of the pixel.
    # @param color [Integer] The new color index of the pixel.
    # @return [Integer] The new color index of the pixel.
    def []=(x, y, color)
      @pixels[y * width + x] = color & 0xFF
    end

    # Get the values (color _index_) of a list of pixels safely (i.e. with bound
    # checks). For the fast version, see {#[]}.
    # @param points [Array<Array<Integer>>] The list of points whose color should
    #   be retrieved. Must be an array of pairs of coordinates.
    # @return [Array<Integer>] The list of colors, in the same order.
    # @raise [Exception::CanvasError] If any of the specified points is out of bounds.
    def get(points)
      bound_check(points.min_by(&:first)[0], points.min_by(&:last)[1])
      bound_check(points.max_by(&:first)[0], points.max_by(&:last)[1])
      points.map{ |p|
        @pixels[p[1] * width + p[0]]
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
      bound_check(points.min_by(&:first)[0], points.min_by(&:last)[1])
      bound_check(points.max_by(&:first)[0], points.max_by(&:last)[1])
      single = colors.is_a?(Integer)
      points.each_with_index{ |p, i|
        @pixels[p[1] * width + p[0]] = single ? color & 0xFF : colors[i] & 0xFF
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
    # @param tip [Boolean] Whether to include the line's final pixel. This
    #   is useful for when multiple lines are joined to form a polygonal line.
    # @return (see #initialize)
    # @raise [Exception::CanvasError] If the line would go out of bounds.
    # @todo Add support for anchors and anti-aliasing, better brushes, etc.
    def line(p1: nil, p2: nil, vector: nil, angle: nil,
      direction: nil, length: nil, color: 0, weight: 1, tip: true)
      # Determine start and end points
      raise Exception::CanvasError, "The line start must be specified." if !p1
      x0, y0 = p1
      if p2
        x1, y1 = p2
      else
        x1, y1 = Geometry.endpoint(
          point: p1, vector: vector, direction: direction,
          angle: angle, length: length
        )
      end
      bound_check(x0, y0)
      bound_check(x1, y1)

      # Normalize coordinates
      swap = (y1 - y0).abs > (x1 - x0).abs
      x0, x1, y0, y1 = y0, y1, x0, x1 if swap

      # Precompute useful parameters
      dx = x1 - x0
      dy = y1 - y0
      sx = dx < 0 ? -1 : 1
      sy = dy < 0 ? -1 : 1
      dx *= sx
      dy *= sy
      x, y = x0, y0
      s = [sx, sy]

      # If both endpoints are the same, draw a single point and return
      if dx == 0
        line_chunk(x0, y0, color, weight, swap)
        return self
      end

      # Rotate weight
      e_acc = 0
      e = ((dy << 16) / dx.to_f).round
      max = (dy <= 1 ? dx - 1 : dx + (weight / 2.0).to_i - 2) + (tip ? 1 : 0)
      weight *= (1 + (dy.to_f / dx) ** 2) ** 0.5

      # Draw line chunks
      0.upto(max) do |i|
        e_acc += e
        y += sy if e_acc > 0xFFFF unless i == 0 && e == 0x10000
        e_acc &= 0xFFFF
        w = 0xFF - (e_acc >> 8)
        brush_chunk(x, y, color, weight, swap)
        x += sx
      end

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
    # @return (see #initialize)
    # @raise [Exception::CanvasError] If the rectangle would go out of bounds.
    def rect(x, y, w, h, stroke, fill = nil, weight: 1)
      # Check coordinates
      x0, y0, x1, y1 = x, y, x + w - 1, y + h - 1
      bound_check(x0, y0)
      bound_check(x1, y1)

      # Fill rectangle, if provided
      if fill
        for x in (x0 .. x1)
          for y in (y0 .. y1)
            @pixels[y * @width + x] = fill
          end
        end
      end

      # Rectangle border
      line(p1: [x0, y0], p2: [x1, y0], color: stroke, weight: weight)
      line(p1: [x0, y1], p2: [x1, y1], color: stroke, weight: weight)
      line(p1: [x0, y0], p2: [x0, y1], color: stroke, weight: weight)
      line(p1: [x1, y0], p2: [x1, y1], color: stroke, weight: weight)

      self
    end

    private

    # Ensure the provided point is within the image's bounds.
    def bound_check(x, y)
      Geometry.bound_check([[x, y]], [0, 0, @width, @height])
    end

    # Draw one line chunk, used for Xiaolin-Wu line algorithm
    def line_chunk(x, y, color, weight = 1, swap = false)
      weight = 1.0 if weight < 1.0
      weight = weight.to_i
      min = - weight / 2 + 1
      max =   weight / 2

      w = min
      if !swap
        self[x, y + w] = color
        self[x, y + w] = color while (w += 1) < max
        self[x, y + w] = color if w <= max
      else
        self[y + w, x] = color
        self[y + w, x] = color while (w += 1) < max
        self[y + w, x] = color if w <= max
      end
    end

    def brush_chunk(x, y, color, weight = 1, swap = false)
      weight = 1.0 if weight < 1.0
      weight = weight.to_i
      x, y = y, x if swap
      cross_brush = [
        [ 0, -1],
        [-1,  0],
        [ 0,  0],
        [ 1,  0],
        [ 0,  1]
      ]
      two_by_two_brush = [
        [0, 0],
        [1, 0],
        [0, 1],
        [1, 1]
      ]
      two_by_two_brush.each{ |dx, dy| self[x + dx, y + dy] = color }
    end

  end
end
