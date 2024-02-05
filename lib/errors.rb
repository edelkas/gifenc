module Gifenc
  # Generic Gifenc exception container.
  class Exception < ::StandardError
    # Exception raised when we perform illegal operations with the color table of
    # a GIF, such as adding more than 256 colors.
    class ColorTableError < Exception
    end
  end
end