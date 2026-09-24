# Hello World Android

A tiny experimental Android app (built and compiled on a cloud VM with Muse).

- Package: `com.example.helloworld`
- Version: `1.0` (versionCode 1)
- minSdk 26, targetSdk 35, compileSdk 35
- Pure Java, no dependencies, no XML layouts — everything is built in code.

The app shows **Hello World 👋** with a counter button ("点我试试"). Tapping it increments
the counter, and the 10th tap shows a toast: 十全十美！

## Build

In a normal Android environment (Android Studio or Gradle on your machine):

```bash
./gradlew assembleDebug
```

### Special note: manual build chain on this VM

The VM this project was first compiled on has no usable Gradle distribution access,
so it ships with `build.sh` — a manual toolchain that does the same job:

```
aapt2 link → javac → d8 → zipalign → apksigner
```

Requirements on that machine:

- JDK 17 at `~/workspace/tools/jdk17`
- Android SDK at `~/workspace/android-sdk`
  (platform-tools, platforms/android-35, build-tools/35.0.0)
- A debug keystore at `debug.keystore` (generated once by `build.sh` if missing)

Run it:

```bash
./build.sh   # produces app-debug.apk in the project root area
```
