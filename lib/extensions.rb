require_relative 'util.rb'

module Gifenc

  # Generic container for GIF extensions. Extensions were added in the second
  # and final specification of the GIF format in 1989, and implement additional
  # and extensible functionality to GIF files.
  class Extension

    # 1-byte field indicating the beginning of an extension block.
    EXTENSION_INTRODUCER = '!'

    # Create a new generic extension block.
    # @param label [Integer] Label of the extension, uniquely identifies the extension block.
    # @return [Extension] The newly created extension.
    def initialize(label)
      @label = label
    end

    # Encode the extension data to GIF format and write it to a stream.
    # @param stream [IO] Stream to write the data to.
    def encode(stream)
      stream << EXTENSION_INTRODUCER
      stream << @label # Extension Label
      stream << body   # Extension content
    end
  end

  # This extension precedes a frame, and mostly controls its duration, and thus, the
  # the framerate of the GIF. It can also specify a palette index to use as
  # transparent color, which means the pixel will remain the same color as the
  # previous frame. The other flags are hardly supported.
  class GraphicControlExtension < Extension
    LABEL = 0xF9

    def initialize(delay = 10, disposal: :none, user_input: false, transparency: false, trans_color: 0xFF)
      super(LABEL)

      # Packed flags
      @disposal     = [:none, :no, :bg, :prev].include?(disposal) ? disposal : :none
      @user_input   = user_input
      @transparency = transparency

      # Main params
      @delay   = delay & 0xFFFF
      @trans_color = trans_color & 0xFF
    end

    def body
      disposal = {
        none: 0,
        no:   1,
        bg:   2,
        prev: 3
      }[@disposal] || 0

      # Packed flags
      str = [
        (0                  & 0b111) << 5 |
        (disposal           & 0b111) << 2 |
        (@user_input.to_i   & 0b1  ) << 1 |
        (@transparency.to_i & 0b1  )
      ].pack('C')

      # Main params
      str += [@delay].pack('S<')
      str += [@trans_color].pack('C') if @transparency

      blockify(str)
    end
  end

  # This generic extension was added to the GIF specification to allow software
  # developers to inject their own features into the format. Only one became truly
  # standard, the Netscape extension (see below). It's a container in itself,
  # and the specific contents are the "data" method, which must be implemented
  # by any class that includes this module.
  class ApplicationExtension < Extension

    LABEL = 0xFF

    def initialize(id, code, data)
      super(LABEL)
      @id   = id   # Application Identifier
      @code = code # Application Authentication Code
      @data = data # Application Data
    end

    def body
      str = '0x0B' # Application id block size
      str += @id[0...8].ljust(8, '0x00')
      str += @code[0...3].ljust(3, '0x00')
      str += blockify(data)
      str
    end
  end

  # This is the only application extension that became the defacto standard. It's
  # what controls whether the GIF loops or not, and how many times.
  class NetscapeExtension < ApplicationExtension

    def initialize(loops = 0)
      @loops = loops & 0xFFFF # Amount of loops (0 = infinite)
    end

    # Note: We do not add the block size or null terminator here, since it will
    # be blockified later
    def data
      str = '0x01' # Sub-block ID
      str += [@loops].pack('S<')
      str
    end
  end
end