# Script to rebuild and reinstall the gem locally
# Usage: ./reinstall.sh VERSION
# Example: ./reinstall.sh 0.2.1
./rebuild.sh
gem build
gem install gifenc-$1.gem
