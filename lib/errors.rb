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

    # Raised when a generic error happens at the highest level, such as building
    # a GIF file with an incorrect structure.
    class GifError < Exception
    end

    # Raised when an illegal operation regarding GIF extensions is performed,
    # such as trying to append 2 Graphic Control Extensions to the same image.
    class ExtensionError < Exception
    end

    # Raised when a mathematic error happens in any of the calculations.
    class GeometryError < Exception
    end
  end
end
