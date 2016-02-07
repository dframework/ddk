#!/bin/sh

# -------------------------------------------------------

XCODE_PATH=`xcode-select -print-path`

# -------------------------------------------------------

ddk_crosscp_ready(){
    local ARCH=$DDK_ENV_TARGET_CPU
    local PLATFORM=""
    local VERSION=""

    if [ ! -d "${XCODE_PATH}" ]; then
        echo "xcode path is not set correctly "
        echo "${XCODE_PATH} does not exist."
        exit 1
    fi

    case $XCODE_PATH in
        *\ * )
            echo "Your Xcode path contains whitespaces, "
            echo "which is not supported."
            exit 1
        ;;
    esac

    local ios_PWD=`pwd`
    case $ios_PWD in
        *\ * )
            echo "Your path contains whitespaces, "
            echo "which is not supported by 'make install'."
            exit 1
        ;;
    esac

    if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
        PLATFORM="iPhoneSimulator"
        VERSION=`xcrun -sdk iphoneos --show-sdk-version`
    elif [ "${ARCH}" == "tv_x86_64" ]; then
        ARCH="x86_64"
        PLATFORM="AppleTVSimulator"
        VERSION=`xcrun -sdk appletvos --show-sdk-version`
    elif [ "${ARCH}" == "tv_arm64" ]; then
        ARCH="arm64"
        PLATFORM="AppleTVOS"
        VERSION=`xcrun -sdk appletvos --show-sdk-version`
    else
        PLATFORM="iPhoneOS"
        VERSION=`xcrun -sdk iphoneos --show-sdk-version`
    fi

    local CFLAGS="${DDK_CROSS_CFLAGS} -pipe -Wno-unused-value"
    case $CFLAGS in
        armv7s) CFLAGS="${CFLAGS} -miphoneos-version-min=6" ;;
        arm64) CFLAGS="${CFLAGS} -miphoneos-version-min=7" ;;
        x86_64) CFLAGS="${CFLAGS} -miphoneos-version-min=8" ;;
    esac

    CFLAGS="${CFLAGS} -arch ${ARCH} -mcpu=cortex-a8 -marm"
    if [[ $VERSION == 9.* ]]; then
        CFLAGS="${CFLAGS} -fembed-bitcode"
    fi

    local XCODE_SDK=${PLATFORM}${VERSION}.sdk
    local DEVROOT=${XCODE_PATH}/Platforms/${PLATFORM}.platform/Developer
    local SDKROOT=${DEVROOT}/SDKs/${XCODE_SDK}

    DDK_CROSS_CFLAGS="${CFLAGS} -isysroot ${SDKROOT}"
    DDK_CROSS_LDFLAGS="${DDK_CROSS_LDFLAGS} -arch ${ARCH} --sysroot ${SDKROOT}"
    DDK_CROSS_HOME="${XCODE_PATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin"
    DDK_CROSS_PREFIX=""
    DDK_ENV_INCLUDES=""
    DDK_CC="clang"
    DDK_CXX="clang++"

}

# -------------------------------------------------------

ddk_crosscp_ready

