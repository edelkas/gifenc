#include "main.h"

void Init_cgifenc() {
  VALUE module = rb_const_get(rb_cObject, rb_intern("Gifenc"));

  rb_define_singleton_method(module, "lzw_encode", lzw_encode, 1);
}