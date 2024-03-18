require 'gifenc'

# GIF properties
DIM    = 128
FRAMES = 512
DELAY  = 4

# Colors
BG   = 0
COL1 = 0x880000
COL2 = 0x008800
COL3 = 0x000088

# Rectangle dimensions (width and height)
DIM1 = [40, 40]
DIM2 = [30, 50]
DIM3 = [30, 20]

# Initial positions (upper left corners)
POS1 = [50, 40]
POS2 = [70, 70]
POS3 = [0, 100]

# Initial velocities
VEL1 = [-1, 1]
VEL2 = [2, -2]
VEL3 = [3, 3]

# Build a color table containing the background color, the 3 rectangle colors,
# and all possible sums. When rectangles overlap, the color of the intersection
# is the RGB sum of the colors
$palette = Gifenc::ColorTable.new(
  [
    BG,                                      # Background
    COL1, COL2, COL3,                        # Base colors
    COL1 + COL2, COL1 + COL3, COL2 + COL3,   # 2-overlap colors
    COL1 + COL2 + COL3                       # 3-overlap colors
  ]
)

# Construct an infinitely looping GIF
$gif = Gifenc::Gif.new(DIM, DIM, gct: $palette, loops: -1)

# Draw the rectangles and their overlaps on the last frame
def draw_rectangles
  # Fetch image and colors
  image = $gif.images.last
  colors = $palette.colors

  # Draw base rectangles with their original color
  3.times.each{ |i|
    rect = [*$rects[i][:pos], *$rects[i][:dim]]
    color = colors.index($rects[i][:col])
    image.rect(*rect, nil, color)
  }

  # Draw double overlaps
  3.times.to_a.combination(2).each{ |i, j|
    rect = Gifenc::Geometry.rect_overlap(
      [*$rects[i][:pos], *$rects[i][:dim]],
      [*$rects[j][:pos], *$rects[j][:dim]]
    )
    color = colors.index($rects[i][:col] + $rects[j][:col])
    image.rect(*rect, nil, color) if rect
  }

  # Draw triple overlap
  rect = Gifenc::Geometry.rect_overlap(
    [*$rects[0][:pos], *$rects[0][:dim]],
    [*$rects[1][:pos], *$rects[1][:dim]],
    [*$rects[2][:pos], *$rects[2][:dim]]
  )
  color =  colors.index($rects[0][:col] + $rects[1][:col] + $rects[2][:col])
  image.rect(*rect, nil, color) if rect
end

# Update the position of the rectangles, by adding the velocity and bouncing
# off the walls when needed
def update_positions
  3.times.each{ |i|
    # Move rectangles
    2.times.each{ |j|
      $rects[i][:pos][j] += $rects[i][:vel][j]
    }

    # Depenetrate and bounce rectangle off each wall
    2.times.each{ |j|
      if $rects[i][:pos][j] < 0
        $rects[i][:pos][j] = 0
        $rects[i][:vel][j] *= -1
      end

      if $rects[i][:pos][j] > DIM - $rects[i][:dim][j]
        $rects[i][:pos][j] = DIM - $rects[i][:dim][j]
        $rects[i][:vel][j] *= -1
      end
    }
  }
end

# Initialize physical variables
$rects = [
  { pos: POS1, dim: DIM1, vel: VEL1, col: COL1 },
  { pos: POS2, dim: DIM2, vel: VEL2, col: COL2 },
  { pos: POS3, dim: DIM3, vel: VEL3, col: COL3 }
]

# Start simulation
FRAMES.times.each do |t|
  $gif.images << Gifenc::Image.new(DIM, DIM, color: BG, delay: DELAY)
  update_positions
  draw_rectangles
end

# Export animation
$gif.save('test.gif')
