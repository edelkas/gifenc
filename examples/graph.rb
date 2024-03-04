require './lib/gifenc.rb'

DIM = 128

palette = Gifenc::ColorTable.new([0xFFFFFF, 0, 0xCCCCCC, 0x880000])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)
gif.images << Gifenc::Image.new(DIM, DIM, color: 0)
  .grid(0, 0, DIM, DIM, 7, 7, 0, 0, color: 2, style: :dashed)


gif.save('test.gif')