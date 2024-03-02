require './lib/gifenc.rb'

DIM  = 128
N    = 64

palette = Gifenc::ColorTable.new([0xFFFFFF, 0, 0xFF0000])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)

bg = Gifenc::Image.new(DIM, DIM, color: 0, delay: 2)

points = N.times.map{ [2 + rand(DIM - 4), 2 + rand(DIM - 4)] }
#points = (8 .. 120).step(8).to_a.product((8 .. 120).step(8).to_a).shuffle.take(N)
points.each{ |p| bg.circle(p, 0.5, nil, 1) }
gif.images << bg

hull = Gifenc::Geometry.convex_hull(points, true)
hull.size.times.each{ |i|
  a = hull[i]
  b = hull[(i + 1) % hull.size]
  d = (b - a).norm_inf.ceil
  d.times.each{ |j|
    p1 = a + (b - a) * (j / d.to_f)
    p2 = a + (b - a) * ((j + 1) / d.to_f)
    bbox = Gifenc::Geometry.bbox([p1, p2], j == 0 ? 2 : 0)
    p1, p2 = Gifenc::Geometry.transform([p1, p2], bbox)
    gif.images << Gifenc::Image.new(bbox: bbox, color: 0, trans_color: 0, delay: 2)
      .line(p1: p1, p2: p2, color: 2)
    gif.images.last.circle(p1, 1.5, nil, 2) if j == 0
  }
}

gif.exhibit
gif.save('test.gif')