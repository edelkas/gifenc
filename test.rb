require_relative 'lib/gifenc.rb'

reds = Gifenc::ColorTable.new(64.times.map{ |c| 4 * c << 16 | 0x40 })
greens = Gifenc::ColorTable.new(4.times.map{ |c| 64 * c << 8 | 0x40 })

gif = Gifenc::Gif.new(64, 64, gct: reds, loops: -1)
for z in (0 ... 4)
  gif.images << Gifenc::Image.new(
    64 - 16 * z, 64 - 16 * z, 8 * z, 8 * z, lct: greens, color: z, delay: 2
  )
end
for y in (0 ... 8)
  for x in (0 ... 8)
    gif.images << Gifenc::Image.new(7, 7, 8 * x + 1, 8 * y + 1, color: 8 * y + x, delay: 5)
  end
end
gif.save('test.gif')