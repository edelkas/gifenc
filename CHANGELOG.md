# Changelog

### 0.2.1 (18/Mar/2024)

Improved the image copy method:

* Automatically corrects both source and destination offsets / dimensions to prevent any out of bounds errors.
* Allows to "copy with transparency", which will copy every color except for the transparent one.
* Allows to specify a bounding box to which the copying should be restricted to.

### 0.2.0 (05/Mar/2024)

A big update, with the main changes being divided in two categories: mathematical methods and drawing methods.

- Added a `Geometry` module that abstracts a lot of mathematical - and more specifically geometrical - functionality, that is useful throughout the program, but particularly for drawing. A Point class is included, which represents both 2D points and vectors, depending on context. This module includes:
  * Bound checking, calculation of bounding boxes and convex hulls.
  * Changes of coordinates, cartesian and polar coordinate support, etc.
  * Point operations, such as translations, dilations / scalings, linear and convex combinations, scalar product, center of mass, etc.
  * Point transformations, such as rotations, projections and reflections.
  * Norms (L1, euclidean, supremum), normalization, distances.
  * Angles, parallelism, orthogonality, normal vectors...

- Significantly expanded the drawing functionality, including:
  * Improved line drawing, and added line styles (dashed, dotted, etc).
  * Added circles and general (axis-aligned) ellipses.
  * Added grids, polygonal chains and spirals.
  * Arbitrary parametric curves and function graphs given a lambda function.
  * Implemented the flood fill / bucket tool.
  * Added a general Brush class to enable more flexible drawing.

Many sample GIFs, showcasing all this new functionality, were added in the [Examples](https://github.com/edelkas/gifenc/tree/master/examples) folder as well.

- Additional new functionality includes:
  * Copy: Ability to copy a region from one image to another.
  * Compress: Ability to LZW-compress image data on the fly, instead of keeping
    everything raw in memory until final encode time. Particularly helpful for
    GIFs with thousands of frames on systems with low memory.

### 0.1.0 (14/Feb/2024)

Initial release. Includes:

- Encoding working, with support for most of the specification (missing interlacing and Plain Text / Comment extensions).
- Basic color table and image manipulation.
- A few drawing primitives (lines and rectangles).