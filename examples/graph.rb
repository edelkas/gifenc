require './lib/gifenc.rb'

# GIF and graph properties
DIM       = 128   # GIF width and height
FREQUENCY = 0.125 # Frequency steps, in multiples of PI, of the sinc wave to plot
STEPS     = 16    # How many plots, with different frequencies, to plot
DELAY     = 25    # Delay, in 1/100ths of a second, between frames

# Construct a basic color table with a few colors to use for the plot
# Also create a looping GIF object using this palette
palette = Gifenc::ColorTable.new([0xFFFFFF, 0, 0xBBBBFF, 0x880000, 0xDDDDFF, 0x000088])
gif = Gifenc::Gif.new(DIM, DIM, gct: palette, loops: -1)

# For each desired frame, add an image and plot the graph.
# Note that most parameters are optional! We use (almost) all of them here to
# showcase them, but denote them as either "mandatory", "recommended" or
# "optional".
# Most options are self-explanatory, nonetheless, see the "graph" function's docs
# for details on each and every param.
(FREQUENCY .. FREQUENCY * STEPS).step(FREQUENCY).each{ |f|
  gif.images << Gifenc::Image.new(DIM, DIM, color: 0, delay: DELAY)
    .graph(
      # Function and range (mandatory)
      -> (t) { Math.sin(Math::PI * f * t) / (Math::PI * f * t) }, # Draw a modulated sinc wave
      -2 * Math::PI, 2 * Math::PI, -0.5, 1.1,                     # X and Y range to plot

      # Plot position and scale (recommended)
      center:  [DIM / 2, 0.65 * DIM],                             # Also see "pos" option
      x_scale: 9,
      y_scale: 64,

      # Plot aspect (recommended)
      color:  3,
      weight: 1,

      # Grid parameters (optional)
      grid:         true,
      grid_color:   2,
      grid_weight:  1,
      grid_sep_x:   Math::PI / 2,                                 # Also see "grid_steps_x" option
      grid_sep_y:   0.25,                                         # Also see "grid_steps_y" option
      grid_style:   :dotted,
      grid_density: :normal,

      # Axes parameters (optional)
      axes:         true,
      axes_color:   1,
      axes_weight:  1,
      axes_style:   :style,
      axes_density: :normal,

      # Origin parameters (optional)
      origin:        true,
      origin_color:  1,
      origin_weight: 2,

      # Background parameters (optional)
      background:         true,
      background_color:   4,
      background_padding: 1,

      # Frame parameters (optional)
      frame:         true,
      frame_color:   5,
      frame_weight:  1,
      frame_style:   :dotted,
      frame_density: :normal
    )
}

# Export GIF file
gif.save('test.gif')