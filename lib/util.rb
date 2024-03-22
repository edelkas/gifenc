module Gifenc

  # Encapsulates generic functionality that is useful when handling GIF files.
  module Util

    # Divide data block into a series of sub-blocks of size at most 256 bytes each,
    # consisting on a 1-byte prefix indicating the block length, and <255 bytes of
    # actual data, with a null terminator at the end. This is how raw data (e.g.
    # compressed pixel data or extension data) is stored in GIFs.
    # @param data [String] Data to lay into sub-blocks.
    # @return [String] The resulting data in block fashion.
    def self.blockify(data)
      return BLOCK_TERMINATOR if data.size == 0
      ff = "\xFF".b.freeze
      off = 0
      out = "".b
      len = data.length
      for _ in (0 ... len / 255)
        out << ff << data[off ... off + 255]
        off += 255
      end
      out << (len - off).chr << data[off..-1] if off < len
      out << BLOCK_TERMINATOR
      out
    rescue
      BLOCK_TERMINATOR
    end

    # Recover original data from inside the 256-byte blocks used by GIF.
    # @param data [String] Data in blocks to read.
    # @return [String] Original raw data.
    def self.deblockify(data)
      out = ""
      size = data[0].ord
      off = 0
      while size != 0
        out << data[off + 1 .. off + size]
        off += size + 1
        size = data[off].ord
      end
      out
    rescue
      ''.b
    end
  end
end