# Gifenc is a Ruby library to encode and decode GIF files, aiming to eventually
# implement the complete {file:docs/Specification.md specification}.
# The Gifenc module serves as a namespace to encapsulate the functionality
# of the entire library.
module Gifenc

  # 1-byte block indicating the termination of a sequence of data sub-blocks.
  BLOCK_TERMINATOR = "\x00"

  # Fully replace a frame with the next one.
  DISPOSAL_REPLACE = 0

  # Do not dispose a frame before displaying the next one.
  DISPOSAL_NONE = 1

  # Restore to background color before displaying the next frame.
  DISPOSAL_BG = 2

  # Restore to the previous undisposed frame before displaying the next one.
  DISPOSAL_PREV = 3
end

require_relative 'util.rb'
require_relative 'errors.rb'
require_relative 'color_table.rb'
require_relative 'extensions.rb'
require_relative 'image.rb'
require_relative 'gif.rb'