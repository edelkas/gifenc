#include "main.h"

void Init_cgifenc() {
  VALUE m_gifenc = rb_const_get(rb_cObject, rb_intern("Gifenc"));
  VALUE c_image = rb_const_get(m_gifenc, rb_intern("Image"));

  rb_define_singleton_method(m_gifenc, "lzw_encode", lzw_encode, 1);
  rb_define_method(c_image, "copy_raw", copy_raw, -1);
}

VALUE copy_raw(int argc, VALUE* argv, VALUE self) {
  VALUE src, opt_dx, opt_dy, opt_ox, opt_oy, opt_lx, opt_ly, opt_trans, bg;
  rb_scan_args(argc, argv, "9", &src, &opt_dx, &opt_dy, &opt_ox, &opt_oy, &opt_lx, &opt_ly, &opt_trans, &bg);
  long
    dx = FIX2LONG(opt_dx), dy = FIX2LONG(opt_dy),
    ox = FIX2LONG(opt_ox), oy = FIX2LONG(opt_oy),
    lx = FIX2LONG(opt_lx), ly = FIX2LONG(opt_ly);
  bool trans = RTEST(opt_trans);
  if (!FIXNUM_P(bg)) trans = false;

  long self_w = FIX2LONG(rb_funcall(self, rb_intern("width"), 0));
  long src_w  = FIX2LONG(rb_funcall(src,  rb_intern("width"), 0));
  VALUE* self_pix = RARRAY_PTR(rb_funcall(self, rb_intern("pixels"), 0));
  VALUE* src_pix  = RARRAY_PTR(rb_funcall(src,  rb_intern("pixels"), 0));

  long x, y;
  VALUE px;
  for(y = 0; y < ly; y++) {
    for(x = 0; x < lx; x++) {
      px = src_pix[(oy + y) * src_w + ox + x];
      if (trans && px == bg) continue;
      self_pix[(dy + y) * self_w + dx + x] = px;
    }
  }

  return self;
}