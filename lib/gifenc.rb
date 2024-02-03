require_relative 'gif.rb'
require_relative 'image.rb'
require_relative 'extensions.rb'

# Gifenc is a Ruby library to encode and decode GIF files, aiming to eventually
# implement the complete specification (file:docs/spec-gif89a.txt Reference)
# The Gifenc module serves as a namespace to encapsulate the functionality
# of the entire library.
module Gifenc

  # 6-byte block indicating the beginning of the GIF data stream.
  # It is composed of the signature (GIF) and the version (89a).
  HEADER = 'GIF89a'

  # 1-byte block indicating the termination of a sequence of data sub-blocks.
  BLOCK_TERMINATOR = "\x00"

  # 1-byte block indicating the termination of the GIF data stream.
  TRAILER = ';'
end