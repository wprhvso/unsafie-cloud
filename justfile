set dotenv-load := true

fix:
    cd zig && zig fmt src/

run:
    cd zig && zig build run

gen-rules:
    cd zig && zig build gen-rules

build-static:
    cd zig && zig build -Doptimize=ReleaseFast

ci-check:
    cd zig && zig fmt --check src/

ci-test:
    cd zig && zig build test

ci-build:
    cd zig && zig build -Doptimize=ReleaseFast

ci-zig-format:
    cd zig && zig fmt --check src/

ci-zig-test:
    cd zig && zig build test

ci-android-ktlint:
    ktlint "android/**/*.kt"

ci-android-format:
    ktlint -F "android/**/*.kt"

ci-android-lint:
    bash -c 'test -f android/app/src/main/AndroidManifest.xml && test -f android/app/build.gradle'

cd-all:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p dist android/app/src/main/jniLibs/arm64-v8a android/app/src/main/jniLibs/x86_64

    (cd zig && zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast && cp zig-out/bin/unsafie ../dist/unsafie-x86_64-linux) &
    PID1=$!
    (cd zig && zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseFast && cp zig-out/bin/unsafie ../dist/unsafie-aarch64-linux) &
    PID2=$!
    (cd zig && zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast && cp zig-out/bin/unsafie.exe ../dist/unsafie-x86_64.exe) &
    PID3=$!
    (cd zig && zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast && cp zig-out/bin/unsafie ../dist/unsafie-aarch64-macos) &
    PID4=$!
    (cd zig && zig build -Dtarget=x86_64-macos -Doptimize=ReleaseFast && cp zig-out/bin/unsafie ../dist/unsafie-x86_64-macos) &
    PID5=$!
    (cd zig && zig build -Dtarget=aarch64-linux-android -Doptimize=ReleaseFast && cp zig-out/lib/libunsafie_core.so ../android/app/src/main/jniLibs/arm64-v8a/libunsafie_core.so) &
    PID6=$!
    (cd zig && zig build -Dtarget=x86_64-linux-android -Doptimize=ReleaseFast && cp zig-out/lib/libunsafie_core.so ../android/app/src/main/jniLibs/x86_64/libunsafie_core.so) &
    PID7=$!

    wait $PID1 $PID2 $PID3 $PID4 $PID5 $PID6 $PID7

    zip -j dist/unsafie-android.apk android/app/src/main/jniLibs/arm64-v8a/libunsafie_core.so android/app/src/main/AndroidManifest.xml

    VERSION=$(awk -F '[Count"= ]+' '/^\.version[ ]*=/ {gsub(/[\047",]/, "", $2); print $2}' zig/build.zig.zon)
    if [ -z "$VERSION" ]; then
        echo "Error: VERSION could not be extracted from zig/build.zig.zon" >&2
        exit 1
    fi
    TAG="v${VERSION}"
    gh release create "${TAG}" dist/* --title "Unsafie ${TAG}" --generate-notes
