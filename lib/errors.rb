module Gifenc
  # Generic Gifenc exception container.
  class Exception < ::StandardError
    # Raised when we perform illegal operations with the color table of a GIF
    # such as adding more than 256 colors.
    class ColorTableError < Exception
    end

    # Raised when an illegal operation is performed when manipulating the canvas,
    # such as trying to change an out of bounds pixel.
    class CanvasError < Exception
    end
  end
end