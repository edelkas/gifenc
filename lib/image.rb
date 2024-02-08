require 'lzwrb'
require_relative 'util.rb'

module Gifenc
  # Represents a single image. A GIF may contain multiple images, and they need
  # not be animation frames (they could simply be tiles of a static image).
  # Crucially, images can be smaller than the GIF logical screen (canvas), thus
  # being placed at an offset of it, saving space and time, and allowing for more
  # complex compositions.
  class Image

    # Contains the table based image data (the color indexes for each pixel).
    attr_accessor :pixels

    # Create a new image or frame.
    # @param width [Integer] Width of the image in pixels.
    # @param height [Integer] Height of the image in pixels.
    # @param x [Integer] Horizontal offset of the image in the logical screen.
    # @param y [Integer] Vertical offset of the image in the logical screen.
    # @param color [Integer] The initial color of the canvas.
    # @param delay [Integer] Time, in 1/100ths of a second, to wait before displaying the next image.
    # @param trans_color [Integer] Index of color to use as transparent color.
    # @param interlace [Boolean] Whether the pixel data of this image is interlaced or not.
    # @param lct [ColorTable] Add a Local Color Table to this image, overriding the global one.
    def initialize(width, height, x = 0, y = 0, color: 0, delay: nil, trans_color: nil, interlace: false, lct: nil)
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
      @delay       = delay
      @trans_color = trans_color
      @extensions  = []

      if !@delay.nil? || !@trans_color.nil?
        @extensions << GraphicControlExtension.new(
          delay:        @delay,
          transparency: !@trans_color.nil?,
          trans_color:  @trans_color
        )
      end
    end

    # Encode the image data to GIF format and write it to a stream.
    # @param stream [IO] Stream to write the data to.
    def encode(stream)
      # Optional extensions go before the image data
      stream << @extensions.each{ |e| e.encode(stream) }

      # Image descriptor
      stream << ','
      stream << [@x, @y, @width, @height].pack('S<4')
      flags = (@interlace ? 1 : 0) << 6
      flags |= @lct.local_flags if @lct
      stream << [flags].pack('C')

      # Local Color Table
      @lct.encode(stream) if @lct

      # LZW-compressed image data
      min_bits = @lct ? @lct.real_size : 8
      stream << min_bits.chr
      lzw = LZWrb.new(preset: LZWrb::PRESET_GIF, min_bits: min_bits)
      stream << Util.blockify(lzw.encode(@pixels.pack('C*')))
    end

    # Extend the current image with the specified local extension. There are
    # several reasons why this could fail (if the specified extension is global,
    # or if the image already has one of a kind that must be unique).
    # @param extension [Extension] The extension to apply to this image.
    # @param quiet [Boolean] On failure, whether to raise an exception or just
    #   return gracefully.
    # @return [Boolean] Whether the extension of the image was successful or not.
    #   If `quiet = false`, this will always be `true`, as otherwise an exception
    #   is raised.
    def extend(extension, quiet: false)
      if extension.is_a?(GraphicControlExtension) &&
        @extensions.any?{ |e| e.is_a?(GraphicControlExtension) }
        return false if quiet
        raise ExtensionError, "Cannot extend, image already has a Graphic\
          Control Extension."
      end
      if extension.is_a?(ApplicationExtension)
        return false if quiet
        raise ExtensionError, "Application extensions have a global scope, they\
          must be assigned to the whole GIF object, not individual images."
      end
      @extensions << extension
      true
    end

    # Create a duplicate copy of this image.
    # @return [Image] The new image.
    def dup
      lct = @lct ? @lct.dup : nil
      image = Image.new(
        @width, @height, @x, @y, color: @color, delay: @delay,
        trans_color: @trans_color, interlace: @interlace, lct: lct
      )
      @extensions.each{ |e| image.extend(e.dup, quiet: true) }
    end

    # Move the image to a different origin of coordinates.
    # @param x [Integer] New origin horizontal coordinate.
    # @param y [Integer] New origin vertical coordinate.
    def move(x, y)
      @x = x
      @y = y
    end

    # Get the value (color _index_) of a pixel **fast** (i.e. without bound
    # checks). For the safe version, see {#get}.
    # @param x [Integer] The X coordinate of the pixel.
    # @param y [Integer] The Y coordinate of the pixel.
    # @return [Integer] The color index of the pixel.
    def [](x, y)
      @pixels[x * width + y]
    end

    # Set the value (color _index_) of a pixel **fast** (i.e. without bound
    # checks). For the safe version, see {#set}.
    # @param x [Integer] The X coordinate of the pixel.
    # @param y [Integer] The Y coordinate of the pixel.
    # @param color [Integer] The new color index of the pixel.
    # @return [Integer] The new color index of the pixel.
    def []=(x, y, color)
      @pixels[x * width + y] = color & 0xFF
    end

    # Get the value (color _index_) of a pixel **safely** (i.e. with bound
    # checks). For the fast version, see {#[]}.
    # @param (see #[])
    # @return (see #[])
    def get(x, y)
      check_bounds(x, y)
      @pixels[x * width + y]
    end

    # Set the value (color _index_) of a pixel **safely** (i.e. with bound
    # checks). For the fast version, see {#[]=}.
    # @param (see #[]=)
    # @return (see #[]=)
    def set(x, y, color)
      check_bounds(x, y)
      @pixels[x * width + y] = color & 0xFF
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
    end

    # Draw a rectangle with border and optional fill.
    # @param x      [Integer] X coordinate of the top-left vertex.
    # @param y      [Integer] Y coordinate of the top-left vertex.
    # @param w      [Integer] Width of the rectangle in pixels.
    # @param h      [Integer] Height of the rectangle in pixels.
    # @param stroke [Integer] Index of the border color.
    # @param fill   [Integer] Index of the fill color (`nil` for no fill).
    # @param width  [Integer] Stroke width of the border in pixels.
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
    end

    private

    def check_bounds(x, y)
      if !x.between?(0, @width) || !y.between?(0, @height)
        raise CanvasError, "Out of bounds: Pixel (#{x}, #{y}) doesn't exist."
      end
    end
  end
end
