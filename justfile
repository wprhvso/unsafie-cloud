set dotenv-load := true

fix:
    cd zig && zig fmt src/

run:
    cd zig && zig build run

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

ci-python-ruff:
    ruff check python/

ci-python-ruff-format:
    ruff format --check python/

ci-python-basedpyright:
    basedpyright python/

cd-all:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p dist/bin dist/packages android/app/src/main/jniLibs/arm64-v8a android/app/src/main/jniLibs/x86_64

    (cd zig && zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast && cp zig-out/bin/unsafie-cloud ../dist/bin/unsafie-cloud-x86_64-linux) &
    PID1=$!
    (cd zig && zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseFast && cp zig-out/bin/unsafie-cloud ../dist/bin/unsafie-cloud-aarch64-linux) &
    PID2=$!
    (cd zig && zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast && cp zig-out/bin/unsafie-cloud.exe ../dist/bin/unsafie-cloud-x86_64.exe) &
    PID3=$!
    (cd zig && zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast && cp zig-out/bin/unsafie-cloud ../dist/bin/unsafie-cloud-aarch64-macos) &
    PID4=$!
    (cd zig && zig build -Dtarget=x86_64-macos -Doptimize=ReleaseFast && cp zig-out/bin/unsafie-cloud ../dist/bin/unsafie-cloud-x86_64-macos) &
    PID5=$!
    (cd zig && zig build -Dtarget=aarch64-linux-android -Doptimize=ReleaseFast && cp zig-out/lib/libunsafie_core.so ../android/app/src/main/jniLibs/arm64-v8a/libunsafie_core.so) &
    PID6=$!
    (cd zig && zig build -Dtarget=x86_64-linux-android -Doptimize=ReleaseFast && cp zig-out/lib/libunsafie_core.so ../android/app/src/main/jniLibs/x86_64/libunsafie_core.so) &
    PID7=$!
    (python3 -m pip install build --quiet 2>/dev/null || true; python3 -m build python/ -o dist/packages/ 2>/dev/null || true) &
    PID8=$!

    wait $PID1 $PID2 $PID3 $PID4 $PID5 $PID6 $PID7 $PID8

    tar -czf dist/unsafie-cloud-linux-x86_64.tar.gz -C dist/bin unsafie-cloud-x86_64-linux
    tar -czf dist/unsafie-cloud-linux-aarch64.tar.gz -C dist/bin unsafie-cloud-aarch64-linux
    zip -j dist/unsafie-cloud-windows-x86_64.zip dist/bin/unsafie-cloud-x86_64.exe
    tar -czf dist/unsafie-cloud-macos-aarch64.tar.gz -C dist/bin unsafie-cloud-aarch64-macos
    tar -czf dist/unsafie-cloud-macos-x86_64.tar.gz -C dist/bin unsafie-cloud-x86_64-macos
    zip -j dist/unsafie-android.apk android/app/src/main/jniLibs/arm64-v8a/libunsafie_core.so android/app/src/main/AndroidManifest.xml

    VERSION=$(cat python/pyproject.toml | grep -o 'version = "[^"]*"' | cut -d'"' -f2 || echo "0.1.0")
    TAG="v${VERSION}"
    gh release create "${TAG}" dist/*.tar.gz dist/*.zip dist/*.apk dist/packages/* --title "Unsafie Cloud ${TAG}" --generate-notes || true
