set -o pipefail
echo "DEBIAN_FRONTEND=noninteractive apt-get install -y \\"
for DEB in archives/*.deb; do
  ar -t $DEB | grep "^control.tar" | while read -r FILE; do
    ar -p $DEB $FILE | tar  --zstd -xOv ./control 2>/dev/null | awk '/^Package:/ {pkg=$2} /^Version:/ {ver=$2} END { print "  " pkg "=" ver " \\"}'
  done
done
