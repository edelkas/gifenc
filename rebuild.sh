# Quick script to rebuild and reinstall the Gem locally, assuming Makefile didn't change
cd ext
make
cp cgifenc.so ../lib/cgifenc.so
make clean
cd ..
gem build
gem install gifenc-$1.gem
