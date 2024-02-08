require 'set'

module Gifenc
  # The color table is the palette of the GIF, it contains all the colors that
  # may appear in any of its images. The color table can be *global* (GCT), in
  # which case it applies to all images, and *local* (LCT), in which case it
  # applies only to the subsequent image, overriding the global one, if present.
  # Technically, both are optional according to the standard, but we enforce
  # having an LCT if no GCT is present, since otherwise it's up to the decoder to
  # choose how to render the colors.
  #
  # A color table can have a size of at most 8 bits, i.e., at most 256 colors,
  # and it's always a power of 2, even if there's leftover space or empty slots.
  # The color of each pixel in the image is then determined by specifying its
  # index in the corresponding color table (local, if present, or global).
  # Regardless of the bit depth, each color component still takes up a byte (and
  # each pixel thus 3 bytes) in the encoded GIF file.
  #
  # This class handles all the logic dealing with color indexes (in the table)
  # internally, so that the user can work purely with colors directly.
  #
  # Notes:
  # - Many of the methods that manipulate the color table return the table back,
  #   so that they may be chained properly.
  # - Several methods may change the color indexes, thus potentially corrupting
  #   images already made with this table. These methods are indicated with a note,
  #   and should probably only be used when building the desired palette, before
  #   actually starting to use it to craft images.
  class ColorTable

    # The maximum size of a GIF color table. The encoder will always choose the
    # smallest size possible that fits all colors, so this is only a hard limit.
    MAX_SIZE = 256

    # The color resolution, in bits per channel, of the _original_ image, NOT of
    # the GIF. The GIF's color depth is always 8 bits per channel.
    # @return [Integer] Original color bit depth.
    # @note This attribute is essentially meaningless nowadays, and ignored by
    #   most decoders.
    attr_accessor :depth

    # Whether the colors of the table are sorted in decreasing order of importance.
    # As per the specification, this would typically be decreasing order of
    # frequency, in order to assist older systems and decoders with fewer
    # available colors in choosing the best subset of colors to represent the image.
    # @return [Boolean] Whether the table colors are sorted or not.
    # @note This attribute is essentially meaningless nowadays, and ignored by
    #   most decoders.
    attr_accessor :sorted

    # The raw list of colors in the table. May contain `nil`s, which represents
    # empty slots in the table (since the exact indexes matter). To change the
    # color list in bulk, use the {#set} method. To change individual colors,
    # use the {#replace} method.
    # @return [Array<Integer>] The raw list of colors.
    attr_reader :colors

    # Creates a new color table. This color table can then be used as a GCT,
    # as an LCT for as many images as desired, or both.
    # @param colors [Array<Integer>] An ordered list of colors to initialize the
    #   table with. Colors can be duplicated, but regardless, the list should be
    #   at most 256 colors long. Since the indexes matter, the list may contain
    #   `nil`s, which represents empty slots in the table.
    # @param depth [Integer] Specifies the bit depth (1-8) for each color
    #   component _in the original image_. This does **not** set the actual GIF's
    #   color depth (that is always 8), and is ignored by most decoders.
    # @param sorted [Boolean] Indicates that the colors in the table are sorted
    #   by importance. It's essentially a deprecated flag that most decoders ignore.
    # @return [ColorTable] The color table.
    def initialize(colors = [], depth: 8, sorted: false)
      clear
      @depth = depth.clamp(1, 8)
      @sorted = sorted
      set(colors)
    end

    # Encode the color table as it will appear in the GIF.
    # @param stream [IO] The stream to output the encoded color table into.
    def encode(stream)
      @colors.each{ |c|
        c = 0 if !c
        stream << [c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF].pack('C3')
      }
    end

    # Create a duplicate copy of this color table.
    # @return [ColorTable] The new color table.
    def dup
      ColorTable.new(@colors.dup, depth: @depth, sorted: @sorted)
    end

    # Pack GCT flags into a byte as they appear in the GIF.
    # @private
    def global_flags
      (1 << 7 | (@depth - 1 & 0b111) << 4 | (@sorted ? 1 : 0) << 3 | (bit_size - 1 & 0b111)) & 0xFF
    end

    # Pack LCT flags into a byte as they appear in the GIF.
    # @private
    def local_flags
      (1 << 7 | (@sorted ? 1 : 0) << 5 | (bit_size - 1 & 0b111)) & 0xFF
    end

    # Change all colors in this table with a different list of colors. The list
    # may contain `nil`s, indicating empty slots.
    # @param colors [Array<Integer>] The new list of colors.
    # @return (see #initialize)
    # @note This method may change color indexes.
    # @raise [ColorTableError] If there are too many colors (>256).
    def set(colors)
      if colors.size > MAX_SIZE
        raise ColorTableError, "Cannot build color table, the supplied color list\
          has more than #{MAX_SIZE} entries."
      end
      colors.each_with_index{ |c, i| @colors[i] = !!c ? c & 0xFFFFFF : nil }
      self
    end

    # Eliminates duplicate colors from the color table. This will keep the first
    # instance of each color untouched (i.e., its index will remain valid), and
    # set subsequent duplicate entries to `nil`.
    # @note (see #set)
    # @return (see #initialize)
    # @see #simplify
    def uniq
      unique_colors = Set.new
      for i in (0 ... MAX_SIZE)
        next if !@colors[i]
        if @colors[i].in?(unique_colors)
          @colors[i] = nil
        else
          unique_colors.add(@colors[i])
        end
      end
      self
    end

    # Rearrange all colors to remove empty intermediate slots. This is accomplished
    # by laying out all colors subsequently from the start. The order of the
    # actual colors is preserved.
    # @return (see #initialize)
    # @note (see #set)
    # @see #simplify
    def compact
      @colors.compact!
      @colors += [nil] * (MAX_SIZE - @colors.size)
      self
    end

    # Simplifies the color table by removing color duplicates and empty slots.
    # It's equivalent to `uniq` + `compact`.
    # @return (see #initialize)
    # @see #uniq
    # @see #compact
    # @note (see #set)
    def simplify
      uniq
      compact
    end

    # Empties the whole color table, bringing its size down to 0.
    # @return (see #initialize)
    # @note (see #set)
    def clear
      @colors = [nil] * MAX_SIZE
      self
    end

    alias_method :reset, :clear

    # Rearrange a subset of colors in the table according to a permutation.
    # The permutation must match the length of the provided colors. For example,
    # if we pass the colors `A, B, C, D` and the permutation `[2, 0, 3, 1]`, the
    # colors will now be sorted like `C, A, D, B`.
    # @param colors [Integers] The colors to rearrange.
    # @param order [Array<Integer>] The permutation according to which to rearrange.
    # @return (see #initialize)
    # @see #cycle
    # @raise [ColorTableError] If the permutation is invalid (e.g. not of the
    #   right length, or not containing the right indices), or if any color was
    #   not found in the color table.
    def permute(*colors, order: [])
      # Ensure permutation makes sense for the provided colors
      if order.sort != colors.size.times.to_a || order.uniq.size != order.size
        raise ColorTableError, "Cannot permute colors: Permutation is invalid."
      end

      # Ensure provided colors are in the table
      if !(colors - @colors).empty?
        raise ColorTableError, "Cannot permute colors: Color not found."
      end

      mapping = colors.each_with_index.map{ |c, i| [c, colors[order[i]]] }.to_h
      @colors.map!{ |c| mapping[c] || c }
      
      self
    end

    # Rearrange a subset of colors in the table according to a cycle. For
    # example, if we cycle the colors `A, B, C, D` with a step of -2, the colors
    # become `C, D, A, B`.
    # @param colors [Integers] The sequence of colors to shift in a cycle.
    # @param step [Integer] The positive or negative step to take in the shift.
    # @return (see #initialize)
    # @see #permute
    # @raise [ColorTableError] If any color was not found in the color table.
    def cycle(*colors, step: 1)
      permutation = colors.times.map{ |i| (i - step) % colors.size }
      permute(*colors, order: permutation)
    end

    # Swap 2 colors of the color table. This can be used to change the theme of
    # a GIF in a trivial way.
    # @param col_a [Integer] First color to swap.
    # @param col_b [Integer] Second color to swap.
    # @return (see #initialize)
    # @raise (see #cycle)
    def swap(col_a, col_b)
      permute(col_a, col_b, order: [1, 0])
    end

    # Insert new colors into the color table.
    # @param colors [Integers] The colors to add.
    # @return (see #initialize)
    # @raise [ColorTableError] If there's not enough space in the table to add
    #   the new colors.
    def add(*colors)
      colors = (colors - @colors).compact.uniq
      if count + colors.size > MAX_SIZE
        raise ColorTableError, "Cannot add colors to the color table:\
          Table over size limit (#{MAX_SIZE})."
      end
      colors.each{ |c| @colors[find_slot] = c & 0xFFFFFF }
      self
    end

    # Delete colors from the color table.
    # @param colors [Integers] The colors to delete.
    # @return (see #initialize)
    def delete(*colors)
      colors.each{ |c| replace(c, nil) }
      self
    end

    # Changes one color in the table to another one.
    # @param old_color [Integer] The color to replace.
    # @param new_color [Integer] The color to change it to.
    # @return (see #initialize)
    def replace(old_color, new_color)
      new_color = !!new_color ? new_color & 0xFFFFFF : nil
      @colors.map!{ |c| c == old_color ? new_color : c }
      self
    end

    # Inverts all the colors in the table.
    # @return (see #initialize)
    def invert
      @colors.each{ |c| replace(c, c ^ 0xFFFFFF) }
      self
    end

    # Find the actual bit size of the color table.
    # @private
    def bit_size
      [Math.log2(last + 1).ceil, 1].max
    end

    # Real size of the table that will be used by the encoder. The size is the
    # smallest power of 2 capable of holding all colors currently in the list.
    # It must be at least 2, even if there's a single color in the table.
    # @return [Integer] Size of the table.
    # @see #count
    def size
      2 ** bit_size
    end

    alias_method :length, :size

    # Count of actual colors present in the table.
    # @return [Integer] Color count.
    # @see #size
    # @see #distinct
    def count
      @colors.count{ |c| !!c }
    end

    # Count of distinct colors present in the table. See {#count}.
    # @return [Integer] Distinct color count.
    # @see #count
    def distinct
      @colors.uniq.count{ |c| !!c }
    end

    private

    # Find the last slot containing a color.
    def last
      @colors.rindex{ |c| !!c }
    end

    # Find the first empty slot (nil if full).
    def find_slot
      @colors.index(nil)
    end

  end
end
