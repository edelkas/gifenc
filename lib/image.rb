require 'lzwrb'
require_relative 'util.rb'

module Gifenc
  # Represents a single image. A GIF may contain multiple images, and they need
  # not be animation frames (they could simply be tiles of a static image).
  # Crucially, images can be smaller than the GIF logical screen (canvas), thus
  # being placed at an offset of it, saving space and time, and allowing for more
  # complex compositions.
  class Image

    # Create a new image or frame,
    # @param width [Integer] Width of the image in pixels
    # @param height [Integer] Height of the image in pixels
    # @param x [Integer] Horizontal offset of the image in the logical screen
    # @param y [Integer] Vertical offset of the image in the logical screen
    # @param delay [Integer] Time, in 1/100ths of a second, to wait before displaying the next image.
    # @param trans_color [Integer] Index of color to use as transparent color.
    def initialize(width, height, x = 0, y = 0, delay: nil, trans_color: nil)
      # Basic characteristics
      @width  = width
      @height = height
      @x      = x
      @y      = y

      # Local Color Table and flags
      @lct_flag  = false # Local color table not present
      @lct_sort  = false # Colors in LCT not ordered by importance
      @lct_size  = 0     # Number of colors in LCT (0 - 256, power of 2)
      @lct       = []

      @interlace = false # No interlacing
      @pixels = []

      # Extended features
      @delay = delay             # Delay between this frame and the next (in 1/100ths of sec)
      @trans_color = trans_color # Transparent color (keeps pixel from previous frame)
      @extensions = []           # Extensions local to this image

      if !@delay.nil? || !@trans_color.nil?
        @extensions << GraphicControlExtension.new(
          @delay,
          transparency: !@trans_color.nil?,
          trans_color: @trans_color
        )
      end
    end

    # Set the values of the pixels
    def set(pixels)

    end

    # Encode the image data to GIF format and write it to a stream.
    # @param stream [IO] Stream to write the data to.
    def encode(stream)
      # Optional extensions go before the image data
      stream << @extensions.each{ |e| e.encode(stream) }

      # Image descriptor
      stream << ','
      stream << [@x, @y, @width, @height].pack('S<4')
      size = @lct_size < 2 ? 0 : Math.log2(@lct_size - 1).to_i
      stream << [
        (@lct_flag.to_i & 0b1  ) << 7 |
        (@interlace     & 0b1  ) << 6 |
        (@lct_sort      & 0b1  ) << 5 |
        (0              & 0b11 ) << 3 |
        (size           & 0b111)
      ].pack('C')

      # Local Color Table
      @lct.each{ |c|
        stream << [c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF].pack('C3')
      } if @lct_flag

      # LZW-compressed image data
      # TODO: Add data here
    end
  end
end