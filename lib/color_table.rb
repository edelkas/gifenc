module Gifenc
  # The color table is the palette of the GIF, it contains all the colors that
  # may appear in any of its images. The color table can be *global*, in which
  # case it applies to all images, and *local*, in which case it applies only to
  # the subsequent image, superseeding the global one, if present. Both are
  # optional. A color table can have a depth of at most 8 bits, i.e., at most
  # 256 colors, and the color of each pixel in the image is then determined by
  # specifying its index in the corresponding color table.
  class ColorTable

  end
end