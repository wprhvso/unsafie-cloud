set dotenv-load := true
export ANSIBLE_CONFIG := "ansible/ansible.cfg"

default:
    @just --list

build:
    cd zig && zig build -Doptimize=ReleaseFast
    cd cli && zig build -Doptimize=ReleaseFast

run:
    cd zig && zig build run

check:
    cd zig && zig fmt --check src/
    cd cli && zig fmt --check src/

format:
    cd zig && zig fmt src/
    cd cli && zig fmt src/

host-setup:
    ansible-playbook -i ansible/hosts.ini ansible/site.yml

bootstrap:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/bootstrap.yml

hypervisors:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/hypervisors.yml


ci-check:
    cd zig && zig fmt --check src/
    cd cli && zig fmt --check src/
    python3 -m compileall sdk/

ci-test:
    cd zig && zig build test
    cd cli && zig build test
    python3 -m compileall sdk/

ci-build:
    cd zig && zig build -Doptimize=ReleaseFast
    cd cli && zig build -Doptimize=ReleaseFast

ci-build-all:
    mkdir -p dist/bin
    cd zig && zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
    cp zig/zig-out/bin/unsafie-cloud dist/bin/unsafie-cloud-x86_64-linux
    cd cli && zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
    cp cli/zig-out/bin/unsafie dist/bin/unsafie-x86_64-linux
    cd zig && zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseFast
    cp zig/zig-out/bin/unsafie-cloud dist/bin/unsafie-cloud-aarch64-linux
    cd cli && zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseFast
    cp cli/zig-out/bin/unsafie dist/bin/unsafie-aarch64-linux
    cd zig && zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast
    cp zig/zig-out/bin/unsafie-cloud.exe dist/bin/unsafie-cloud-x86_64.exe
    cd cli && zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast
    cp cli/zig-out/bin/unsafie.exe dist/bin/unsafie-x86_64.exe
    cd zig && zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast
    cp zig/zig-out/bin/unsafie-cloud dist/bin/unsafie-cloud-aarch64-macos
    cd cli && zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast
    cp cli/zig-out/bin/unsafie dist/bin/unsafie-aarch64-macos
    cd zig && zig build -Dtarget=x86_64-macos -Doptimize=ReleaseFast
    cp zig/zig-out/bin/unsafie-cloud dist/bin/unsafie-cloud-x86_64-macos
    cd cli && zig build -Dtarget=x86_64-macos -Doptimize=ReleaseFast
    cp cli/zig-out/bin/unsafie dist/bin/unsafie-x86_64-macos

ci-android:
    mkdir -p android/app/src/main/jniLibs/arm64-v8a
    mkdir -p android/app/src/main/jniLibs/x86_64
    cd zig && zig build -Dtarget=aarch64-linux-android -Doptimize=ReleaseFast
    cp zig/zig-out/lib/libunsafie_core.so android/app/src/main/jniLibs/arm64-v8a/
    cd zig && zig build -Dtarget=x86_64-linux-android -Doptimize=ReleaseFast
    cp zig/zig-out/lib/libunsafie_core.so android/app/src/main/jniLibs/x86_64/
    mkdir -p dist
    bash -c 'if [ -f android/app/build/outputs/apk/release/app-release.apk ]; then cp android/app/build/outputs/apk/release/app-release.apk dist/unsafie-android.apk; elif [ -f android/app/build/outputs/apk/debug/app-debug.apk ]; then cp android/app/build/outputs/apk/debug/app-debug.apk dist/unsafie-android.apk; else zip -j dist/unsafie-android.apk android/app/src/main/jniLibs/arm64-v8a/libunsafie_core.so android/app/src/main/AndroidManifest.xml; fi'

cd-package:
    mkdir -p dist/packages
    tar -czf dist/unsafie-linux-x86_64.tar.gz -C dist/bin unsafie-x86_64-linux unsafie-cloud-x86_64-linux
    tar -czf dist/unsafie-linux-aarch64.tar.gz -C dist/bin unsafie-aarch64-linux unsafie-cloud-aarch64-linux
    zip -j dist/unsafie-windows-x86_64.zip dist/bin/unsafie-x86_64.exe dist/bin/unsafie-cloud-x86_64.exe
    tar -czf dist/unsafie-macos-aarch64.tar.gz -C dist/bin unsafie-aarch64-macos unsafie-cloud-aarch64-macos
    tar -czf dist/unsafie-macos-x86_64.tar.gz -C dist/bin unsafie-x86_64-macos unsafie-cloud-x86_64-macos
    bash -c 'if command -v python3 >/dev/null 2>&1; then python3 -m pip install build --quiet 2>/dev/null || true; python3 -m build sdk/ -o dist/packages/ 2>/dev/null || true; fi'

cd-release:
    gh release create "${GITHUB_REF_NAME:-v1.0.0}" dist/*.tar.gz dist/*.zip dist/*.apk dist/packages/* --title "Unsafie Cloud ${GITHUB_REF_NAME:-v1.0.0}" --generate-notes
