require 'gifenc'

# GIF dimensions and amount of random points to take
DIM    = 128
MARGIN = 16
N      = 32

# Build a basic color table and a looping GIF with a first background frame
palette = Gifenc::ColorTable.new([0xFFFFFF, 0, 0x880000, 0xFFDDDD, 0x000088])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)
bg = Gifenc::Image.new(DIM, DIM, color: 0, delay: 2)

# Generate N random points and draw them on the canvas as little circles
points = N.times.map{
  [MARGIN + rand(DIM - 2 * MARGIN), MARGIN + rand(DIM - 2 * MARGIN)]
}
points.each{ |p| bg.circle(p, 0.5, nil, 1) }
gif.images << bg
last = bg.dup # Duplicate background for later

# Compute the convex hull, which yields the smallest convex set containing
# all the points in the set, and progressively draw its boundary
hull = Gifenc::Geometry.convex_hull(points, true)
hull.size.times.each{ |i|
  # One edge of the hull
  a = hull[i]
  b = hull[(i + 1) % hull.size]
  d = (b - a).norm_inf.ceil

  # Draw each edge of the hull at constant speed by dividing it into the
  # appropriate number of frames. We will draw the edges and circles twice, once
  # in the background image, and once in the actual frame. As a consequence, we
  # can have small frames, but also record everything on a full image, which we
  # will use at the end to call the bucket fill tool.
  d.times.each{ |j|
    # Edge chunk coordinates
    p1 = a + (b - a) * (j / d.to_f)
    p2 = a + (b - a) * ((j + 1) / d.to_f)

    # Draw on a full image
    last.line(p1: p1, p2: p2, color: 2)
    last.circle(p1, 2, nil, 2) if j == 0

    # Draw on a new frame, by redrawing the rectangular bounding box rather than
    # the whole GIF
    bbox = Gifenc::Geometry.bbox([p1, p2], j == 0 ? 2 : 0)
    p1, p2 = Gifenc::Geometry.transform([p1, p2], bbox)
    gif.images << Gifenc::Image.new(bbox: bbox, color: 0, trans_color: 0, delay: 2)
      .line(p1: p1, p2: p2, color: 2)
    gif.images.last.circle(p1, 2, nil, 2) if j == 0
  }
}

# In order to fill the convex region, we will use the flood fill method, which
# implements the classic bucket tool. Since the points were selected at random,
# we make 50 attempts at finding a white pixel around the center of the image,
# so that we can throw the bucket there.
50.times.each{
  x = (0.4 * DIM + rand(0.2 * DIM)).round
  y = (0.4 * DIM + rand(0.2 * DIM)).round
  if last[x, y] == 0
    last.fill(x, y, 3)
    break
  end
}
gif.images << last

# We finish by also drawing the center of mass of the random points, which is
# of course contained within the convex hull.
center = Gifenc::Geometry.center(points)
last.circle(center, 2, nil, 4)

# Keep last frame onscreen for longer
gif.exhibit(200)
gif.save('test.gif')