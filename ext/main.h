#ifndef GIFENC
#define GIFENC

#include <stdint.h>  // uint8_t, ...
#include <stdio.h>   // FILE
#include <stdlib.h>  // malloc, free
#include <string.h>  // memset, memcpy
#include <stdbool.h> // true, false

#include "ruby.h"

void Init_cgifenc();
VALUE lzw_encode(VALUE self, VALUE data);
VALUE copy_raw(int argc, VALUE* argv, VALUE self);

#endif