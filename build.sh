#!/bin/bash
# 手动编译 Android APK: aapt2 link -> javac -> d8 -> zipalign -> apksigner
# (本机 Gradle 走代理有兼容问题, 此脚本用 curl 可达的工具链完成同样工作)
set -euo pipefail

PROJ="$HOME/workspace/android-helloworld"
SDK="$HOME/workspace/android-sdk"
BT="$SDK/build-tools/35.0.0"
ANDROID_JAR="$SDK/platforms/android-35/android.jar"
export JAVA_HOME="$HOME/workspace/tools/jdk17"
export PATH="$JAVA_HOME/bin:$PATH"
BUILD="$PROJ/manual-build"

log(){ echo ">>> $*"; }

rm -rf "$BUILD"
mkdir -p "$BUILD/classes" "$BUILD/dex"

log "aapt2 link: 打包 AndroidManifest.xml"
"$BT/aapt2" link -o "$BUILD/base.apk" \
  -I "$ANDROID_JAR" \
  --manifest "$PROJ/app/src/main/AndroidManifest.xml" \
  --min-sdk-version 26 --target-sdk-version 35 \
  --version-code 1 --version-name 1.0

log "javac: 编译 Java 源码"
find "$PROJ/app/src/main/java" -name "*.java" > "$BUILD/sources.txt"
if ! javac -encoding UTF-8 -source 8 -target 8 -cp "$ANDROID_JAR" \
    -d "$BUILD/classes" @"$BUILD/sources.txt" > "$BUILD/javac.log" 2>&1; then
  cat "$BUILD/javac.log"
  exit 1
fi
grep -v "bootstrap class path" "$BUILD/javac.log" || true

log "d8: class 转 dex"
"$BT/d8" --min-api 26 --lib "$ANDROID_JAR" \
  --output "$BUILD/dex" $(find "$BUILD/classes" -name "*.class")

log "组装 APK (加入 classes.dex)"
cp "$BUILD/base.apk" "$BUILD/unsigned.apk"
python3 - "$BUILD/unsigned.apk" "$BUILD/dex/classes.dex" <<'PYEOF'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1], 'a', zipfile.ZIP_DEFLATED)
z.write(sys.argv[2], 'classes.dex')
z.close()
print("classes.dex 已加入 APK")
PYEOF

if [ -x "$BT/zipalign" ]; then
  log "zipalign: 对齐优化"
  "$BT/zipalign" -f 4 "$BUILD/unsigned.apk" "$BUILD/aligned.apk"
else
  cp "$BUILD/unsigned.apk" "$BUILD/aligned.apk"
fi

log "生成 debug 签名证书(仅首次)"
if [ ! -f "$PROJ/debug.keystore" ]; then
  keytool -genkeypair -keystore "$PROJ/debug.keystore" -alias androiddebugkey \
    -keyalg RSA -keysize 2048 -validity 10950 \
    -storepass android -keypass android \
    -dname "CN=Android Debug,O=Android,C=US" 2>/dev/null
fi

log "apksigner: 签名 APK"
"$BT/apksigner" sign --ks "$PROJ/debug.keystore" \
  --ks-pass pass:android --key-pass pass:android \
  --out "$BUILD/app-debug.apk" "$BUILD/aligned.apk"

log "验签"
"$BT/apksigner" verify --print-certs "$BUILD/app-debug.apk" | head -4

mkdir -p "$HOME/workspace/your_files"
cp -f "$BUILD/app-debug.apk" "$HOME/workspace/your_files/HelloWorld-debug.apk"
log "完成:"
ls -lh "$HOME/workspace/your_files/HelloWorld-debug.apk"
