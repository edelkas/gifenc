require './lib/gifenc.rb'

DIM            = 128
CENTER         = [DIM / 2, DIM / 2]
LOOPS          = 4
STEP           = 15
CONTROL_POINTS = 64

palette = Gifenc::ColorTable.new([0xFFFFFF, 0, 0x880000, 0x000088])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)
gif.images << Gifenc::Image.new(DIM, DIM, color: 0)
  .line(p1: [0, DIM / 2], p2: [DIM, DIM / 2], color: 1)
  .line(p1: [DIM / 2, 0], p2: [DIM / 2, DIM], color: 1)
  .curve(
    -> (t) {
      [
        CENTER[0] + STEP * t * Math.cos(t) / (2 * Math::PI),
        CENTER[1] + STEP * t * Math.sin(t) / (2 * Math::PI)
      ]
    },
    0, LOOPS * 2 * Math::PI, step: 2 * Math::PI / CONTROL_POINTS,
    line_color: 2, line_weight: 1
  ).curve(
    -> (t) {
      [
        CENTER[0] - STEP * t * Math.cos(t) / (2 * Math::PI),
        CENTER[1] - STEP * t * Math.sin(t) / (2 * Math::PI)
      ]
    },
    0, LOOPS * 2 * Math::PI, step: 2 * Math::PI / CONTROL_POINTS,
    line_color: 3, line_weight: 1
  )


gif.save('test.gif')
