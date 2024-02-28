require './lib/gifenc.rb'

DIM    = 128
N      = 5
STEP   = 2
CENTER = [DIM / 2, DIM / 2]
LENGTH = DIM * 0.45
RADIUS = DIM / 3
ANGLE  = -Math::PI / 2
FRAMES = 25
DELAY  = 5

palette = Gifenc::ColorTable.new([0xFFFFFF, 0x888888, 0, 0x880000])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)

center = Gifenc::Geometry::Point.parse(CENTER)
vertex = center + Gifenc::Geometry::Point.parse([RADIUS, ANGLE], :polar)


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

point = vertex.dup
bbox = nil
gif.images.last.circle(vertex, 2, nil, 3)
N.times.each{ |i|
  angle = ANGLE + 2 * Math::PI * (STEP * i + 1) / N
  FRAMES.times.each{ |f|
    new_point = vertex.reflect(
      -1 + 2.0 * (f + 1) / FRAMES,
      p1: center,
      angle: angle
    )
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


gif.save('test.gif')
