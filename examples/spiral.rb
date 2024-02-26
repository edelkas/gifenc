require './lib/gifenc.rb'

DIM = 128
CENTER = [DIM / 2, DIM / 2]
LOOPS = 4
STEP = 10

palette = Gifenc::ColorTable.new([0xFFFFFF, 0])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)
gif.images << Gifenc::Image.new(DIM, DIM, color: 0, delay: 5)
  .curve(
    -> (t) { [STEP * t * Math.cos(t), STEP * t * Math.sin(t)] },
    0, LOOPS * 2 * Math::PI, step: Math::PI / 16, color: 1
  )

gif.save('test.gif')