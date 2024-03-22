require 'mkmf'
$CFLAGS << ' -Wall -O3'
create_makefile('cgifenc')