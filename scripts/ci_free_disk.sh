#!/usr/bin/env bash
# GitHub's ubuntu runners start with ~14 GB free; the Android emulator image
# alone wants 7+ GB and a Gradle release build several more. Remove toolchains
# these jobs never use, and print the result so a tight disk shows up in the
# log before it turns into "No space left on device" further down.
set -euo pipefail

df -h / | tail -1 | awk '{print "Disk before cleanup: " $4 " free"}'
sudo rm -rf /usr/share/dotnet /opt/ghc /usr/local/.ghcup /usr/local/share/boost \
  /opt/hostedtoolcache/CodeQL /usr/local/lib/node_modules/.cache || true
df -h / | tail -1 | awk '{print "Disk after cleanup: " $4 " free"}'
