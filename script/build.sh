#!/usr/bin/env bash

# Define variables
BB_NAME="Enhanced"
BB_VER="v1.37.0.1"
BUILD_TYPE="BETA"
BB_BUILDER="eraselk@gacorprjkt"
NDK_VERSION="r27"
RUN_ID=${GITHUB_RUN_ID:-"local"}
ZIP_NAME="${BB_NAME}-BusyBox-${BB_VER}-${RUN_ID}.zip"
TZ="Asia/Makassar"
NDK_PROJECT_PATH="/home/runner/work/ndk-box-kitchen/ndk-box-kitchen"
BUILD_LOG="${NDK_PROJECT_PATH}/build.log"
BUILD_SUCCESS=""

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

upload_file() {
if [[ -z "$2" ]]; then
    	curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
		-F chat_id="${CHAT_ID}" \
		-F document=@"$1" \
		-o /dev/null
else
        curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
		-F chat_id="${CHAT_ID}" \
		-F document=@"$1" \
		-F caption="$2" \
		-o /dev/null
fi
}

send_msg() {
    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=$1" \
    -o /dev/null
}

send_msg "BusyBox CI Trigerred"
sleep 5
send_msg "==========================
BB_NAME=$BB_NAME BusyBox
BB_VERSION=$BB_VER
BUILD_TYPE=$BUILD_TYPE
BB_BUILDER=$BB_BUILDER
NDK_VERSION=$NDK_VERSION
CPU_CORES=$(nproc --all)
=========================="

START=$(date +"%s")
(

	# Update and upgrade packages
	sudo apt update -y && sudo apt upgrade -y

	# Set Time Zone (TZ)
	sudo ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime

	# Download NDK
	wget -q https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip
	unzip -q android-ndk-${NDK_VERSION}-linux.zip
	rm -f android-ndk-${NDK_VERSION}-linux.zip
	mv -f android-ndk-${NDK_VERSION} ndk

	# Clone Busybox
	git clone --depth=1 https://github.com/eraselk/busybox

	# Clone modules
	git clone --depth=1 https://android.googlesource.com/platform/external/selinux jni/selinux
	git clone --depth=1 https://android.googlesource.com/platform/external/pcre jni/pcre

	# generate Makefile
	if ! [[ -x "run.sh" ]]; then
		chmod +x run.sh
	fi

	bash run.sh generate

	# Build Busybox (arm64-v8a, armeabi-v7a, and x64)
	$NDK_PROJECT_PATH/ndk/ndk-build all -j"$(nproc --all)" && BUILD_SUCCESS=1 || BUILD_SUCCESS=0

	# Clone Module Template
	if [[ "$BUILD_SUCCESS" == "1" ]]; then
		git clone --depth=1 https://github.com/eraselk/busybox-template

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
	fi
) | tee -a ${BUILD_LOG}
END=$(date +"%s")
DIFF=$((END - START))
export minutes=$((DIFF / 60))
export seconds=$((DIFF % 60))
    
# Upload to Telegram

if [[ -f "${NDK_PROJECT_PATH}/${ZIP_NAME}" ]]; then
	upload_file "${NDK_PROJECT_PATH}/${ZIP_NAME}" "Build took ${minutes}m ${seconds}s
#${BUILD_TYPE} #${BB_NAME}BusyBox #${BB_VER}"
	upload_file "${BUILD_LOG}"
else
	upload_file "${BUILD_LOG}" "Build failed after ${minutes}m ${seconds}s"
fi
