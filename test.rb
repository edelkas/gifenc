require_relative 'lib/gifenc.rb'

# Build a couple color tables
reds = Gifenc::ColorTable.new(64.times.map{ |c| 4 * c << 16 | 0x40 } + [0])
greens = Gifenc::ColorTable.new(4.times.map{ |c| 64 * c << 8 | 0x40 })

# Paint a first frame that will act as a background, using a local color table
gif = Gifenc::Gif.new(128, 128, gct: reds, loops: -1)
gif.images << Gifenc::Image.new(128, 128, lct: greens, color: 0, delay: 2, trans_color: 0)
(1 ... 4).each do |z|
  gif.images.last.rect(16 * z, 16 * z, 128 - 32 * z, 128 - 32 * z, z, z)
end

# Add animation frames drawing a gradient, using the global color table
(0 ... 8).each do |y|
  (0 ... 8).each do |x|
    gif.images << Gifenc::Image.new(
      14, 14, 16 * x + 1, 16 * y + 1, color: 8 * y + x, delay: 5, trans_color: 64, disposal: 3
    ).rect(4, 4, 6, 6, 64, 64)
  end
end

# Export the GIF to a file
gif.save('test.gif')