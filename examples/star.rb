require './lib/gifenc.rb'

# Build a 5-point star by reflection a vertex about each diagonal
# Obviously, it's not the optimal way to draw the star, it just serves to
# illustrate axial reflections.

# GIF properties
DIM    = 128
FRAMES = 25
DELAY  = 5

# Star properties
N      = 5
STEP   = 2
CENTER = [DIM / 2, DIM / 2]
LENGTH = DIM * 0.45
RADIUS = DIM / 3
ANGLE  = -Math::PI / 2

# Create a basic palette with 4 colors and a looping GIF using it
palette = Gifenc::ColorTable.new([0xFFFFFF, 0x888888, 0, 0x880000])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)

# Define the center and the first vertex point, it's not necessary to use
# the Geometry module simply for drawing points or lines (arrays of coordinates
# can simply be used), but it is simpler to operate with Point objects.
center = Gifenc::Geometry::Point.parse(CENTER)
vertex = center + Gifenc::Geometry::Point.parse([RADIUS, ANGLE], :polar)

# Create the first frame of the GIF, and draw each of the star diagonals on it
background = Gifenc::Image.new(DIM, DIM, color: 0, delay: 2)
N.times.each{ |i|
  background.line(
    p1: center,
    angle: ANGLE + 2 * Math::PI * (STEP * i + 1) / N,
    length: LENGTH,
    color: 1
  )
}
gif.images << background

# Animate the tracing of the star, we start with the top vertex and compute the
# subsequent ones by reflecting about the corresponding diagonal.
point = vertex.dup
bbox = nil
gif.images.last.circle(vertex, 2, nil, 3)
N.times.each{ |i|
  # Draw each side
  angle = ANGLE + 2 * Math::PI * (STEP * i + 1) / N
  FRAMES.times.each{ |f|
    # Next point is calculated by partially reflecting the vertex
    new_point = vertex.reflect(
      -1 + 2.0 * (f + 1) / FRAMES,
      p1: center,
      angle: angle
    )

    # Each frame only changes a small portion of the screen, so instead of
    # updating everything, we only redraw a small region given by a bounding
    # box containing the line chunk for this frame.
    bbox = Gifenc::Geometry.bbox([point, new_point], f == FRAMES - 1 ? 2 : 0)
    p1, p2 = Gifenc::Geometry.transform([point, new_point], bbox)
    gif.images << Gifenc::Image.new(bbox: bbox, color: 0, trans_color: 0, delay: DELAY)
      .line(p1: p1, p2: p2, color: 2)
    point = new_point
  }
  vertex = point
  circle = Gifenc::Geometry.transform([vertex], bbox)[0]
  gif.images.last.circle(circle, 2, nil, 3)
}

# Stop 1 second to admire the star
gif.images.last.delay = 100
gif.save('test.gif')
