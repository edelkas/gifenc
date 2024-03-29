# gifenc

[![Gem Version](https://img.shields.io/gem/v/gifenc.svg)](https://rubygems.org/gems/gifenc)
[![Gem](https://img.shields.io/gem/dt/gifenc.svg)](https://rubygems.org/gems/gifenc)
[![Documentation](https://img.shields.io/badge/docs-grey.svg)](https://www.rubydoc.info/gems/gifenc)
[![Examples](https://img.shields.io/badge/examples-grey.svg)](https://github.com/edelkas/gifenc/tree/master/examples)

A Ruby library with no external dependencies that allows to encode, decode and edit GIFs. Its main goals are to:

* Support the full GIF [specification](https://www.w3.org/Graphics/GIF/spec-gif89a.txt) for both encoding and decoding.
* Achieve high encoding and decoding speeds via a native C extension.
* Have a decent suite of editing functionalities, so that the need for external tools is avoided as much as possible.
* Have a succint and comfortable syntax to use.

Currently, the specs are almost fully supported for encoding. Decoding is not yet available, but will be soon. There's a solid `Geometry` module and decent drawing functionality. See the [Reference](https://www.rubydoc.info/gems/gifenc) for the full documentation, as well as [Examples](https://github.com/edelkas/gifenc/tree/master/examples) for a list of sample snippets and GIFs.

## A first example

Consider the following GIF and the variation next to it. They already showcase most of the main elements of the format, including global and local color tables, transparency, animation, and different disposal methods. It also makes use of some basic drawing methods:

<p align="center">
<img src="https://github.com/edelkas/gifenc/raw/master/res/first_a.gif">
<img src="https://github.com/edelkas/gifenc/raw/master/res/first_b.gif">
</p>

The code to generate the first version with `Gifenc` is the following:

```ruby
require 'gifenc'

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
      14, 14, 16 * x + 1, 16 * y + 1, color: 8 * y + x, delay: 5, trans_color: 64
    ).rect(4, 4, 6, 6, 64, 64)
  end
end

# Export the GIF to a file
gif.save('test.gif')
```

Let's see a step-by-step overview, refer to the documentation for an in-depth explanation of the actual details for each of the topics involved.
1. The first thing we do is create two **Color Tables**, one with red shades, and another with green shades. Since GIF is an indexed image format, it can only use colors from predefined palettes of at most 256 colors. `Gifenc` comes equipped with several default ones, but you can build your own, and operate with them.
2. We create the GIF object. We select the red color table to be the **GCT** (_Global Color Table_), which is used for all frames that do not contain an explicit **LCT** (_Local Color Table_). We also set the GIF to loop indefinitely.
3. We create the first frame, this will act as the background. We use the green color table as LCT for this frame. We set a few attributes, such as the default color of the canvas, the length of the frame, and the color used for transparency. We draw a sequence of centered green squares, they will help to see the transparency of the next frames.
4. Now, we create a sequence of frames, each of them being a small square located at an offset of the canvas. Since they have no LCT, they will use the GCT, and will thus be red. We draw an even smaller square in their center with the transparent color, the background will then show through these holes in the GIF.
5. Finally, we export the GIF to a file, and voilà, we're done!

Producing the second variation is surprisingly simple. It suffices to add the option `disposal: Gifenc::DISPOSAL_PREV` to the frames (except for the background). More on this later.

See the [Examples](https://github.com/edelkas/gifenc/tree/master/examples) folder for more code samples; the resulting GIFs are stored [here](https://github.com/edelkas/gifenc/tree/master/res).

## Resources

The following are a few of the excellent resources one can find on the net to get a deep understanding of the GIF file format.
- [What's in a GIF](http://www.matthewflickinger.com/lab/whatsinagif/): Comprehensive description of the GIF file format, LZW compression, and other related aspects. Illustrated with diagrams and examples. Includes online tools to explore GIF contents.
- [Manipulating GIF Color Tables](https://www.codeproject.com/Articles/1042433/Manipulating-GIF-Color-Tables): Detailed breakdown of the format, including a very nice diagram. Develops an open source GIF manipulation tool in C#.
- [Inside the GIF file format](https://web.archive.org/web/20230315204422/https://commandlinefanatic.com/cgi-bin/showarticle.cgi?article=art011): Step by step explanation of a GIF decoder in C (has a similar article on [LZW compression](https://web.archive.org/web/20230315204422/http://commandlinefanatic.com/cgi-bin/showarticle.cgi?article=art010)).
- [Gifology](http://www.theimage.com/animation/toc/toc.html): Practical explanation of all the properties and elements of the GIF specification, with technical examples.
- [Web design in a nutshell](https://docstore.mik.ua/orelly/web2/wdesign/ch19_01.htm): Chapters 19 and 23 present an exposition of the GIF file format and how several elements of its specification work.
- [Wikipedia GIF article](https://en.wikipedia.org/wiki/GIF): History of the format, break down of its structure, and other related interesting topics.
- [GIF specification](https://www.w3.org/Graphics/GIF/spec-gif89a.txt): And of course, the original GIF specification, which details every field of every block.