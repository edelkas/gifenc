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
      stream << @label.chr # Extension label
      stream << body       # Extension content
    end

    # This extension precedes a *single* image and controls several of its rendering
    # charactestics, such as its duration and the transparent color index. A
    # complete description, mostly adapted from the specification, follows:
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
    #
    # Note that, in reality, most software does not perfectly conform to this
    # standard. Notably, the user input flag is mostly ignored, and very small
    # delays are changed to a higher value (see {#delay}). Also, disposal methods
    # 2 and 3 are sometimes not supported either.
    class GraphicControl < Extension

      # Label identifying a Graphic Control Extension block.
      LABEL = 0xF9

      # Specifies the time, in 1/100ths of a second, to leave this image onscreen
      # before moving on to rendering the next one in the GIF. Must be between
      # 0 and 65535. If `0`, processing of the GIF should continue immediately.
      # In reality, however, programs almost never comply with this standard, and
      # instead normalize very small delays up to a certain, slower value. For
      # instance, in most browsers, values smaller than 2 (i.e. 0 and 1) will be
      # changed to 10, resulting in the fastest possible speed being attained
      # with a delay of 2 (20ms, or 50fps).
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
      #
      # Note that support for all disposal methods might be incomplete in some
      # pieces of software. The most limited programs only support method 1.
      # @return [Integer] Disposal method.
      attr_accessor :disposal

      # Index in the color table of the color to render as transparent. If
      # specified, the transparency flag in the GIF will be set by default.
      # Whatever is in the background (e.g. the background color, or a previous
      # frame, see {#disposal}) will the show through the transparent pixels of
      # the current image. To disable transparency, simply set this to `nil`.
      # @return [Integer] Index of transparent color.
      attr_accessor :trans_color

      # Whether or not user input is required to continue onto the next image.
      # @note This flag is ignored by most decoders nowadays, instead just
      #   displaying all images continuously according to the delay.
      # @return [Boolean] User input flag.
      attr_accessor :user_input

      # Create a new Graphic Control Extension associated to a particular image.
      # @param delay [Integer] Number of 1/100ths of a second (0-65535) to wait
      #   before rendering next image in the GIF file. Beware that most software
      #   does not support ultra fast GIFs (see {#delay}).
      # @param disposal [Integer] The disposal method (0-7) indicates how to
      #   dispose of this image before displaying the next one (see {#disposal}).
      # @param trans_color [Integer] Color table index (0-255) of the color that
      #   should be used as the transparent color. The transparent color maintains
      #   whatever color was present in that pixel before rendering this image
      #   (see {#trans_color}).
      # @param user_input [Boolean] Whether or not user input is expected to
      #   continue rendering the subsequent GIF images (mostly deprecated flag).
      # @return [GraphicControl] The newly created Graphic Control
      #   Extension block.
      def initialize(
          delay:        DEFAULT_DELAY,
          disposal:     DEFAULT_DISPOSAL,
          trans_color:  nil,
          user_input:   DEFAULT_USER_INPUT
        )
        super(LABEL)

        @disposal     = (0..7).include?(disposal) ? disposal : DEFAULT_DISPOSAL
        @user_input   = user_input
        @delay        = (0..0xFFFF).include?(delay) ? delay : DEFAULT_DELAY
        @trans_color  = (0..0xFF).include?(trans_color) ? trans_color : nil
      end

      # Encode the extension block as a 6-byte binary string, as it will appear
      # in the actual GIF file.
      # @return [String] The encoded extension block.
      def body
        # Packed flags
        flags = [
          (0                               & 0b111) << 5 |
          ((@disposal || DEFAULT_DISPOSAL) & 0b111) << 2 |
          ((@user_input    ? 1 : 0)        & 0b1  ) << 1 |
          ((!!@trans_color ? 1 : 0)        & 0b1  )
        ].pack('C')
        trans_color = !@trans_color ? DEFAULT_TRANS_COLOR : @trans_color

        # Main params
        str = "\x04"                   # Block size (always 4 bytes)
        str += flags                   # Packed fields
        str += [@delay].pack('S<')     # Delay time
        str += [trans_color].pack('C') # Transparent index
        str += BLOCK_TERMINATOR

        str
      end

      # Create a duplicate copy of this graphic control extension.
      # @return [GraphicControl] The new extension object.
      def dup
        GraphicControl.new(
          delay:       @delay,
          disposal:    @disposal,
          trans_color: @trans_color,
          user_input:  @user_input
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
    class Application < Extension

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
      # @return [Application] The newly created Application Extension
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
        "\x0B" + id + code + Util.blockify(data)
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
    class Netscape < Application

      # The amount of times to loop the GIF. Must be between 0 and 65535, where
      # 0 indicates to loop indefinitely.
      # @return [Integer] Loop count.
      attr_accessor :loops

      # Create a new Netscape Extension block.
      # @param loops [Integer] Times (0-65535) to loop the GIF (`0` = infinite).
      # @return [Netscape] The newly created Netscape Extension block.
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
      # @return [Netscape] The new extension object.
      def dup
        Netscape.new(@loops)
      end
    end
  end
end