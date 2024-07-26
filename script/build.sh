#!/usr/bin/env bash

# Define variables
BB_NAME="Enhanced"
BB_VER="v1.37.0.1"
BB_BUILDER="eraselk@gacorprjkt"
NDK_VERSION="r27"
RUN_ID=${GITHUB_RUN_ID:-"local"}
ZIP_NAME="${BB_NAME}-BusyBox-${BB_VER}-${RUN_ID}.zip"
TZ="Asia/Makassar"
NDK_PROJECT_PATH="/home/runner/work/ndk-box-kitchen/ndk-box-kitchen"
BUILD_LOG="${NDK_PROJECT_PATH}/build.log"

# Export all variables
export BB_NAME BB_VER BB_BUILDER NDK_VERSION ZIP_NAME TZ NDK_PROJECT_PATH

# Check if TOKEN is set
if [[ -z "$TOKEN" ]]; then
  echo "Error: Variable TOKEN not defined"
  exit 1
fi

# Check if CHAT_ID is set
if [[ -z "$CHAT_ID" ]]; then
  echo "Error: Variable CHAT_ID not defined"
  exit 1
fi

{
  # Update and upgrade packages
  sudo apt update -y && sudo apt upgrade -y

  # Set Time Zone (TZ)
  sudo ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime

  # Download NDK
  wget -q https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download NDK"
    exit 1
  fi

  unzip -q android-ndk-${NDK_VERSION}-linux.zip
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to unzip NDK"
    exit 1
  fi

  rm -f android-ndk-${NDK_VERSION}-linux.zip
  mv -f android-ndk-${NDK_VERSION} ndk

  # Clone Busybox
  git clone --depth=1 https://github.com/eraselk/busybox
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to clone Busybox"
    exit 1
  fi

  # Clone modules
  git clone --depth=1 https://android.googlesource.com/platform/external/selinux jni/selinux
  git clone --depth=1 https://android.googlesource.com/platform/external/pcre jni/pcre

  # generate Makefile
  if ! [[ -x "run.sh" ]]; then
      chmod +x run.sh
  fi

  bash run.sh generate
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to generate Makefile"
    exit 1
  fi

  # Build Busybox (arm64-v8a, armeabi-v7a, and x64)
  $NDK_PROJECT_PATH/ndk/ndk-build all -j"$(nproc --all)"
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to build Busybox"
    exit 1
  fi

  # Clone Module Template
  git clone --depth=1 https://github.com/eraselk/busybox-template
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to clone Busybox template"
    exit 1
  fi

  rm -f $NDK_PROJECT_PATH/busybox-template/system/xbin/.placeholder

  # Copy binaries to template
  cp -f $NDK_PROJECT_PATH/libs/arm64-v8a/busybox $NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm64
  cp -f $NDK_PROJECT_PATH/libs/armeabi-v7a/busybox $NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm
  cp -f $NDK_PROJECT_PATH/libs/x86_64/busybox $NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-x64
  cp -f $NDK_PROJECT_PATH/libs/x86/busybox $NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-x86

  # Update version in module.prop
  sed -i "s/version=.*/version=${BB_VER}-${RUN_ID}/" $NDK_PROJECT_PATH/busybox-template/module.prop

  # Zip the template
  cd $NDK_PROJECT_PATH/busybox-template
  zip -r9 ${ZIP_NAME} *
  mv -f ${ZIP_NAME} $NDK_PROJECT_PATH
  cd $NDK_PROJECT_PATH
} | tee -a ${BUILD_LOG}

# Upload to Telegram
curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
-F chat_id="${CHAT_ID}" \
-F document=@${NDK_PROJECT_PATH}/${ZIP_NAME}
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to upload ZIP to Telegram"
  exit 1
fi

curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
-F chat_id="${CHAT_ID}" \
-F document=@${BUILD_LOG}
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to upload build log to Telegram"
  exit 1
fi
