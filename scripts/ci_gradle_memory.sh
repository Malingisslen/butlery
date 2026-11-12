#!/usr/bin/env bash
# The Android release build ran out of memory on the shared runner: the Gradle
# daemon was killed mid-build ("daemon disappeared unexpectedly") with no
# compile error. android/gradle.properties sizes the daemon for a developer
# machine, and the Kotlin daemon and the Dart AOT compiler then run beside it.
# This gives CI a smaller footprint through the user-level properties file,
# which overrides the project file for this runner only, and adds swap so a
# peak pushes pages out instead of getting the daemon killed.
set -euo pipefail

free -m | awk 'NR==2 {print "Memory before: " $2 " MB total, " $7 " MB available"}'

if ! swapon --show | grep -q .; then
  sudo fallocate -l 4G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile >/dev/null
  sudo swapon /swapfile
fi

mkdir -p "$HOME/.gradle"
cat >> "$HOME/.gradle/gradle.properties" <<'PROPS'
org.gradle.jvmargs=-Xmx2560M -XX:MaxMetaspaceSize=1g -XX:+HeapDumpOnOutOfMemoryError
kotlin.daemon.jvmargs=-Xmx1536M
org.gradle.workers.max=2
PROPS

free -m | awk 'NR==3 {print "Swap: " $2 " MB"}'
