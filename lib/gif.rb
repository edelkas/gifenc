module Gifenc

  # Represents a GIF file, possibly composed of multiple images. Note that each
  # image in a GIF file is not necessarily an animation frame, they could also be
  # still images that should be layered on top of each other.
  class Gif

    # 6-byte block indicating the beginning of the GIF data stream.
    # It is composed of the signature (GIF) and the version (89a).
    HEADER = 'GIF89a'

    # 1-byte block indicating the termination of the GIF data stream.
    TRAILER = ';'

    # The width of the GIF's logical screen, i.e., its canvas. To resize it, use
    # the {#resize} method.
    # @return [Integer] Width of the logical screen in pixels.
    # @see #resize
    attr_reader :width

    # The height of the GIF's logical screen, i.e., its canvas. To resize it, use
    # the {#resize} method.
    # @return [Integer] Width of the logical screen in pixels.
    # @see #resize
    attr_reader :height

    # The Global Color Table. This represents the default palette of all the
    # images in the GIF. In other words, all colors in all images are indexed in
    # this table, unless a local table is explicitly provided for an image, in
    # which case it overrides the global one. A color table may contain up to
    # 256 colors. See {ColorTable} for more details and a list of default palettes.
    # @note Changing this table _after_ images have already been created with it
    #   will NOT update their color indices, which will thus corrupt them in the
    #   final encoded GIF.
    # @return [ColorTable] The global color table.
    attr_accessor :gct

    # The default color of the GIF's images. This color is used to initialize
    # new blank images, as well as to pad images when they are resized to a bigger
    # size. This can be overriden individually for each image.
    # @return [Integer] Index of the default image color.
    attr_accessor :color

    # The default delay to use between images, in 1/100ths of a second. See
    # {Extension::GraphicControl#delay} for details about its implementation.
    # This can be overriden individually for each image.
    # @return [Integer] Delay beween frames.
    attr_accessor :delay

    # The index of the default color to use as transparent. For details about
    # how transparency works in GIF files, see {Extension::GraphicControl#trans_color}.
    # This can be overriden individually for each image.
    # @return [Integer] Index of the default transparent color.
    attr_accessor :trans_color

    # The default disposal method to use for every image in the GIF. The disposal
    # method handles how each frame is disposed of before displaying the next one.
    # See {Extension::GraphicControl#disposal} for the specific details.
    # This can be overriden individually for each image.
    # @return [Integer] Default frame disposal method.
    attr_accessor :disposal

    # The amount of times to loop the GIF. Must be a number between -1 and 65535,
    # where -1 means to loop indefinitely. Internally, any non-zero number will
    # result in the creation of a Netscape Extension. Note that many programs
    # do not support finite loop counts, instead rendering all GIFs as either
    # fully static or looping indefinitely.
    # @return [Integer] GIF loop count.
    attr_reader :loops

    # Index of the background color in the Global Color Table. This is the color
    # of the exposed parts of the canvas, i.e., those not covered by any image.
    # @note This field is ignored by most decoders, which instead render the
    #   exposed parts of the canvas transparently.
    # @return [Integer] Index of the background color.
    attr_accessor :bg

    # Aspect ratio of the pixels. If provided (`ar > 0`), the aspect ratio is
    # calculated as (ar + 15) / 64, which allows for ratios roughly between 1:4
    # and 4:1 in increments of 1/64th. `0` means square pixels.
    # @note This field is ignored by most decoders, which instead render all
    #   pixels square.
    # @return [Integer] Pixel aspect ratio.
    attr_accessor :ar

    # The array of images present in the GIF.
    # @return [Array<Image>] Image list.
    attr_accessor :images

    # The array of global extensions present in the GIF. This may include
    # Application Extensions, Comment Extensions, etc. Other extensions, like
    # the Graphic Control Extension, are local to each image, and are set there.
    # @return [Array<Extension>] Extension list.
    attr_accessor :extensions

    # Automatically destroy each image right after processing it during encoding.
    # This is intended to save as much memory as possible whenever that's sensitive.
    # Normally, since the pixel data for each image gets encoded and appended to
    # the final output, the data is briefly duplicated in memory. This avoids it.
    # @note This will make the images unusable after the first encoding! So if
    #   you plan on reusing them multiple times, do not enable this setting, or
    #   only do so before the very last encoding.
    # @return [Boolean] Auto-destroy mode.
    attr_accessor :destroy

    # Creates a new GIF object.
    # @param width       [Integer]    Width of the logical screen (canvas) in pixels (see {#width} and {#resize}).
    # @param height      [Integer]    Height of the logical screen (canvas) in pixels (see {#height} and {#resize}).
    # @param gct         [ColorTable] The global color table of the GIF (see {#gct}).
    # @param color       [Integer]    Default frame color (see {#color}).
    # @param delay       [Integer]    Default delay between frames (see {#delay}).
    # @param trans_color [Integer]    Default transparent color (see {#trans_color}).
    # @param disposal    [Integer]    Default disposal method (see {#disposal}).
    # @param loops       [Integer]    Amount of times to loop the GIF (see {#loops}).
    # @param bg          [Integer]    Background color (see {#bg}).
    # @param ar          [Integer]    Pixel aspect ratio (see {#ar}).
    # @param destroy     [Boolean]    Auto-destroy each image right after encoding (see {#destroy}).
    # @return [Gif] The GIF object.
    def initialize(
        width,
        height,
        gct:         nil,
        color:       DEFAULT_COLOR,
        interlace:   DEFAULT_INTERLACE,
        delay:       nil,
        trans_color: nil,
        disposal:    nil,
        loops:       DEFAULT_LOOPS,
        bg:          DEFAULT_BACKGROUND,
        ar:          DEFAULT_ASPECT_RATIO,
        destroy:     false
      )
      # GIF attributes
      @width  = width
      @height = height
      @bg     = bg
      @ar     = ar
      @gct    = gct

      # Default image attributes
      @color       = color
      @interlace   = interlace
      @delay       = delay
      @trans_color = trans_color
      @disposal    = disposal

      # GIF content data
      @images     = []
      @extensions = []

      # Other
      @destroy = destroy
      @file = nil

      # If we want the GIF to loop, then add the Netscape Extension
      self.loops = loops
    end

    # Encode all the data as a GIF file and write it to a stream.
    # @param stream [IO] Stream to write the data to.
    def encode(stream)
      encode_head(stream)

      @images.size.times.each{ |i|
        @images[i].encode(stream)
        if @destroy
          @images[i].destroy
          @images[i] = nil
        end
      }

      encode_tail(stream)
    end

    # Change the dimensions of the GIF's logical screen, i.e, its canvas.
    # @param width [Integer] The new width of the GIF, in pixels.
    # @param height [Integer] The new height of the GIF, in pixels.
    # @todo We should probably test what happens when images are out of the
    #   logical screen's bounds, and perform integrity checks here if necessary,
    #   perhaps cropping the images present in this GIF.
    # @return (see #initialize)
    def resize(width, height)
      @width = width
      @height = height
      self
    end

    # Overload for the loop count so that we can appropriately create or delete
    # the required Netscape Extension.
    def loops=(value)
      raise Exception::GifError, "Loop count must be between -1 and 65535" if !value.between?(-1, 65535)
      if value == 0
        @extensions.reject!{ |e| e.is_a?(Extension::Netscape) }
      else
        @extensions << Extension::Netscape.new(value == -1 ? 0 : value)
      end
    end

    # Shortcut to not loop the GIF at all. This sets the loop count to 0 and
    # removes Netscape Extension. The name of the method comes from the
    # fact that this is typically done to make a still image instead of an
    # animation, but if multiple frames are added, they will be played back once.
    # Crucially, if we want to make a layered image (i.e., a still image with
    # multiple tiles and no delay between them, a common trick to achieve more
    # than 256 colors in a GIF image), it's usually mandatory to do this, as most
    # decoders will actually assume multiple images in a GIF are animation frames,
    # rather than layers of a still image, if the Netscape Extension is present.
    # @return (see #initialize)
    def still
      self.loops = 0
      self
    end

    # Shortcut to loop the GIF indefinitely. This sets the loops count to -1,
    # which translates to 0 in the Netscape Extension.
    # @return (see #initialize)
    def cycle
      self.loops = -1
      self
    end

    # Duplicates all frames in reverse order. Generates a boomerang effect,
    # particularly neat when looped.
    # @param first [Boolean] Whether to duplicate the very first frame. Probably
    #   not desired for looping GIFs, because then the first frame would appear
    #   twice in a row (at the start, and at the end). Useful for non-looping
    #   boomerangs.
    # @return (see #initialize)
    def boomerang(first: false)
      (@images.size - 2).downto(first ? 0 : 1).each{ |i|
        @images << @images[i].dup
      }
      self
    end

    # Shortcut to modify the delay of the GIF's last frame, intended to
    # showcase the final result before looping it. Call this when all frames
    # have already been added to the {#images} list.
    # @param delay [Integer] The time, in 1/100ths of a second, to show the last
    #   frame.
    # @return (see #initialize)
    # @raise [Exception::GifError] If there are no frames in the GIF yet.
    def exhibit(delay = DEFAULT_EXHIBIT_TIME)
      raise Exception::GifError, "No frames in the GIF yet." if @images.empty?
      @images.last.delay = delay
      self
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

    # Open the GIF file and initialize it by writing the start to disk. This includes
    # everything before the actual image data, i.e., the header, logical screen
    # descriptor, global color table and global extensions. This is useful for
    # dynamically building a GIF file and saving it to disk on the fly, instead of
    # keeping all images in memory and only writing them at the end using {#write}
    # or {#save}. Instead, one can open the GIF, use the {#add} method to write
    # images, and finally {#close} it. Intended to reduce memory footprint, specially
    # useful for GIFs with thousands of frames on systems with low memory.
    # @param filename [String] The name to use for the GIF file.
    # @see #close
    # @see #add
    # @raise [Exception::GifError] If the GIF has already been opened.
    def open(filename)
      raise Exception::GifError, "The GIF has already been opened." if open?
      @file = File.open(filename, "wb")
      encode_head(@file)
    end

    # Finish writing the GIF to disk and close it. This writes the trailer to the
    # file and immediately closes it. Only use this when the GIF has been previously
    # opened with {#open}, intended for dynamically creating a GIF and writing
    # it to disk on the fly. To keep everything in memory and just export at the
    # the end, use {#write} or {#save} instead.
    # @see #open
    # @see #add
    # @raise [Exception::GifError] If the GIF had not been opened.
    def close
      raise Exception::GifError, "The GIF hasn't been opened." if !open?
      encode_tail(@file)
      @file.close
    end

    # Add an image to the GIF and write to disk now. Only use this if the GIF
    # been previously opened with {#open}. To instead keep all images in memory
    # and just write everything at the end, simply add the images to the {#images}
    # list and call {#write} or {#save} at the end, which doesn't require to open
    # or close the GIF.
    # @param image [Image] The image to add to the file stream.
    # @raise [Exception::GifError] If the GIF had not been opened.
    def add(image)
      raise Exception::GifError, "The GIF hasn't been opened." if !open?
      image.encode(@file)
    end

    # Checks whether the GIF file has been opened and initialized already or not.
    # @return [Boolean] Is the GIF file open?
    def open?
      @file && !@file.closed?
    end

    private

    # Encode the header, logical screen descriptor, global color table, and
    # global extensions present in the GIF. In other words, encode everything
    # that comes before the actual image data.
    def encode_head(stream)
      # Header
      stream << HEADER

      # Logical Screen Descriptor
      stream << [@width, @height].pack('S<2')
      flags = 0
      flags |= @gct.global_flags if @gct
      stream << [flags].pack('C')
      stream << [@bg, @ar].pack('C2')

      # Global Color Table
      @gct.encode(stream) if @gct

      # Global extensions
      @extensions.each{ |e| e.encode(stream) }
    end

    # Encode the trailer. In other words, encode everything that comes after the
    # actual image data.
    def encode_tail(stream)
      # Trailer
      stream << TRAILER
    end
  end
end
