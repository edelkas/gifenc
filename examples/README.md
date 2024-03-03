The following animated GIFs have been generated with the code samples present in this folder. The corresponding GIF files are available in the `res` folder.
**Note**: Depending on your settings and browser, you may need to click on them or hit play to begin playback.

|Description|GIF|
|---|:---:|
|**first.rb** <br>First example from the main readme. Here we test some of the basic features of the GIF format, including animation, transparency, disposal method, etc.|![First example GIF](../res/first_a.gif)|
|**clock.rb** <br>Several methods from the `Geometry` module are used here to perform auxiliary calculations. We also test some more drawing primitives, such as lines.|![Clock GIF](../res/clock.gif)|
|**anchor.rb** <br>Experimenting with different `anchoring` settings for a rectangle's border. This controls whether the border is drawn inside the rectangle's boundary, outside it, centered, or any inbetween. The default is inside.|![Anchor GIF](../res/anchor.gif)|
|**circles.rb** <br>Experimenting with different `style` settings for a circle's border. This controls whether the border is drawn either as concentric circles (`:smooth`, bottom right) or by subsequently adding grid layers around the inner border (`:grid`, top left). The default is `:smooth`.|![Circles GIF](../res/circles.gif)|
|**ellipses.rb** <br>Some more drawing primitives. Morphing ellipses with border.|![Ellipses GIF](../res/ellipses.gif)|
|**spirals.rb** <br>Gifenc allows to trace parametric curves. In this example, we trace 4 similar archimedean spirals, morphing them in different ways (rotating, scaling, tracing, and all 3 of them). |![Spirals GIF](../res/spirals.gif)|
|**star.rb** <br>Tracing of a pointed star. This example showcases another geometrica tool: reflections, since we trace each side by progressively reflecting a vertex about one of the star's diagonals. |![Star GIF](../res/star.gif)|
|**hull.rb** <br>Tracing the convex hull of a random sample of points, and using the flood fill / bucket tool to color the interior once the trace is done. We also plot the center of mass of the points at the end.|![Convex hull GIF](../res/hull.gif)|