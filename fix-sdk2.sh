#!/bin/bash
# 修复2: 给 sdkmanager 配上代理认证, 用官方渠道安装 SDK 包
set -euo pipefail
WORK="$HOME/workspace"
SDK="$WORK/android-sdk"
TOOLS="$WORK/tools"
export JAVA_HOME="$TOOLS/jdk17"
export PATH="$JAVA_HOME/bin:$SDK/cmdline-tools/latest/bin:$PATH"

log(){ echo ">>> $*"; }

# 从环境变量提取代理 host/port/用户名/密码, 组装成 JVM 参数(不打印密码)
export JDK_JAVA_OPTIONS="$(python3 - <<'PYEOF'
import os
from urllib.parse import urlparse, unquote
v = os.environ.get('https_proxy') or os.environ.get('HTTPS_PROXY') or ''
p = urlparse(v)
opts = []
for scheme in ('http', 'https'):
    opts.append(f"-D{scheme}.proxyHost={p.hostname}")
    opts.append(f"-D{scheme}.proxyPort={p.port}")
    if p.username:
        opts.append(f"-D{scheme}.proxyUser={unquote(p.username)}")
    if p.password:
        opts.append(f"-D{scheme}.proxyPassword={unquote(p.password)}")
print(' '.join(opts))
PYEOF
)"
log "JVM 代理参数已配置(密码不可见)"

log "测试 sdkmanager 连接..."
sdkmanager --list 2>&1 | grep -E "platforms;android-35|build-tools;35" | head -5

log "接受 licenses..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true

log "安装 SDK 包..."
sdkmanager --install "platform-tools" "platforms;android-35" "build-tools;35.0.0" 2>&1 | tail -3

log "SDK 内容:"
ls "$SDK"
ls "$SDK/platforms" "$SDK/build-tools"

# ---- 编译 ----
log "开始编译..."
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
