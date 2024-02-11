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

    # Create a new image or frame.
    # @param width [Integer] Width of the image in pixels.
    # @param height [Integer] Height of the image in pixels.
    # @param x [Integer] Horizontal offset of the image in the logical screen.
    # @param y [Integer] Vertical offset of the image in the logical screen.
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
        width,
        height,
        x = 0,
        y = 0,
        color:       DEFAULT_COLOR,
        gce:         nil,
        delay:       nil,
        trans_color: nil,
        disposal:    nil,
        interlace:   DEFAULT_INTERLACE,
        lct:         nil
      )
      # Image attributes
      @width     = width
      @height    = height
      @x         = x
      @y         = y
      @lct       = lct
      @interlace = interlace

      # Image data
      @color     = color
      @pixels    = [@color] * (width * height)

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
      stream << @gce.encode(stream) if @gce

      # Image descriptor
      stream << ','
      stream << [@x, @y, @width, @height].pack('S<4')
      flags = (@interlace ? 1 : 0) << 6
      flags |= @lct.local_flags if @lct
      stream << [flags].pack('C')

      # Local Color Table
      @lct.encode(stream) if @lct

      # LZW-compressed image data
      min_bits = @lct ? @lct.bit_size : 8
      stream << min_bits.chr
      lzw = LZWrb.new(preset: LZWrb::PRESET_GIF, min_bits: min_bits)
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
    # @raise [CanvasError] If the supplied pixel data length doesn't match the
    #   canvas's current dimensions.
    # @return (see #initialize)
    def replace(pixels)
      if pixels.size != @width * @height
        raise CanvasError, "Pixel data doesn't match image dimensions. Please\
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
    # @raise [CanvasError] If we're placing the image out of bounds.
    # @todo We're only checking negative out of bounds, what about positive ones?
    def place(x, y)
      raise CanvasError, "Cannot move image, out of bounds." if @x < 0 || @y < 0
      @x = x
      @y = y
      self
    end

    # Move the image relative to the current position.
    # @param x [Integer] X displacement.
    # @param y [Integer] Y displacement.
    # @return (see #initialize)
    # @see #place
    # @raise [CanvasError] If the movement would place the image out of bounds.
    # @todo We're only checking negative out of bounds, what about positive ones?
    def move(x, y)
      raise CanvasError, "Cannot move image, out of bounds." if @x < -x || @y < -y
      @x += x
      @y += y
      self
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
    # @raise [CanvasError] If any of the specified points is out of bounds.
    def get(points)
      check_bounds(points.min_by(&:first)[0], points.min_by(&:last)[1])
      check_bounds(points.max_by(&:first)[0], points.max_by(&:last)[1])
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
    # @raise [CanvasError] If any of the specified points is out of bounds.
    def set(points, colors)
      check_bounds(points.min_by(&:first)[0], points.min_by(&:last)[1])
      check_bounds(points.max_by(&:first)[0], points.max_by(&:last)[1])
      single = colors.is_a?(Integer)
      points.each_with_index{ |p, i|
        @pixels[p[1] * width + p[0]] = single ? color & 0xFF : colors[i] & 0xFF
      }
      self
    end

    # Draw a straight line connecting 2 points.
    # @param x0     [Integer] X coordinate of first point.
    # @param y0     [Integer] Y coordinate of first point.
    # @param x1     [Integer] X coordinate of second point.
    # @param y1     [Integer] Y coordinate of second point.
    # @param color  [Integer] Index of the color of the line.
    # @param width  [Integer] Width of the line in pixels.
    # @param anchor [Symbol]  For lines with `width > 1`, specifies what part of
    #   the line the coordinates are referencing (top, bottom, center...).
    # @return (see #initialize)
    # @raise [CanvasError] If the line would go out of bounds.
    # @todo Add support for arbitrary lines, widths, and even basic anti-aliasing.
    def line(x0, y0, x1, y1, color, width: 1, anchor: :c)
      check_bounds(x0, y0)
      check_bounds(x1, y1)

      if x0 == x1    # Vertical
        y0, y1 = y1, y0 if y0 > y1
        for y in (y0 .. y1)
          @pixels[y * width + x0] = color
        end
      elsif y0 == y1 # Horizontal
        x0, x1 = x1, x0 if x0 > x1
        for x in (x0 .. x1)
          @pixels[y0 * width + x] = color
        end
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
    # @param width  [Integer] Stroke width of the border in pixels.
    # @return (see #initialize)
    # @raise [CanvasError] If the rectangle would go out of bounds.
    def rect(x, y, w, h, stroke, fill = nil, width: 1)
      # Check coordinates
      x0, y0, x1, y1 = x, y, x + w - 1, y + h - 1
      check_bounds(x0, y0)
      check_bounds(x1, y1)

      # Fill rectangle, if provided
      if fill
        for x in (x0 .. x1)
          for y in (y0 .. y1)
            @pixels[y * width + x] = fill
          end
        end
      end

      # Rectangle border
      line(x0, y0, x1, y0, stroke, width: width)
      line(x0, y1, x1, y1, stroke, width: width)
      line(x0, y0, x0, y1, stroke, width: width)
      line(x1, y0, x1, y1, stroke, width: width)

      self
    end

    private

    def check_bounds(x, y)
      if !x.between?(0, @width) || !y.between?(0, @height)
        raise CanvasError, "Out of bounds: Pixel (#{x}, #{y}) doesn't exist."
      end
    end
  end
end
