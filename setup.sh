#!/bin/bash
# 一键搭建: JDK 17 + Android SDK + Gradle, 创建 Hello World 工程并编译出 APK
set -euo pipefail

WORK="$HOME/workspace"
TOOLS="$WORK/tools"
SDK="$WORK/android-sdk"
PROJ="$WORK/android-helloworld"
APK_OUT="$WORK/your_files/HelloWorld-debug.apk"

log() { echo ">>> $*"; }

# ---------- 1. JDK 17 ----------
if [ ! -x "$TOOLS/jdk17/bin/java" ]; then
  log "下载 JDK 17 (Temurin)..."
  mkdir -p "$TOOLS"
  curl -sSL --retry 3 --max-time 900 -o /tmp/jdk17.tar.gz \
    "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse"
  mkdir -p "$TOOLS/jdk17"
  tar xzf /tmp/jdk17.tar.gz -C "$TOOLS/jdk17" --strip-components=1
  rm -f /tmp/jdk17.tar.gz
else
  log "JDK 17 已存在，跳过下载"
fi
export JAVA_HOME="$TOOLS/jdk17"
export PATH="$JAVA_HOME/bin:$PATH"
java -version 2>&1 | head -2

# ---------- 2. Android cmdline-tools ----------
if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  log "下载 Android cmdline-tools..."
  mkdir -p /tmp/cmdtools "$SDK/cmdline-tools/latest"
  curl -sSL --retry 3 --max-time 900 -o /tmp/cmdtools.zip \
    "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  unzip -q -o /tmp/cmdtools.zip -d /tmp/cmdtools
  cp -r /tmp/cmdtools/cmdline-tools/* "$SDK/cmdline-tools/latest/"
  rm -rf /tmp/cmdtools /tmp/cmdtools.zip
else
  log "cmdline-tools 已存在，跳过下载"
fi
export ANDROID_HOME="$SDK"
export ANDROID_SDK_ROOT="$SDK"
export PATH="$SDK/cmdline-tools/latest/bin:$SDK/platform-tools:$PATH"
sdkmanager --version

# ---------- 3. SDK packages ----------
log "安装 SDK 组件 (platform-tools, android-35, build-tools 35.0.0)..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true
sdkmanager --install "platform-tools" "platforms;android-35" "build-tools;35.0.0" 2>&1 | tail -2 || true

# ---------- 4. Gradle ----------
GRADLE_VER="8.10.2"
if [ ! -x "$TOOLS/gradle-$GRADLE_VER/bin/gradle" ]; then
  log "下载 Gradle $GRADLE_VER..."
  curl -sSL --retry 3 --max-time 900 -o /tmp/gradle.zip \
    "https://services.gradle.org/distributions/gradle-$GRADLE_VER-bin.zip"
  unzip -q -o /tmp/gradle.zip -d "$TOOLS"
  rm -f /tmp/gradle.zip
else
  log "Gradle $GRADLE_VER 已存在，跳过下载"
fi

# ---------- 5. 创建工程 ----------
log "创建 Hello World 工程..."
mkdir -p "$PROJ/app/src/main/java/com/example/helloworld" "$PROJ/gradle/wrapper"

cat > "$PROJ/settings.gradle" <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "HelloWorld"
include ':app'
EOF

cat > "$PROJ/build.gradle" <<'EOF'
plugins {
    id 'com.android.application' version '8.5.2' apply false
    id 'org.jetbrains.kotlin.android' version '2.0.21' apply false
}
EOF

cat > "$PROJ/app/build.gradle" <<'EOF'
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    namespace 'com.example.helloworld'
    compileSdk 35
    buildToolsVersion '35.0.0'

    defaultConfig {
        applicationId 'com.example.helloworld'
        minSdk 26
        targetSdk 35
        versionCode 1
        versionName '1.0'
    }
    buildTypes {
        debug {}
        release {
            minifyEnabled false
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = '17'
    }
}

dependencies {
}
EOF

cat > "$PROJ/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
org.gradle.workers.max=2
android.useAndroidX=false
android.nonTransitiveRClass=true
EOF

cat > "$PROJ/local.properties" <<EOF
sdk.dir=$SDK
EOF

cat > "$PROJ/app/src/main/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <application
        android:label="Hello World"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
EOF

cat > "$PROJ/app/src/main/java/com/example/helloworld/MainActivity.kt" <<'EOF'
package com.example.helloworld

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

class MainActivity : Activity() {

    private var count = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val hello = TextView(this).apply {
            text = "Hello World 👋"
            textSize = 34f
            gravity = Gravity.CENTER
        }

        val counter = TextView(this).apply {
            text = "你点了 0 次"
            textSize = 18f
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 24)
        }

        val button = Button(this).apply {
            text = "点我试试"
            setOnClickListener {
                count++
                counter.text = "你点了 $count 次"
                if (count == 10) {
                    Toast.makeText(this@MainActivity, "十全十美！", Toast.LENGTH_SHORT).show()
                }
            }
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            addView(hello)
            addView(counter)
            addView(button)
        }

        setContentView(layout)
    }
}
EOF

# ---------- 6. Gradle wrapper + 编译 ----------
cd "$PROJ"
if [ ! -f "$PROJ/gradlew" ]; then
  log "生成 Gradle wrapper..."
  "$TOOLS/gradle-$GRADLE_VER/bin/gradle" wrapper --gradle-version "$GRADLE_VER" --no-daemon -q
fi

log "开始编译 debug APK（首次会下载依赖，耗时较长）..."
./gradlew assembleDebug --no-daemon

APK="$PROJ/app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK" ]; then
  echo "ERROR: APK 未生成，编译可能失败" >&2
  exit 1
fi

# ---------- 7. 交付 ----------
mkdir -p "$WORK/your_files"
cp -f "$APK" "$APK_OUT"
log "完成！"
ls -lh "$APK_OUT"
sha256sum "$APK_OUT" | awk '{print "SHA256: " $1}'
