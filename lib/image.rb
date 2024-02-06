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
      @pixels    = [color] * (width * height)

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
  end
end