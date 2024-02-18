require 'gifenc'

DIM = 128
WEIGHT = 11

palette = Gifenc::ColorTable.new([0xEEEEEE, 0x000040, 0xFF0040])
gif = Gifenc::Gif.new(DIM, DIM, color: 0, gct: palette, loops: -1)

# For each frame we draw 2 rectangles with the SAME boundary:
# - The first one has a thick border with varying anchoring.
# - The second one has a border of width 1 and stays fixed, showing the actual
#   boundary of the rectangle.
(0 ... WEIGHT).each{ |t|
  x = WEIGHT + 2
  y = x
  w = DIM - 2 * WEIGHT - 4
  h = w
  a = -1 + 2 * t.to_f / (WEIGHT - 1)
  gif.images << Gifenc::Image.new(DIM, DIM, delay: 10)
    .rect(x, y, w, h, 1, weight: WEIGHT, anchor: a)
    .rect(x, y, w, h, 2, weight: 1, anchor: a)
}

# We repeat the frames in reverse order
gif.boomerang

gif.save('test.gif')