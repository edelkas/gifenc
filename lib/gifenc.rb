# Gifenc is a pure Ruby library to encode, decode and edit GIF files. It aims
# to eventually support the complete {file:docs/Specification.md specification}.
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

  # Default disposal method to use when it hasn't been explicitly specified.
  DEFAULT_DISPOSAL = DISPOSAL_NONE

  # Default frame delay, in 1/100ths of a second, to use when an animated GIF
  # without explicit delay is created.
  DEFAULT_DELAY = 10

  # Default color _index_ to initialize blank images to.
  DEFAULT_COLOR = 0

  # Default color _index_ to use as transparent for those images which have
  # transparency enabled but which don't have an explicit transparent color set.
  DEFAULT_TRANS_COLOR = 0

  # Default value of the deprecated user input flag in graphic control extensions.
  DEFAULT_USER_INPUT = false

  # Default number of times to loop GIF's (`-1` = indefinitely).
  DEFAULT_LOOPS = -1

  # Whether to use image interlacing by default.
  DEFAULT_INTERLACE = false

  # Default background color (only for exposed parts of the canvas). Note that
  # this setting is actually ignored by most decoders.
  DEFAULT_BACKGROUND = 0

  # Default pixel aspect ratio (`0` = square). Note that this setting is ignored
  # by most decoders.
  DEFAULT_ASPECT_RATIO = 0

  # Default time to exhibit GIF's last frame when selected (in 1/100ths of sec)
  DEFAULT_EXHIBIT_TIME = 100
end

require_relative 'errors.rb'
require_relative 'util.rb'
require_relative 'geometry.rb'
require_relative 'color_table.rb'
require_relative 'extensions.rb'
require_relative 'image.rb'
require_relative 'gif.rb'

require_relative 'cgifenc'
