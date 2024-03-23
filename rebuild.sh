# Script to rebuild the native extension, assuming Makefile didn't change
cd ext
make
cp cgifenc.so ../lib/cgifenc.so
make clean
cd ..
