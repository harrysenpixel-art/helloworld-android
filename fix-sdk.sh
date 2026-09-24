#!/bin/bash
# 修复: 绕过 sdkmanager 的代理问题, 直接用 curl 下载 SDK 包; 配置 Gradle 代理后重新编译
set -euo pipefail
WORK="$HOME/workspace"
SDK="$WORK/android-sdk"
TOOLS="$WORK/tools"
export JAVA_HOME="$TOOLS/jdk17"
export PATH="$JAVA_HOME/bin:$PATH"

log(){ echo ">>> $*"; }

# ---- 1. Gradle 走代理(带认证) ----
log "配置 Gradle 代理..."
python3 - <<'PYEOF'
import os
from urllib.parse import urlparse
v = os.environ.get('https_proxy') or os.environ.get('HTTPS_PROXY') or ''
p = urlparse(v)
lines = []
for scheme in ('http', 'https'):
    lines.append(f"systemProp.{scheme}.proxyHost={p.hostname}")
    lines.append(f"systemProp.{scheme}.proxyPort={p.port}")
    if p.username:
        lines.append(f"systemProp.{scheme}.proxyUser={p.username}")
        lines.append(f"systemProp.{scheme}.proxyPassword={p.password}")
lines.append("systemProp.http.nonProxyHosts=localhost|127.0.0.1")
lines.append("systemProp.https.nonProxyHosts=localhost|127.0.0.1")
os.makedirs(os.path.expanduser('~/.gradle'), exist_ok=True)
with open(os.path.expanduser('~/.gradle/gradle.properties'), 'w') as f:
    f.write('\n'.join(lines) + '\n')
print("proxy configured for gradle")
PYEOF

# ---- 2. 直接下载 SDK 包 ----
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
  log "解析 repository xml 获取精确包地址..."
  curl -sSL --retry 3 --max-time 120 -o repo.xml \
    "https://dl.google.com/android/repository/repository2-1.xml"

  python3 - <<'PYEOF' > urls.txt
import re
xml = open('/tmp/sdkdl/repo.xml', encoding='utf-8').read()

def linux_url(path):
    m = re.search(r'<remotePackage path="%s">.*?</remotePackage>' % re.escape(path), xml, re.S)
    if not m:
        return None
    for am in re.finditer(r'<archive>.*?</archive>', m.group(0), re.S):
        ab = am.group(0)
        if '<host-os>linux</host-os>' in ab:
            return re.search(r'<url>(.*?)</url>', ab).group(1).strip()
    return None

plat = 'platforms;android-35'
bt = linux_url('build-tools;35.0.0')
bt_ver = '35.0.0'
if not bt:
    # 回退: 取最新的 build-tools
    cands = sorted(set(re.findall(r'<remotePackage path="(build-tools;[\d.]+)">', xml)))
    bt_path = cands[-1]
    bt_ver = bt_path.split(';')[1]
    bt = linux_url(bt_path)
    print("FALLBACK build-tools ->", bt_ver)
print(plat + ' ' + linux_url(plat))
print('build-tools;' + bt_ver + ' ' + bt)
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
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    mv "$tmpd/$top" "$dest"
    rm -rf "$tmpd"
  done < dl.txt

  if [ "$BTVER" != "35.0.0" ]; then
    log "build-tools 使用 $BTVER, 同步更新 app/build.gradle"
    sed -i "s/buildToolsVersion '[^']*'/buildToolsVersion '$BTVER'/" \
      "$WORK/android-helloworld/app/build.gradle"
  fi
else
  log "android-35 平台已存在"
fi

# ---- 3. license 文件(标准 hash, 等同于 sdkmanager --licenses 接受) ----
log "写入 license 文件..."
mkdir -p "$SDK/licenses"
printf '8933bad161af4178b1185d1a37fbf41ea5269c55\nd56f5187479451eabf01d78af1dfb2b1e577a15c\n84831b9409646a918e6ef8464cf5c5aca\n' \
  > "$SDK/licenses/android-sdk-license"

# ---- 4. 编译 ----
log "SDK 就绪，开始编译..."
cd "$WORK/android-helloworld"
export ANDROID_HOME="$SDK" ANDROID_SDK_ROOT="$SDK"
export PATH="$SDK/platform-tools:$PATH"
set +e
./gradlew assembleDebug --no-daemon > /tmp/build.log 2>&1
code=$?
set -e
tail -30 /tmp/build.log
if [ $code -ne 0 ]; then
  echo "BUILD FAILED (exit $code), 完整日志: /tmp/build.log" >&2
  exit $code
fi

APK="$WORK/android-helloworld/app/build/outputs/apk/debug/app-debug.apk"
mkdir -p "$WORK/your_files"
cp -f "$APK" "$WORK/your_files/HelloWorld-debug.apk"
log "编译成功！"
ls -lh "$WORK/your_files/HelloWorld-debug.apk"
