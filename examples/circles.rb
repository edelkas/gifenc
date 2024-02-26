require 'gifenc'

# Choose largest radius for which we can fit 2 circles inside a given square
DIM = 128
RADIUS = (DIM / (2 + 2 ** 0.5)).to_i

# Create the GIF, and as background, add the 2 circles without border
palette = Gifenc::ColorTable.new([0xFFFFFF, 0, 0x8a4b5e, 0x859f94, 0x6768ab])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette)
gif.images << Gifenc::Image.new(DIM, DIM, color: 4, delay: 2, trans_color: 0)
  .circle([RADIUS, RADIUS], RADIUS, nil, 1)
  .circle([DIM - 1 - RADIUS, DIM - 1 - RADIUS], RADIUS, nil, 1)

# For each frame, redraw the circles with a border 1 unit larger
(RADIUS * 0.75).to_i.times.each{ |r|
  gif.images << Gifenc::Image.new(DIM, DIM, color: 0, delay: 10, trans_color: 0)
    .circle([RADIUS, RADIUS], RADIUS, 2, 1, weight: r + 1, style: :grid)
    .circle([DIM - 1 - RADIUS, DIM - 1 - RADIUS], RADIUS, 3, 1, weight: r + 1, style: :smooth)
}

# Repeat the frames backwards
gif.boomerang
gif.save('test.gif')