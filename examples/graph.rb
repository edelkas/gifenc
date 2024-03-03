require './lib/gifenc.rb'

DIM = 128

palette = Gifenc::ColorTable.new([0xFFFFFF, 0, 0xCCCCCC, 0x880000])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)
gif.images << Gifenc::Image.new(DIM, DIM, color: 0)
  #.grid(0, 0, DIM, DIM, 7, 7, 0, 0, color: 2, pattern: [1, 3], pattern_offsets: [0, 0])

5.times.each{ |w|
  gif.images.last.line(p1: [16, 8 * (w + 1)], p2: [112, 8 * (w + 1)], color: 1, weight: w + 1, style: :dotted)
}

gif.save('test.gif')