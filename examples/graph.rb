require './lib/gifenc.rb'

DIM = 128

palette = Gifenc::ColorTable.new([0xFFFFFF, 0, 0xCCCCCC, 0x880000])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)
gif.images << Gifenc::Image.new(DIM, DIM, color: 0)
  .graph(-> (t) { t ** 2 }, -2, 2, -2, 5, x_scale: 16, y_scale: 10, color: 3, weight: 1, grid: true, grid_color: 2, axes_color: 1)


gif.save('test.gif')