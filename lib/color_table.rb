module Gifenc
  # The color table is the palette of the GIF, it contains all the colors that
  # may appear in any of its images. The color table can be *global*, in which
  # case it applies to all images, and *local*, in which case it applies only to
  # the subsequent image, overriding the global one, if present. Both are
  # optional.
  #
  # A color table can have a size of at most 8 bits, i.e., at most 256 colors,
  # and a depth (color resolution) of at most 8 bits per R/G/B channel.
  # Regardless of the bit depth, each color component still takes up a byte (and
  # each pixel thus 3 bytes) in the encoded GIF file.
  # The color of each pixel in the image is then determined by specifying its
  # index in the corresponding color table.
  class ColorTable
    def initialize(colors = [], depth = 8)
      @colors = colors
      @depth = depth
    end
  end
end