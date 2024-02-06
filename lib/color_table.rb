module Gifenc
  # The color table is the palette of the GIF, it contains all the colors that
  # may appear in any of its images. The color table can be *global* (GCT), in
  # which case it applies to all images, and *local* (LCT), in which case it
  # applies only to the subsequent image, overriding the global one, if present.
  # Technically, both are optional according to the standard, but we always
  # include a GCT, since otherwise it's up to software to choose how to render
  # the colors.
  #
  # A color table can have a size of at most 8 bits, i.e., at most 256 colors,
  # and it's always a power of 2, even if there's leftover space or empty slots.
  # The color depth / resolution may be at most 8 bits per R/G/B channel.
  # Regardless of the bit depth, each color component still takes up a byte (and
  # each pixel thus 3 bytes) in the encoded GIF file.
  # The color of each pixel in the image is then determined by specifying its
  # index in the corresponding color table.
  class ColorTable

    # Creates a new color table. This color table can then be used as a GCT,
    # as an LCT for as many images as desired, or both.
    # @param colors [Array<Integer>] An ordered list of colors to initialize the
    #   table with. Colors can be duplicated, but regardless, the list should be
    #   at most 256 colors long. It can be empty, and colors be added later.
    # @param unique [Boolean] Eliminates duplicate colors in the supplied list
    #   _before_ building the table. Beware that this will, naturally, change
    #   the color indices, so if this is unacceptable (perhaps because an image
    #   needs to be parsed with this exact palette configuration), don't do it.
    #   If enabled, then the list may have more than 256 entries, as long as it
    #   has fewer than 256 different entries.
    # @param max_size [Integer] Maximum size of the color table (maximum number
    #   of colors) in bits. This must be between 1 and 8, yielding a size between
    #   2 and 256 colors. **Note**: The encoder will always choose the smallest
    #   size possible that fits all colors, only change this setting if you want
    #   to _force_ it to not surpass a certain size below the hard limit of 256.
    # @param depth [Integer] Specifies the bit depth (1-8) for each color
    #   component _in the original image_. This does **not** set the actual GIF's
    #   color depth (that is always 8), and is ignored by most decoders anyway,
    #   so this field was almost never useful.
    # @param sorted [Boolean] Indicates that the colors in the table are sorted
    #   by importance. It's essentially a deprecated flag that most decoders ignore.
    # @return [ColorTable] The newly created Color Table.
    def initialize(colors = [], unique = false, max_size: 8, depth: 8, sorted: false)
      @colors = {}
      @depth = depth.clamp(1, 8)
      @sorted = sorted
      resize(max_size)
      set(colors, unique)
    end

    # Encode the color table as it will appear in the GIF.
    # @param stream [IO] The stream to output the encoded color table into.
    def encode(stream)
      inv_colors = @colors.invert
      for i in (0 ... 2 ** real_size) do
        c = inv_colors[i] || 0
        stream << [c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF].pack('C3')
      end
    end

    # Pack GCT flags into a byte as they appear in the GIF.
    # @private
    def global_flags
      (1 << 7 | (@depth - 1 & 0b111) << 4 | (@sorted ? 1 : 0) << 3 | (real_size - 1 & 0b111)) & 0xFF
    end

    # Pack LCT flags into a byte as they appear in the GIF.
    # @private
    def local_flags
      (1 << 7 | (@sorted ? 1 : 0) << 5 | (real_size - 1 & 0b111)) & 0xFF
    end

    # Change all colors in this table with a different list of colors.
    # @param colors [Array<Integer>] The new list of colors.
    # @param unique [Boolean] Whether to remove color duplicates.
    def set(colors, unique = false)
      colors.uniq! if unique
      if colors.size > @max_size
        raise ColorTableError, "Cannot build color table, the supplied color list\
          has more than #{@max_size } entries."
      end

      # Keep only _first_ appearance of each color in the palette
      @colors = colors.each_with_index.to_a.reverse.to_h
      @index  = find_slot
    end

    # Changes the maximum size of the color table. The encoder will always use
    # the smallest possible size that fits all colors, so this is only intended
    # to force a smaller (than 256) limit. The new size is specified in bits and
    # must be between 1 and 8, thus yielding a table size between 2 and 256 colors.
    # The policy specifies what to do if the new size doesn't fit all the colors
    # currently present in the table.
    # @param bits [Integer] New table size in bits (1-8).
    # @param policy [Symbol] Specifies how to handle when the new size doesn't
    #   fit the current colors in the table:
    #   * `:strict` will raise an exception. It will never modify existing colors.
    #   * `:reorder` will rearrange the colors by removing empty intermediate
    #     slots if that's enough to make the colors fit. It will never delete colors.
    #   * `:truncate` will simply truncate the necessary colors from the end of the table.
    def resize(bits, policy = :strict)
      raise ColorTableError, "Color table bit size must be between 1 and 8." if !bits.between?(1, 8)
      max_index = @colors.values.max || 0

      # Current colors fit in new size without changes
      if max_index < 1 << bits
        return (@max_size = 1 << bits)
      elsif policy == :strict
        raise ColorTableError, "Color table could not be resized (strict policy)"
      end

      # Current colors do not fit in new size
      if policy == :reorder
        if @colors.size <= 1 << bits
          reset
          return (@max_size = 1 << bits)
        else
          raise ColorTableError, "Color table could not be resized (truncation needed)"
        end
      elsif policy == :truncate
        @colors.delete_if{ |color, index| index >= 1 << bits }
        return (@max_size = 1 << bits)
      else
        raise ColorTableError, "Unknown table resizing policy"
      end
    end

    # Rearranges all the colors in the color table to remove empty intermediate
    # slots, by laying out all colors subsequently from the start.
    def reset
      @colors = @colors.keys.each_with_index.to_h
      @index = @colors.size < @max_size - 1 ? @colors.size : nil
    end

    # Empties the whole color table, bringing its size down to 0.
    def clear
      @colors = {}
      @index = 0
    end

    # Rearrange a subset of colors in the table according to a permutation.
    # The permutation must match the length of the provided colors. For example,
    # if we pass the colors `A, B, C, D` and the permutation `3, 1, 4, 2`, the
    # colors will now be sorted like `C, A, D, B`.
    # @param colors [Integers] The colors to rearrange.
    # @param order [Array<Integer>] The permutation according to which to rearrange.
    def permutate(*colors, order: [])
      # Ensure permutation makes sense for the provided colors
      if order.sort != colors.size.times.to_a
        raise ColorTableError, "Cannot permutate colors: Permutation is invalid."
      end

      # Ensure provided colors are in the table
      indices = colors.map{ |c| @colors[c] }
      raise ColorTableError, "Can't cycle colors: Color not found." if !indices.all?

      for i in (0 ... indices.size) do
        @colors[i] = indices[order[i]]
      end
    end

    # Rearrange a subset of colors in the table according to a cycle (see
    # {#permutate}). For example, if we cycle the colors `A, B, C, D` with a
    # step of -2, the colors become `C, D, A, B`.
    # @param colors [Integers] The sequence of colors to shift in a cycle.
    # @param step [Integer] The positive or negative step to take in the shift.
    def cycle(*colors, step: 1)
      permutation = colors.times.map{ |i| (i - step) % indices.size }
      permutate(*colors, order: permutation)
    end

    # Swap 2 colors of the color table. This can be used to change the theme of
    # a GIF in a trivial way.
    # @param col_a [Integer] First color to swap.
    # @param col_b [Integer] Second color to swap.
    def swap(col_a, col_b)
      permutate(col_a, col_b, order: [1, 0])
    end

    # Insert new colors into the color table.
    # @param colors [Integers] The colors to add.
    # @return [Integer] The table index of the (last) added color.
    def add(*colors)
      if @colors.size + colors.size > @max_size
        raise ColorTableError, "Cannot add #{colors.size} colors to the color\
          table: Palette would overflow."
      end
      colors.each{ |c| add_color(c) }
    end

    # Delete colors from the color table.
    # @param colors [Integers] The colors to delete.
    # @return [Boolean] Whether all colors were found (and deleted) or not.
    def delete(*colors)
      colors.all?{ |c| delete_color(c) }
    end

    # Changes one color in the table with a different value. The value must be
    # new, as the colors in the table must be unique.
    # @param old_color [Integer] The color to replace.
    # @param new_color [Integer] The color to change it to.
    def replace(old_color, new_color)
      raise ColorTableError, "Cannot change color: New color already exists." if @colors[new_color]
      @colors[new_color & 0xFFFFFF] = @colors[old_color]
      @colors.delete(old_color)
    end

    # Inverts all the colors in the table.
    def invert
      @colors.each{ |c| replace(c, c ^ 0xFFFFFF) }
    end

    # Find the actual bit size of the color table
    # @private
    def real_size
      [Math.log2(@colors.values.max + 1).ceil, 1].max
    end

    private

    # Find index of the first empty slot in the color table (nil if full)
    def find_slot
      @colors.values.sort.each_with_index.find{ |c, i| c != i  }[1]
    end

    # Add an individual color to the color table, return its index
    def add_color(color)
      ind = @colors[color & 0xFFFFFF]
      return ind if ind
      raise ColorTableError, "Cannot add color to the color table: Palette is full." if !@index
      @colors[color & 0xFFFFFF] = @index
      ind = @index
      @index = find_slot
      ind
    end

    # Delete an individual color from the color table, return whether it was found and deleted
    def delete_color(color)
      ind = @colors.delete(color)
      @index = ind if ind && ind < @index
      !!ind
    end

  end
end