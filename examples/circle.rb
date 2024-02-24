require './lib/gifenc.rb'

palette = Gifenc::ColorTable.new([0xFFFFFF, 0])
gif = Gifenc::Gif.new(17, 17, gct: palette)
gif.images << Gifenc::Image.new(17, 17, color: 0).circle([8, 8], 5, nil, 1)
gif.save('test.gif')