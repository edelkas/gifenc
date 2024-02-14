require 'gifenc'

DIM   = 128
STEPS = 64

# Build a global color table with a few colors, create a looping GIF,
# and add a first frame which will act as the background
palette = Gifenc::ColorTable.new([0xFFFFFF, 0, 0x808080, 0xFF0000])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)
gif.images << Gifenc::Image.new(DIM, DIM, color: 2, delay: 2)

STEPS.times.each{ |i|
  # Determine the coordinates of the endpoints of the line, with respect
  # to the whole canvas
  length = DIM / 3.0
  angle = 2.0 * Math::PI * i / STEPS
  point_a = [DIM / 2, DIM / 2]
  point_b = Gifenc::Geometry.endpoint(point: point_a, length: length, angle: angle)

  # The frame won't take up the whole canvas, we save space by only taking
  # the bounding box of the line
  bbox = Gifenc::Geometry.bbox([point_a, point_b], 1)
  point_a, point_b = Gifenc::Geometry.transform([point_a, point_b], bbox)
  gif.images << Gifenc::Image.new(
    bbox: bbox, color: 0, delay: 5, disposal: 3, trans_color: 0
  ).line(p1: point_a, p2: point_b, color: 1, weight: 2)
}

# Export GIF to a file
gif.save('test.gif')
