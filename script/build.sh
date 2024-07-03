#!/usr/bin/env bash
set -e

# Define variables
export BB_NAME="Enhanced"
export BB_VER="v1.36.1-1"
export BB_BUILDER="eraselk@gacorprjkt"
export NDK_VERSION="r27-beta2"
export ZIP_NAME="${BB_NAME}-BusyBox-${BB_VER}-${RUN_ID}.zip"
export TZ="Asia/Makassar"
export NDK_PROJECT_PATH="/home/runner/work/ndk-box-kitchen/ndk-box-kitchen"

# check $TOKEN
if [[ -z "$TOKEN" ]]; then
echo "Error: Variable TOKEN not defined"
exit 1
fi

# check $CHAT_ID
if [[ -z "$CHAT_ID" ]]; then
echo "Error: Variable CHAT_ID not defined"
exit 1
fi

# Package
sudo apt update -y && sudo apt upgrade -y

#;Set Time Zone (TZ)
sudo ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime

# Download NDK
wget -q https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip
unzip -q android-ndk-${NDK_VERSION}-linux.zip
rm -f android-ndk-${NDK_VERSION}-linux.zip
mv -f android-ndk-${NDK_VERSION} ndk

# Clone Busybox
git clone --depth=1 https://github.com/eraselk/busybox

# Clone modules
git clone --depth=1 https://github.com/eraselk/pcre jni/pcre
git clone --depth=1 https://github.com/eraselk/selinux jni/selinux

# Apply Patches and Generate Makefile
if ! [[ -x "run.sh" ]]; then
    chmod +x run.sh
fi
bash run.sh patch
bash run.sh generate

# Build busybox (arm64-v8a, armeabi-v7a, and x64)
/home/runner/work/ndk-box-kitchen/ndk-box-kitchen/ndk/ndk-build all

# Clone Module Template
git clone --depth=1 https://github.com/eraselk/busybox-template

# Move busybox binaries to module template
rm -f /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-template/system/xbin/.placeholder
# arm64-v8a
cp -f /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/libs/arm64-v8a/busybox /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-template/system/xbin/busybox-arm64
# armeabi-v7a
cp -f /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/libs/armeabi-v7a/busybox /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-template/system/xbin/busybox-arm
# x64
#cp -f /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/libs/x86_64/busybox /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-x64
#
sed -i "s/version=.*/version=${BB_VER}-${RUN_ID}/" /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-template/module.prop

# Zipping
cd /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-template
zip -r9 ${ZIP_NAME} *
mv -f ${ZIP_NAME} /home/runner/work/ndk-box-kitchen/ndk-box-kitchen
cd /home/runner/work/ndk-box-kitchen/ndk-box-kitchen

# Upload to Telegram
curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
-F chat_id="${CHAT_ID}" \
-F document=@"/home/runner/work/ndk-box-kitchen/ndk-box-kitchen/${ZIP_NAME}" 

# Upload busybox x86_64 binary to bashupload.com
#curl -T /home/runner/work/ndk-box-kitchen/ndk-box-kitchen/busybox-x64 bashupload.com