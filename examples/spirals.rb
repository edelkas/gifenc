require 'gifenc'

# Initialize spiral parameters. They all have the same characteristics,
# except for the center, but we'll morph them in different ways
DIM            = 128                        # GIF size
CENTER1        = [DIM / 4, DIM / 4]         # Center of spiral 1
CENTER2        = [3 * DIM / 4, DIM / 4]     # Center of spiral 2
CENTER3        = [DIM / 4, 3 * DIM / 4]     # Center of spiral 3
CENTER4        = [3 * DIM / 4, 3 * DIM / 4] # Center of spiral 4
LOOPS          = 2                          # Loops per branch
STEP           = 15                         # Distance between loops
FRAMES         = 128                        # GIF frames

# Create a basic color table and a looping GIF using it as GCT
palette = Gifenc::ColorTable.new([0xEEEE88, 0, 0x880000, 0x000088])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)

# Render each frame. We will morph each spiral differently:
# Spiral 1: Rotating (changing the initial angle)
# Spiral 2: Scaling  (changing the step)
# Spiral 3: Tracing  (changing the loop count)
# Spiral 4: All of the above
0.upto(FRAMES).each{ |t|
  angle = 2 * Math::PI * t / FRAMES
  gif.images << Gifenc::Image.new(DIM, DIM, color: 0, delay: 2)
    .line(p1: [0, DIM / 2], p2: [DIM, DIM / 2], color: 1)
    .line(p1: [DIM / 2, 0], p2: [DIM / 2, DIM], color: 1)
    .spiral(CENTER1, STEP, LOOPS, angle: angle, color: 2, weight: 1)
    .spiral(CENTER1, -STEP, LOOPS, angle: angle, color: 3, weight: 1)
    .spiral(CENTER2, (t.to_f / FRAMES) * STEP, LOOPS, color: 2, weight: 1)
    .spiral(CENTER2, -(t.to_f / FRAMES) * STEP, LOOPS, color: 3, weight: 1)
    .spiral(CENTER3, STEP, (t.to_f / FRAMES) * LOOPS, color: 2, weight: 1)
    .spiral(CENTER3, -STEP, (t.to_f / FRAMES) * LOOPS, color: 3, weight: 1)
    .spiral(CENTER4, 4 * (1 - t.to_f / FRAMES) * STEP, (t.to_f / FRAMES) * LOOPS, angle: -angle, color: 2, weight: 1)
    .spiral(CENTER4, -4 * (1 - t.to_f / FRAMES) * STEP, (t.to_f / FRAMES) * LOOPS, angle: -angle, color: 3, weight: 1)
}

# Loop frames back in reverse order, and render
gif.boomerang
gif.save('test.gif')
