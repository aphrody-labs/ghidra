#!/usr/bin/env bash
# Build a single-jar Ghidra plus a JDK AOT cache (JEP 483 + 514, JDK 25+), then run analyzeHeadless on it.
# Usage: buildAotCache.sh <ghidra_install_dir> <out_dir>   (afterwards: aotHeadless.sh <out_dir> <headless args>)
# The custom GhidraClassLoader cannot be cached ("Unsupported location"), so the AOT path uses ghidra.jar + ghidra.JarRun.
set -euo pipefail
install=${1:?ghidra install dir}
out=${2:?output dir}
mkdir -p "$out"
"$install/support/buildGhidraJar" -output "$out/ghidra.jar"
train=$(mktemp -d)
trap 'rm -rf "$train"' EXIT
java -Xmx2G -XX:+UseCompactObjectHeaders -Djava.awt.headless=true \
  -XX:AOTCacheOutput="$out/ghidra.aot" -cp "$out/ghidra.jar" ghidra.JarRun \
  "$train" aot -import "$(command -v true)" -overwrite -noanalysis
cat >"$out/aotHeadless.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
d=$(dirname "$(readlink -f "$0")")
exec java -Xmx2G -XX:+UseCompactObjectHeaders -Djava.awt.headless=true -XX:AOTCache="$d/ghidra.aot" -cp "$d/ghidra.jar" ghidra.JarRun "$@"
EOF
chmod +x "$out/aotHeadless.sh"
echo "AOT cache: $out/ghidra.aot"
