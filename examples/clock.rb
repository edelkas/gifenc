require 'gifenc'

DIM   = 128
STEPS = 64

# Build a global color table with a few colors
palette = Gifenc::ColorTable.new(
  [
    0xffffff, # White, will be the transparent color
    0x78563b, # Dark brown, for clock hands
    0xB78E6C, # Mid brown, for clock marks
    0xead2a2  # Light brown, for background
  ]
)

# Create a looping GIF, and add a first frame which be the clock's background
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)
gif.images << Gifenc::Image.new(DIM, DIM, color: 3, delay: 2)

# Draw hour marks on the first frame, they'll remain fixed
(0 ... 12).each{ |hour|
  center = [DIM / 2, DIM / 2]
  angle = 2.0 * Math::PI * hour / 12
  endpoint_1 = Gifenc::Geometry.endpoint(
    point:  center,
    angle:  angle,
    length: 0.4 * DIM
  )
  endpoint_2 = Gifenc::Geometry.endpoint(
    point:  center,
    angle:  angle,
    length: 0.5 * DIM
  )
  gif.images.first.line(p1: endpoint_1, p2: endpoint_2, color: 2)
}
gif.images.first.rect(0, 0, DIM, DIM, 1, weight: 3)

# Draw clock hand moving
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
