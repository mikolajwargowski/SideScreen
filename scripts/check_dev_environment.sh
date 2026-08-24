#!/bin/bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FAILURES=0

pass() { echo "PASS  $1"; }
warn() { echo "WARN  $1"; }
fail() { echo "FAIL  $1"; FAILURES=$((FAILURES + 1)); }

echo "SideScreen development environment"
echo "Repository: $ROOT_DIR"
echo

if xcodebuild -version >/dev/null 2>&1; then
    pass "Xcode: $(xcodebuild -version | tr '\n' ' ')"
else
    fail "Xcode is unavailable or its license has not been accepted"
fi

if swift --version >/dev/null 2>&1; then
    pass "Swift: $(swift --version 2>&1 | head -1)"
else
    fail "Swift toolchain not found"
fi

if [ -n "${JAVA_HOME:-}" ]; then
    JAVA_CANDIDATE="$JAVA_HOME"
elif [ -x "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/java" ]; then
    JAVA_CANDIDATE="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
else
    JAVA_CANDIDATE="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

if [ -x "$JAVA_CANDIDATE/bin/java" ]; then
    JAVA_VERSION="$($JAVA_CANDIDATE/bin/java -version 2>&1 | head -1)"
    JAVA_MAJOR="$($JAVA_CANDIDATE/bin/java -XshowSettings:properties -version 2>&1 | awk '/java.specification.version/ {print $3; exit}')"
    if [ "$JAVA_MAJOR" = "17" ]; then
        pass "Java: $JAVA_CANDIDATE ($JAVA_VERSION)"
    else
        fail "JDK 17 is required by the current Gradle/Kotlin toolchain; found Java $JAVA_MAJOR at $JAVA_CANDIDATE"
    fi
else
    fail "JDK 17 not found; install openjdk@17 or set JAVA_HOME"
fi

SDK_CANDIDATE="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$SDK_CANDIDATE" ]; then
    if [ -d "/opt/homebrew/share/android-commandlinetools" ]; then
        SDK_CANDIDATE="/opt/homebrew/share/android-commandlinetools"
    elif [ -d "$HOME/Library/Android/sdk" ]; then
        SDK_CANDIDATE="$HOME/Library/Android/sdk"
    fi
fi

if [ -n "$SDK_CANDIDATE" ] && [ -d "$SDK_CANDIDATE" ]; then
    pass "Android SDK root: $SDK_CANDIDATE"
else
    fail "Android SDK root not found"
fi

if [ -n "$SDK_CANDIDATE" ] && [ -f "$SDK_CANDIDATE/platforms/android-34/android.jar" ]; then
    pass "Android platform 34"
else
    fail "Android platform 34 is not installed"
fi

if [ -n "$SDK_CANDIDATE" ] && [ -d "$SDK_CANDIDATE/build-tools/34.0.0" ]; then
    pass "Android build-tools 34.0.0"
else
    fail "Android build-tools 34.0.0 are not installed"
fi

if command -v adb >/dev/null 2>&1; then
    pass "ADB: $(adb version | head -1)"
    DEVICE_LINES="$(adb devices -l 2>/dev/null | tail -n +2 | sed '/^[[:space:]]*$/d')"
    if echo "$DEVICE_LINES" | grep -q ' device '; then
        pass "Authorized Android device connected"
    elif echo "$DEVICE_LINES" | grep -q ' unauthorized'; then
        fail "Android device connected but USB debugging is not authorized"
    else
        warn "No authorized Android device connected"
    fi
else
    fail "adb not found"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "Environment ready."
    exit 0
fi

echo "$FAILURES blocking prerequisite(s) remain."
exit 1
