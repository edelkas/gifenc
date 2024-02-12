require_relative 'lib/gifenc.rb'


palette = Gifenc::ColorTable.new([0xFFFFFF, 0, 0x808080, 0xFF0000])
gif = Gifenc::Gif.new(128, 128, gct: palette, loops: -1)
gif.images << Gifenc::Image.new(128, 128, color: 2, delay: 2)
64.times.each{ |i|
  length = 32
  angle = 2 * Math::PI * i / 64.0
  point_a = [64, 64]
  point_b = Gifenc::Image.line_endpoint(point: point_a, length: length, angle: angle)
  bbox = Gifenc::Image.bbox([point_a, point_b], 1)
  x0 = point_a[0] - bbox[0]
  y0 = point_a[1] - bbox[1]
  x1 = point_b[0] - bbox[0]
  y1 = point_b[1] - bbox[1]
  gif.images << Gifenc::Image.new(
    bbox[2], bbox[3], bbox[0], bbox[1], color: 0, delay: 5, disposal: 3
  ).line(
    p1: [x0, y0], p2: [x1, y1], color: 1, weight: 2
  )
}

gif.save('test.gif')