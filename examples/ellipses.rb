require 'gifenc'

# GIF and ellipses dimensions and center
DIM = 128
A = DIM / 2 - 1
B = DIM / 6
C = [DIM / 2, DIM / 2]

# Construct a basic color table and a looping GIF
palette = Gifenc::ColorTable.new([0xEEEE88, 0, 0x000088, 0x880000])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)

# Render each ellipse pair in a different, fully opaque frame
0.upto(A - B).each{ |i|
  gif.images << Gifenc::Image.new(DIM, DIM, color: 0, delay: 4)
    .ellipse(C, [A - i, B + i], 2, 1, weight: 5)
    .ellipse(C, [(B + i) / 3, (A - i) / 3], 3, 0, weight: 2)
}

# Loop backwards and save
gif.boomerang
gif.save('test.gif')