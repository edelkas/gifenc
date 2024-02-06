require_relative 'image.rb'
require_relative 'extensions.rb'

module Gifenc

  # Represents a GIF file, possibly composed of multiple images. Note that each
  # image in a GIF file is not necessarily an animation frame, they could also be
  # still images that should be layered on top of each other.
  class Gif
    # Creates a new GIF object.
    # @param width  [Integer] Width of the logical screen (canvas) in pixels.
    # @param height [Integer] Height of the logical screen (canvas) in pixels.
    # @param gct    [GlobalColorTable] The global color table of the GIF. This
    #   represents the default palette of all the images in the GIF, and contains
    #   the colors that can be used in them (at most 256). Each image can
    #   override this with a local color table. See {ColorTable} for more details
    #   and a list of default palettes.
    # @param loops  [Integer] Amount of times (0-65535) to loop the GIF.
    #   (`-1` = loop indefinitely).
    # @param delay  [Integer] Default delay between frames, in 1/100ths of a second.
    #   This setting can be overridden for each individual frame, thus obtaining
    #   a variable framerate. Beware that most programs do not support the
    #   smallest delays (e.g. <5).
    # @param fps    [Integer] Frames per second of the GIF. This setting will
    #   only be used to approximate the real delay if **no** explicit delay was
    #   given.
    # @param bg     [Integer] Index of the background color in the Global Color
    #   Table. This should be the color of the parts of the canvas not covered
    #   by any image. **Note**: This field is ignored by most decoders, which
    #   instead render the background transparent.
    # @param ar     [Integer] Aspect ratio of the pixels. If provided (`ar > 0`),
    #   the aspect ratio is calculated as (ar + 15) / 64, which allows for ratios
    #   roughly between 1:4 and 4:1 in increments of 1/64th. `0` means square
    #   pixels. **Note**: This field is ignored by most decoders, which instead
    #   just render all pixels square.
    def initialize(width, height, gct: nil, loops: -1, delay: nil, fps: 10, bg: 0, ar: 0)
      # GIF attributes
      @width  = width
      @height = height
      @bg     = bg
      @ar     = ar
      @gct    = gct
  
      # GIF content data
      @images     = []
      @extensions = []

      # Extension params
      @loops = loops
      @delay = delay
      @fps   = fps
  
      # If we want the GIF to loop, then add the Netscape Extension
      if @loops != 0
        loops = @loops == -1 ? 0 : @loops
        @extensions << NetscapeExtension.new(loops)
      end
    end

    # Encode all the data as a GIF file and write it to a stream.
    # @param stream [IO] Stream to write the data to.
    def encode(stream)
      # Header
      stream << HEADER

      # Logical Screen Descriptor
      stream << [@width, @height].pack('S<2')
      stream << [@color_table.global_flags].pack('C') if @color_table
      stream << [@bg, @ar].pack('C2')

      # Global Color Table
      @color_table.encode(stream) if @color_table

      # Global extensions
      @extensions.each{ |e| e.encode(stream) }

      # Encode frames containing image data (and local extensions)
      @images.each{ |f| f.encode(stream) }

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