require_relative 'image.rb'
require_relative 'extensions.rb'

module Gifenc

  # Represents a GIF file, possibly composed of multiple images / frames.
  class Gif
    # Creates a new GIF object.
    # @param width  [Integer] Width of the logical screen in pixels.
    # @param height [Integer] Height of the logical screen in pixels.
    # @param bg     [Integer] Index of background color in the Global Color Table.
    # @param loops  [Integer] Amount of times to loop the GIF (-1 = infinite).
    # @param delay  [Integer] Default delay between frames, in 1/100ths of a second.
    # @param fps    [Integer] Frames per second, will only be used to approximate the real delay if no explicit delay was given.
    def initialize(width, height, bg: 0, loops: -1, delay: nil, fps: 10)
      # Main GIF params
      @width  = width
      @height = height
      @bg     = bg
      @ar     = 0      # Pixel aspect ratio (unused -> square)
      @depth  = 8      # Color depth per channel in bits
  
      # Global Color Table and flags
      @gct_flag  = true  # Global color table present
      @gct_sort  = false # Colors in GCT not ordered by importance
      @gct_size  = 0     # Number of colors in GCT (0 - 256, power of 2)
      @gct = []
  
      # Extension params
      @loops = loops
      @delay = delay
      @fps   = fps
  
      # Main GIF elements
      @frames     = []
      @extensions = []
  
      # If we want the GIF to loop, then add the Netscape Extension
      if @loops != 0
        loops = @loops == -1 ? 0 : @loops
        @extensions << NetscapeExtension.new(loops)
      end
    end

    # Encode all the data as a GIF file and write it to a stream.
    # @param stream [IO] Stream to write the data to.
    def encode(stream, delay: 4)
      # Header
      stream << HEADER

      # Logical Screen Descriptor
      stream << [@width, @height].pack('S<2')
      size = @gct_size < 2 ? 0 : Math.log2(@gct_size - 1).to_i
      stream << [
        (@gct_flag.to_i & 0b1  ) << 7 |
        (@gct_depth - 1 & 0b111) << 4 |
        (@gct_sort.to_i & 0b1  ) << 3 |
        (size           & 0b111)
      ].pack('C')
      stream << [@bg, @ar].pack('C2')

      # Global Color Table
      @gct.each{ |c|
        stream << [c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF].pack('C3')
      } if @gct_flag

      # Global extensions
      @extensions.each{ |e| e.encode(stream) }

      # Encode frames containing image data (and local extensions)
      @frames.each{ |f| f.encode(stream) }

      # Trailer
      stream << TRAILER
    rescue => e
      lex(e, 'Failed to encode GIF')
      nil
    end

    # Encode and write the GIF to a string.
    # @return [String] The string containing the encoded GIF file.
    def write
      str = StringIO.new
      str.set_encoding("ASCII-8BIT")
      encode(str)
      str.string
    end

    # Encode and write the GIF to a file.
    # @param filename [String] Name of the output file.
    def save(filename)
      File.open(filename, 'wb') do |f|
        encode(f)
      end
    end
  end
end