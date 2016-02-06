#!/bin/sh

IOS_PWD=`pwd`
IOS_SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`
#TVOS_SDKVERSION=`xcrun -sdk appletvos --show-sdk-version`
# To set "enable-ec_nistp_64_gcc_128" configuration for x64 archs set next variable to "true"
IOS_ENABLE_EC_NISTP_64_GCC_128=""
IOS_XCODE_PATH=`xcode-select -print-path`
IOS_PLATFORM=""

# -------------------------------------------------------

ddk_crosscp_print(){
    echo ""
    echo " IOS_SDKVERSION : ${IOS_SDKVERSION}"
    echo " IOS_XCODE_PATH : ${IOS_XCODE_PATH}"
    echo " IOS_ARCH       : ${IOS_ARCH}"
    echo " IOS_SDK        : ${IOS_SDK}"
    echo " DDK_DEVROOT    : ${DDK_DEVROOT}"
    echo " DDK_SDKROOT    : ${DDK_SDKROOT}"
    echo ""
}

ddk_crosscp_ready(){
    IOS_ARCH=$DDK_ENV_TARGET_CPU

    if [ ! -d "${IOS_XCODE_PATH}" ]; then
        echo "xcode path is not set correctly "
        echo "${IOS_XCODE_PATH} does not exist."
        exit 1
    fi

    case $IOS_XCODE_PATH in
        *\ * )
            echo "Your Xcode path contains whitespaces, "
            echo "which is not supported."
            exit 1
        ;;
    esac

    case $IOS_PWD in
        *\ * )
            echo "Your path contains whitespaces, "
            echo "which is not supported by 'make install'."
            exit 1
        ;;
    esac

    if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]]; then
        IOS_PLATFORM="iPhoneSimulator"
    elif [ "${IOS_ARCH}" == "tv_x86_64" ]; then
        IOS_ARCH="x86_64"
        IOS_PLATFORM="AppleTVSimulator"
    elif [ "${IOS_ARCH}" == "tv_arm64" ]; then
        IOS_ARCH="arm64"
        IOS_PLATFORM="AppleTVOS"
    else
        IOS_PLATFORM="iPhoneOS"
    fi

    IOS_SDK="${IOS_PLATFORM}${IOS_SDKVERSION}.sdk"
    DDK_DEVROOT=${IOS_XCODE_PATH}/Platforms/${IOS_PLATFORM}.platform/Developer
    DDK_SDKROOT=${DDK_DEVROOT}/SDKs/${IOS_SDK}

    DDK_CROSS_CFLAGS="-arch ${IOS_ARCH} -mcpu=cortex-a8 -marm"
    if [[ $SDKVERSION == 9.* ]]; then
        DDK_CROSS_CFLAGS="${DDK_CROSS_CFLAGS} -fembed-bitcode"
        DDK_CROSS_CPPFLAGS=""
    else
        DDK_CROSS_CPPFLAGS=""
    fi

    DDK_CROSS_CFLAGS="${DDK_CROSS_CFLAGS} -isysroot ${DDK_SDKROOT}"
    DDK_CROSS_LDFLAGS="${DDK_CROSS_LDFLAGS} -isysroot ${DDK_SDKROOT}"
    DDK_CROSS_LDFLAGS="${DDK_CROSS_LDFLAGS}  -Wl, -syslibroot ${DDK_SDKROOT}"
    DDK_CROSS_HOME="${IOS_XCODE_PATH}/usr/bin"
    DDK_CROSS_PREFIX=""
    DDK_ENV_INCLUDES=""

#    echo " DDK_CROSS_HOME : $DDK_CROSS_HOME"
}


# -------------------------------------------------------

ddk_crosscp_ready

#ddk_crosscp_print


