set dotenv-load := true

fix:
    cd zig && zig fmt src/

run:
    cd zig && zig build run

ci: ci-zig-format ci-zig-test ci-android-lint ci-android-ktlint ci-python-ruff ci-python-ruff-format ci-python-basedpyright

ci-check: ci-zig-format ci-python-ruff ci-python-ruff-format ci-python-basedpyright ci-android-lint ci-android-ktlint

ci-test: ci-zig-test

ci-build:
    cd zig && zig build

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
    pid_linux_x86_64=$!
    (cd zig && zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseFast && cp zig-out/bin/unsafie-cloud ../dist/bin/unsafie-cloud-aarch64-linux) &
    pid_linux_aarch64=$!
    (cd zig && zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast && cp zig-out/bin/unsafie-cloud.exe ../dist/bin/unsafie-cloud-x86_64.exe) &
    pid_windows_x86_64=$!
    (cd zig && zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast && cp zig-out/bin/unsafie-cloud ../dist/bin/unsafie-cloud-aarch64-macos) &
    pid_macos_aarch64=$!
    (cd zig && zig build -Dtarget=x86_64-macos -Doptimize=ReleaseFast && cp zig-out/bin/unsafie-cloud ../dist/bin/unsafie-cloud-x86_64-macos) &
    pid_macos_x86_64=$!
    (cd zig && zig build -Dtarget=aarch64-linux-android -Doptimize=ReleaseFast && cp zig-out/lib/libunsafie_core.so ../android/app/src/main/jniLibs/arm64-v8a/libunsafie_core.so) &
    pid_android_arm64=$!
    (cd zig && zig build -Dtarget=x86_64-linux-android -Doptimize=ReleaseFast && cp zig-out/lib/libunsafie_core.so ../android/app/src/main/jniLibs/x86_64/libunsafie_core.so) &
    pid_android_x86_64=$!
    (python3 -m pip install build --quiet 2>/dev/null || true; python3 -m build python/ -o dist/packages/ 2>/dev/null || true) &
    pid_python_pkg=$!

    wait $pid_linux_x86_64 $pid_linux_aarch64 $pid_windows_x86_64 $pid_macos_aarch64 $pid_macos_x86_64 $pid_android_arm64 $pid_android_x86_64 $pid_python_pkg

    tar -czf dist/unsafie-cloud-linux-x86_64.tar.gz -C dist/bin unsafie-cloud-x86_64-linux
    tar -czf dist/unsafie-cloud-linux-aarch64.tar.gz -C dist/bin unsafie-cloud-aarch64-linux
    zip -j dist/unsafie-cloud-windows-x86_64.zip dist/bin/unsafie-cloud-x86_64.exe
    tar -czf dist/unsafie-cloud-macos-aarch64.tar.gz -C dist/bin unsafie-cloud-aarch64-macos
    tar -czf dist/unsafie-cloud-macos-x86_64.tar.gz -C dist/bin unsafie-cloud-x86_64-macos
    zip -j dist/unsafie-android.apk android/app/src/main/jniLibs/arm64-v8a/libunsafie_core.so android/app/src/main/AndroidManifest.xml

    VERSION=$(cat python/pyproject.toml | grep -o 'version = "[^"]*"' | cut -d'"' -f2 || echo "0.1.0")
    TAG="v${VERSION}"
    gh release create "${TAG}" dist/*.tar.gz dist/*.zip dist/*.apk dist/packages/* --title "Unsafie Cloud ${TAG}" --generate-notes || true
