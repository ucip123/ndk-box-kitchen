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
VERSION_CODE="${BB_VER//v/}"
VERSION_CODE="${VERSION_CODE//./}"
BUILD_SUCCESS=""

# Export all variables
export BB_NAME BB_VER BB_BUILDER NDK_VERSION ZIP_NAME TZ NDK_PROJECT_PATH

# Check if TOKEN is set
if [[ -z ${TOKEN} ]]; then
	echo "Error: Variable TOKEN not defined"
        exit 1
fi

# Check if CHAT_ID is set
if [[ -z ${CHAT_ID} ]]; then
	echo "Error: Variable CHAT_ID not defined"
        exit 1
fi
upload_file() {
	local file_path=$1
	local caption=$2

	if [[ -n $caption ]]; then
		curl -s -F document=@"${file_path}" "https://api.telegram.org/bot$TOKEN/sendDocument" \
			-F chat_id="$CHAT_ID" \
			-F "parse_mode=html" \
			-F caption="$caption"
	else
		curl -s -F document=@"${file_path}" "https://api.telegram.org/bot$TOKEN/sendDocument" \
			-F chat_id="$CHAT_ID"
	fi
}

send_msg() {
	local message=$1

	curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
		-d chat_id="$CHAT_ID" \
		-d "parse_mode=html" \
		-d text="$message"
}

send_msg "<b>BusyBox CI Triggered</b>"
sleep 5
send_msg "<code>==========================
BB_NAME=${BB_NAME} BusyBox
BB_VERSION=${BB_VER}
BUILD_TYPE=${BUILD_TYPE}
BB_BUILDER=${BB_BUILDER}
NDK_VERSION=${NDK_VERSION}
CPU_CORES=$(nproc --all)
==========================</code>"

START=$(date +"%s")
(
	sudo apt update -y && sudo apt upgrade -y
	sudo ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime

	curl -sL "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" -o android-ndk-${NDK_VERSION}-linux.zip
	unzip -q android-ndk-${NDK_VERSION}-linux.zip
	rm -f android-ndk-${NDK_VERSION}-linux.zip
	mv -f android-ndk-${NDK_VERSION} ndk

	git clone --depth=1 https://github.com/eraselk/busybox || {
		echo "Failed to clone Busybox"
		exit 1
	}
	git clone --depth=1 https://android.googlesource.com/platform/external/selinux jni/selinux || {
		echo "Failed to clone selinux"
		exit 1
	}
	git clone --depth=1 https://android.googlesource.com/platform/external/pcre jni/pcre || {
		echo "Failed to clone pcre"
		exit 1
	}

	[[ -x "run.sh" ]] || chmod +x run.sh

	bash run.sh generate || {
		echo "Failed to generate Makefile"
		exit 1
	}

	$NDK_PROJECT_PATH/ndk/ndk-build all -j"$(nproc --all)" && BUILD_SUCCESS=1 || BUILD_SUCCESS=0

	if [[ ${BUILD_SUCCESS} == "1" ]]; then
		git clone --depth=1 https://github.com/eraselk/busybox-template || {
			echo "Failed to clone Busybox template"
			exit 1
		}

		rm -f "$NDK_PROJECT_PATH/busybox-template/system/xbin/.placeholder"

		cp -f "$NDK_PROJECT_PATH/libs/arm64-v8a/busybox" "$NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm64"
		cp -f "$NDK_PROJECT_PATH/libs/armeabi-v7a/busybox" "$NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-arm"
		cp -f "$NDK_PROJECT_PATH/libs/x86_64/busybox" "$NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-x64"
		cp -f "$NDK_PROJECT_PATH/libs/x86/busybox" "$NDK_PROJECT_PATH/busybox-template/system/xbin/busybox-x86"

		sed -i "s/version=.*/version=${BB_VER}-${RUN_ID}/" "$NDK_PROJECT_PATH/busybox-template/module.prop"
		sed -i "s/versionCode=.*/versionCode=${VERSION_CODE}/" "$NDK_PROJECT_PATH/busybox-template/module.prop"

		cd "$NDK_PROJECT_PATH/busybox-template"
		zip -r9 "${ZIP_NAME}" *
		mv -f "${ZIP_NAME}" "$NDK_PROJECT_PATH"
		cd "$NDK_PROJECT_PATH"
	fi
) | tee -a "${BUILD_LOG}"

END=$(date +"%s")
DIFF=$((END - START))
minutes=$((DIFF / 60))
seconds=$((DIFF % 60))

if [[ -f "${NDK_PROJECT_PATH}/${ZIP_NAME}" ]]; then
	upload_file "$NDK_PROJECT_PATH/$ZIP_NAME" "<b>Build took ${minutes}m ${seconds}s</b>
#${BUILD_TYPE} #${BB_NAME}BusyBox #${VERSION_CODE}"
	upload_file "$BUILD_LOG" "<b>Build log for ${BB_NAME} ${BB_VER}</b>"
else
	upload_file "$BUILD_LOG" "<b>Build failed after ${minutes}m ${seconds}s</b>"
fi
