#!/bin/bash
# 修复3: XML 可下载了 -> 解析出精确包地址, curl 下载 SDK; 用本地 Gradle(跳过 wrapper 下载)编译
set -euo pipefail
WORK="$HOME/workspace"
SDK="$WORK/android-sdk"
TOOLS="$WORK/tools"
export JAVA_HOME="$TOOLS/jdk17"
export PATH="$JAVA_HOME/bin:$PATH"

log(){ echo ">>> $*"; }

# ---- 1. 解析 repository xml, 下载 SDK 包 ----
mkdir -p "$SDK/platforms" "$SDK/build-tools" /tmp/sdkdl
cd /tmp/sdkdl

if [ ! -x "$SDK/platform-tools/adb" ]; then
  log "下载 platform-tools..."
  curl -fSL --retry 3 --max-time 600 -o pt.zip \
    "https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
  rm -rf "$SDK/platform-tools"
  unzip -q -o pt.zip -d "$SDK"
  rm -f pt.zip
else
  log "platform-tools 已存在"
fi

if [ ! -f "$SDK/platforms/android-35/android.jar" ]; then
  log "下载 repository2-1.xml..."
  curl -fSL --retry 3 --max-time 120 -o repo.xml \
    "https://dl.google.com/android/repository/repository2-1.xml"
  ls -la repo.xml
  head -c 120 repo.xml; echo

  python3 - <<'PYEOF' > urls.txt
import re
xml = open('/tmp/sdkdl/repo.xml', encoding='utf-8').read()
assert '<remotePackage' in xml, "xml 内容不对"

def linux_url(path):
    m = re.search(r'<remotePackage path="%s">' % re.escape(path), xml)
    if not m:
        return None
    # 取从该 remotePackage 开始到下一个 remotePackage 之间的片段
    seg = xml[m.start():m.start()+20000]
    nxt = seg.find('<remotePackage path="', 20)
    if nxt > 0:
        seg = seg[:nxt]
    for am in re.finditer(r'<archive>.*?</archive>', seg, re.S):
        ab = am.group(0)
        if '<host-os>linux</host-os>' in ab:
            u = re.search(r'<url>(.*?)</url>', ab)
            if u:
                return u.group(1).strip()
    return None

plat_url = linux_url('platforms;android-35')
assert plat_url, "找不到 platforms;android-35"
bt_url = linux_url('build-tools;35.0.0')
bt_ver = '35.0.0'
if not bt_url:
    cands = sorted(set(re.findall(r'<remotePackage path="(build-tools;[\d.]+)">', xml)))
    assert cands, "找不到任何 build-tools"
    bt_path = cands[-1]
    bt_ver = bt_path.split(';')[1]
    bt_url = linux_url(bt_path)
    assert bt_url, "找不到 " + bt_path
    print("NOTE fallback build-tools ->", bt_ver)
print('platforms;android-35 ' + plat_url)
print('build-tools;' + bt_ver + ' ' + bt_url)
print("BTVER=" + bt_ver)
PYEOF
  cat urls.txt

  BTVER=$(grep '^BTVER=' urls.txt | cut -d= -f2)
  grep -v '^BTVER=' urls.txt > dl.txt || true

  BASE="https://dl.google.com/android/repository"
  while read -r path url; do
    [ -z "$path" ] && continue
    fname=$(basename "$url")
    log "下载 $path ($fname)..."
    curl -fSL --retry 3 --max-time 900 -o "$fname" "$BASE/$url"
    tmpd=$(mktemp -d)
    unzip -q -o "$fname" -d "$tmpd"
    rm -f "$fname"
    top=$(ls "$tmpd")
    case "$path" in
      platforms*) dest="$SDK/platforms/android-35" ;;
      build-tools*) dest="$SDK/build-tools/$BTVER" ;;
    esac
    log "安装到 $dest (包内顶层: $top)"
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    mv "$tmpd/$top" "$dest"
    rm -rf "$tmpd"
  done < dl.txt

  if [ "$BTVER" != "35.0.0" ]; then
    sed -i "s/buildToolsVersion '[^']*'/buildToolsVersion '$BTVER'/" \
      "$WORK/android-helloworld/app/build.gradle"
  fi
else
  log "android-35 平台已存在"
fi

# ---- 2. license 文件 ----
log "写入 license 文件..."
mkdir -p "$SDK/licenses"
printf '8933bad161af4178b1185d1a37fbf41ea5269c55\nd56f5187479451eabf01d78af1dfb2b1e577a15c\n84831b9409646a918e6ef8464cf5c5aca\n' \
  > "$SDK/licenses/android-sdk-license"
ls "$SDK" "$SDK/platforms" "$SDK/build-tools"

# ---- 3. 编译(用本地 Gradle, 跳过 wrapper 的分发包下载) ----
log "开始编译..."
cd "$WORK/android-helloworld"
export ANDROID_HOME="$SDK" ANDROID_SDK_ROOT="$SDK"
export PATH="$SDK/platform-tools:$PATH"
GRADLE_BIN="$TOOLS/gradle-8.10.2/bin/gradle"

try_build() {
  "$GRADLE_BIN" assembleDebug "$1" > /tmp/build.log 2>&1
  return $?
}

set +e
if try_build ""; then
  code=0
else
  log "常规模式失败, 改用 --no-daemon 重试..."
  try_build "--no-daemon"; code=$?
fi
set -e

tail -30 /tmp/build.log
if [ $code -ne 0 ]; then
  echo "BUILD FAILED, 完整日志: /tmp/build.log" >&2
  exit $code
fi

APK="$WORK/android-helloworld/app/build/outputs/apk/debug/app-debug.apk"
mkdir -p "$WORK/your_files"
cp -f "$APK" "$WORK/your_files/HelloWorld-debug.apk"
log "编译成功！"
ls -lh "$WORK/your_files/HelloWorld-debug.apk"
