module Gifenc

  # Generic container for GIF extensions. Extensions were added in the second
  # and final specification of the GIF format in 1989, and implement additional
  # and extensible functionality to GIF files.
  # @todo Add support for the _Plain Text Extension_ and the _Comment Extension_.
  class Extension

    # 1-byte field indicating the beginning of an extension block.
    EXTENSION_INTRODUCER = '!'

    # Create a new generic extension block.
    # @param label [Integer] Label of the extension, uniquely identifies the type of extension.
    # @return [Extension] The newly created extension.
    def initialize(label)
      @label = label
    end

    # Encode the extension data to GIF format and write it to a stream.
    # @param stream [IO] Stream to write the data to.
    def encode(stream)
      stream << EXTENSION_INTRODUCER
      stream << @label # Extension label
      stream << body   # Extension content
    end

    # This extension precedes a *single* image and controls several of its rendering
    # charactestics, such as its duration and the transparent color index. A
    # complete description, adapted from the specification, follows:
    # - **Disposal method** (*3 bits*): Indicates in which way should be image be
    #   disposed of before displaying the next one.
    #   * 0 - No disposal specified. This image will be fully replaced by the next
    #         one without transparency.
    #   * 1 - Do not dispose. The image will remain onscreen, and the next one
    #         will be drawn on top, with the old one showing through the transparent
    #         pixels of the new one.
    #   * 2 - Restore to background color. The image will be fully replaced by the
    #         background color, over which the next image will be drawn.
    #   * 3 - Restore to previous. The previous undisposed image will be restored,
    #         and the next one will be drawn over it. Useful for animating over
    #         a fixed background.
    #   * 4-7 - Undefined.
    # - **User input flag** (*1 bit*): Indicates whether or not user input is
    #   required before continuing with the next image in the GIF. The nature of
    #   the User input is determined by the application (Carriage Return, Mouse
    #   Button Click, etc.).
    #   * 0 - User input is not expected.
    #   * 1 - User input is expected.
    # - **Transparency flag** (*1 bit*): Indicates whether or not a color will be
    #   specified in the Transparent Index field as the transparent color.
    #   * 0 - Transparent Index is not given.
    #   * 1 - Transparent Index is given.
    # - **Delay Time** (*2 bytes*): If not 0, this field specifies the number of
    #   hundredths (1/100) of a second to wait before continuing with the processing
    #   of the Data Stream. The clock starts ticking immediately after the graphic
    #   is rendered. This field may be used in conjunction with the User Input Flag
    #   field.
    # - **Transparency Index** (*1 byte*): The Transparency Index is such that when
    #   encountered, the corresponding pixel of the display device is not
    #   modified and processing goes on to the next pixel. This is done if and
    #   only if the Transparency Flag is set to 1.
    class GraphicControlExtension < Extension

      # Label identifying a Graphic Control Extension block.
      LABEL = 0xF9

      # Specifies the time, in 1/100ths of a second, to leave this image onscreen
      # before moving on to rendering the next one in the GIF. If `0`, processing
      # of the GIF continues immediately.
      # @return [Integer] Time to leave image onscreen.
      attr_accessor :delay

      # The disposal method (0-3) to use for this image before displaying the
      # next one.
      # * `0` : No disposal specified. This image will be fully replaced by the
      #         next one without transparency.
      # * `1` : Do not dispose. The image will remain onscreen, and the next one
      #         will be drawn on top, with the old one showing through the
      #         transparent pixels of the new one.
      # * `2` : Restore to background color. The image will be fully replaced by
      #         the background color, over which the next image will be drawn.
      # * `3` : Restore to previous. The previous undisposed image will be
      #         restored, and the next one will be drawn over it. Useful for
      #         animating over a fixed background.
      # @return [Integer] Disposal method.
      attr_accessor :disposal

      # Whether or not this image has a color that will be rendered transparent.
      # By default, this is set to `true` if a color is provided in the
      # {#trans_color} field, and `false` otherwise.
      # @return [Boolean] Transparency flag.
      # @see #trans_color
      attr_accessor :transparency

      # Index in the color table of the color to render as transparent. If
      # specified, the {#transparency} flag will be set to `true` by default.
      # Whatever is in the background (as specified by the {#disposal} flag of
      # the previous frames) will show through the transparent pixels of the
      # current image.
      # @return [Integer] Index of transparent color.
      # @see #transparency
      attr_accessor :trans_color

      # Whether or not user input is required to continue onto the next image.
      # @note This flag is ignored by most decoders nowadays, instead just
      #   displaying all images continuously according to the delay.
      # @return [Boolean] User input flag.
      attr_accessor :user_input

      # Create a new Graphic Control Extension associated to a particular image.
      # @param delay [Integer] Number of 1/100ths of a second (0-65535) to wait
      #   before rendering next image in the GIF file. Beware that most software
      #   does not support ultra fast GIFs (e.g. very low delays).
      # @param disposal [Integer] The disposal method (0-7) indicates how to
      #   dispose of this image before displaying the next one (see {#disposal}).
      # @param trans_color [Integer] Color table index (0-255) of the color that
      #   should be used as the transparent color. The transparent color maintains
      #   whatever color was present in that pixel before rendering this image.
      # @param transparency [Boolean] Whether a transparent color is supplied.
      #   Normally you **don't** want to set this argument manually, as it will be
      #   set to `true` or `false` automatically depending on whether or not a
      #   transparent color has been supplied. This argument is used to manually
      #   override the value of this field.
      # @param user_input [Boolean] Whether or not user input is expected to
      #   continue rendering the subsequent GIF images (mostly deprecated flag).
      # @return [GraphicControlExtension] The newly created Graphic Control
      #   Extension block.
      def initialize(
          delay:        10,
          disposal:     DISPOSAL_NONE,
          trans_color:  nil,
          transparency: nil,
          user_input:   false
        )
        super(LABEL)

        @disposal     = (0...8).include?(disposal) ? disposal : DISPOSAL_NONE
        @user_input   = user_input
        @transparency = !transparency.nil? ? transparency : !trans_color.nil?
        @delay        = delay & 0xFFFF
        @trans_color  = (trans_color || 0x00) & 0xFF
      end

      # Encode the extension block as a 6-byte binary string, as it will appear
      # in the actual GIF file.
      # @return [String] The encoded extension block.
      def body
        # Packed flags
        flags = [
          (0                       & 0b111) << 5 |
          (@disposal               & 0b111) << 2 |
          ((@user_input   ? 1 : 0) & 0b1  ) << 1 |
          ((@transparency ? 1 : 0) & 0b1  )
        ].pack('C')

        # Main params
        str = '\x04'                     # Block size (always 4 bytes)
        str += flags                     # Packed fields
        str += [@delay].pack('S<')       # Delay time
        str += [@trans_color].pack('C')  # Transparent index
        str += BLOCK_TERMINATOR

        str
      end

      # Create a duplicate copy of this graphic control extension.
      # @return [GraphicControlExtension] The new extension object.
      def dup
        GraphicControlExtension.new(
          delay:        @delay,
          disposal:     @disposal,
          trans_color:  @trans_color,
          transparency: @transparency,
          user_input:   @user_input
        )
      end
    end

    # This generic extension was added to the GIF specification to allow software
    # developers to inject their own features into the format. Only one became truly
    # standard, the Netscape extension, which introduced GIF looping.
    # An Application Extension is a container in itself, and the specific contents are to
    # be defined in the `data` method, which must be implemented by any subclass.
    # The structure of this extension block, as per the GIF specification, is
    # the following:
    # - **Application Identifier** (*8 bytes*): Sequence of ASCII characters used
    #   to identify the application owning this extension.
    # - **Application Authentication Code** (*3 bytes*): Used to authenticate the
    #   Application Identifier. An Application program may use an algorithm to
    #   compute a binary code that uniquely identifies it as the application owning
    #   the Application Extension.
    # - **Application Data**: The actual contents of the extension block, specific
    #   to each type of application extension.
    class ApplicationExtension < Extension

      # Label identifying an Application Extension block.
      LABEL = 0xFF

      # Application identifier. Must be an 8 character ASCII string.
      # @return [String] The identifier string.
      attr_accessor :id

      # Application authentication code. Must be an arbitrary 3-byte binary string.
      # It was originally intended as a way for applications to validate the
      # extension, but is in practice just a suffix of the identifier.
      # @return [String] The authentication string.
      attr_accessor :code

      # Create a new generic Application Extension block.
      # @param id [String] The Application Identifier. Should be an 8 character
      #   ASCII string (note that it will be converted to ASCII and truncated and
      #   padded to 8 characters during encoding).
      # @param code [String] The Application Authentication Code. Should be a 3
      #   character binary string (note that it will be truncated and padded to
      #   3 characters during encoding).
      # @return [ApplicationExtension] The newly created Application Extension
      #   block.
      def initialize(id, code)
        super(LABEL)
        @id   = id   # Application Identifier
        @code = code # Application Authentication Code
      end

      # Encode the extension block as a binary string (id + code + data), as it
      # will appear in the actual GIF file.
      # @return [String] The encoded extension block.
      def body
        # Sanitize fields
        id   = @id.force_encoding('US-ASCII').scrub[0...8].ljust(8, "\x00")
        code = @code[0...3].ljust(3, "\x00")

        # Build string
        "\x0B" + id + code + blockify(data)
      end
    end

    # This is the only Application Extension block that is widely supported,
    # so much so that it became a defacto standard.
    # It controls whether the GIF should loop or not, and if so, how many times.
    # It need only appear once in the GIF file, and for maximum compatibility, it
    # should be the very first extension block in the GIF file (i.e., it should
    # appear right after the Global Color Table). Structure:
    # - **Sub-block ID** (*1 byte*): Identifies the sub-block (always 1).
    # - **Loop count** (*2 bytes*): Number of iterations (0-65535) the GIF should
    #   be looped. A count of 0 means loop indefinitely.
    class NetscapeExtension < ApplicationExtension

      # The amount of times to loop the GIF. Must be between 0 and 65535, where
      # 0 indicates to loop indefinitely.
      # @return [Integer] Loop count.
      attr_accessor :loops

      # Create a new Netscape Extension block.
      # @param loops [Integer] Times (0-65535) to loop the GIF (`0` = infinite).
      # @return [NetscapeExtension] The newly created Netscape Extension block.
      def initialize(loops = 0)
        super('NETSCAPE', '2.0')
        @loops = loops.clamp(0, 2 ** 16 - 1)
      end

      # Data of the actual extension as a 3-byte binary string.
      # @return [String] The raw application data.
      def data
        # Note: We do not add the block size or null terminator here, since it will
        # be blockified later.
        "\x01" + [@loops & 0xFFFF].pack('S<')
      end

      # Create a duplicate copy of this Netscape extension.
      # @return [NetscapeExtension] The new extension object.
      def dup
        NetscapeExtension.new(@loops)
      end
    end
  end
end