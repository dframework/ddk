#!/bin/sh

DDK_NDK_LLVM_HOME=""
DDK_NDK_HOME=""
DDK_NDK_TOOLCHAINS_VERSION="4.9"
DDK_NDK_PLATFORM_VERSIONS="24 23 21 19 18 17 16 15 14 13 12 9 8 5 4 3"
#DDK_NDK_PLATFORM_VERSIONS="19 18 17 16 15 14 13 12 9 8 5 4 3"

ddk_crosscp_init()
{
  if [ "${ANDROID_NDK_HOME}" = "" ]; then
    local hom1
    local hom2
    hom1=`which ndk-build`
    hom2=`expr "${hom1}" : '\([[:print:]]\{1,\}\)/ndk-build\$'`
    DDK_NDK_HOME=${hom2}
    if [ "${DDK_NDK_HOME}" = "" ]; then
        echo "Not found ANDROID NDK HOME."
        exit 1
    fi
  else
    DDK_NDK_HOME=${ANDROID_NDK_HOME}
  fi

  if test ! -d ${DDK_NDK_HOME} ; then
      echo "Not found ANDROID_NDK_HOME."
      exit 1
  fi

  if test ! -f ${DDK_NDK_HOME}/ndk-build ; then
      echo "Not found ${DDK_NDK_HOME}/ndk-build."
      exit 1
  fi

#  echo "DDK_NDK_HOME: ${DDK_NDK_HOME}"
#  /home/chk/work/android-ndk-r20/toolchains/llvm/prebuilt/linux-x86_64/bin/

}

ddk_crosscp_get_hosttag() {
    local HOST_OS=$(uname -s)
    local HOST_ARCH=$(uname -m)
    case $HOST_OS in
        Darwin) HOST_OS=darwin ;;
        Linux) HOST_OS=linux ;;
        FreeBsd) HOST_OS=freebsd ;;
        CYGWIN*|*_NT-*) HOST_OS=cygwin;;
        *)
            echo "ERROR: Unknown host operating system: $HOST_OS"
            exit 1
        ;;
    esac

    case $HOST_ARCH in
        i?86) HOST_ARCH=x86 ;;
        x86_64) HOST_ARCH=x86_64 ;;
        *) 
           echo "ERROR: Unknown host CPU architecture: $HOST_ARCH"
           exit 1
       ;;
    esac

    # Detect 32-bit userland on 64-bit kernels
    local HOST_TAG="${HOST_OS}-${HOST_ARCH}"
    case $HOST_TAG in
      linux-x86_64|darwin-x86_64)
      # we look for x86_64 or x86-64 in the output of 'file' for our shell
      # the -L flag is used to dereference symlinks, just in case.
      file -L "$SHELL" | grep -q "x86[_-]64"
      if [ $? != 0 ]; then
        HOST_ARCH=x86
      fi
      ;;
    esac

    # Check that we have 64-bit binaries on 64-bit system, otherwise fallback
    # on 32-bit ones. This gives us more freedom in packaging the NDK.
    if [ $HOST_ARCH = x86_64 ]; then
      if [ ! -d $DDK_NDK_HOME/prebuilt/$HOST_TAG ]; then
        HOST_ARCH=x86
      fi
    fi

    HOST_TAG=$HOST_OS-$HOST_ARCH
    # Special case windows-x86 -> windows
    if [ $HOST_TAG = windows-x86 ]; then
      HOST_TAG=windows
    fi

    echo $HOST_TAG
}

ddk_crosscp_find_platform_version()
{
    local ver
    local sdk

    for ver in $DDK_NDK_PLATFORM_VERSIONS
    do
        sdk=${DDK_NDK_HOME}/platforms/android-${ver}/arch-${1}
        if test -d $sdk ; then
            return $ver
        fi
    done

    return 0
}

ddk_crosscp_ready(){
    local ARCH=${DDK_ENV_TARGET_CPU}
    local TOOLCHAINS=""
    local TOOLCHAINS_NM=""
    local TOOLCHAINS_VERSION=${DDK_NDK_TOOLCHAINS_VERSION}
    local VERSION=""
    local ORIGIN_PREFIX=""
    local PREFIX=""
    local PLATFORM=""
    local CC=""
    local CXX=""
    local CROSS_HOME=""

    local android_PWD=`pwd`
    case $android_PWD in
        *\ * )
            echo "Your path contains whitespaces, "
            echo "which is not supported by 'make install'."
            exit 1
        ;;
    esac

    local HOST_TAG=$(ddk_crosscp_get_hosttag)
    
    if [ $? -ne 0 ]; then
        exit 1
    fi

    case ${ARCH} in
        armv7)
            TOOLCHAINS_NM="arm-linux-androideabi"
            PREFIX="arm-linux-androideabi"
            PLATFORM="arm"
        ;;
        arm64)
            TOOLCHAINS_NM="aarch64-linux-android"
            PREFIX="aarch64-linux-android"
            PLATFORM="arm64"
        ;;
        x86)
            TOOLCHAINS_NM="x86"
            PREFIX="i686-linux-android"
            PLATFORM="x86"
        ;;
        x86_64)
            TOOLCHAINS_NM="x86_64"
            PREFIX="x86_64-linux-android"
            PLATFORM="x86_64"
        ;;
        *)
            echo "Unknown arch : $ARCH"
            exit 1
        ;;
    esac

    TOOLCHAINS="${TOOLCHAINS_NM}-${TOOLCHAINS_VERSION}"

    local cflags="${DDK_CROSS_CFLAGS} -pipe -Wno-unused-value"

    case ${ARCH} in
        armv7) cflags="${cflags} -marm" ;;
        arm64) cflags="${cflags}" ;;
        x86) cflags="${cflags}" ;;
        x86_64) cflags="${cflags}" ;;
    esac


    ddk_crosscp_find_platform_version "${PLATFORM}"
    VERSION=$?
    if [ $VERSION -eq 0 ]; then
        echo "Not found platform version for android. platform=${PLATFORM}"
        exit 1
    fi

    local DEVROOT=${DDK_NDK_HOME}/toolchains/${TOOLCHAINS}/prebuilt/${HOST_TAG}
    local SDKROOT=${DDK_NDK_HOME}/platforms/android-${VERSION}/arch-${PLATFORM}

    DDK_CROSS_CFLAGS="${cflags} -isysroot ${SDKROOT}"
    DDK_CROSS_LDFLAGS="${DDK_CROSS_LDFLAGS} -arch ${ARCH} --sysroot ${SDKROOT}"
    DDK_CROSS_HOME="${DEVROOT}/bin"
    DDK_CROSS_ORIGIN_PREFIX="${PREFIX}"
    DDK_CROSS_PREFIX="${PREFIX}-"
    DDK_ENV_INCLUDES=""

    DDK_CC="gcc"
    DDK_CXX="g++"

    if test ! -d $SDKROOT ; then
        echo "Not found $SDKROOT"
        exit 1
    fi

    if test ! -d $DDK_CROSS_HOME ; then
        echo "Not found $DDK_CROSS_HOME"
        exit 1
    fi

    if test ! -f ${DDK_CROSS_HOME}/${DDK_CROSS_PREFIX}${DDK_CC} ; then

        if [ "${DDK_CROSS_ORIGIN_PREFIX}" = "arm-linux-androideabi" ]; then
            ORIGIN_PREFIX="armv7a-linux-androideabi"
            PREFIX="${ORIGIN_PREFIX}-"
        elif [ "${DDK_CROSS_ORIGIN_PREFIX}" = "aarch64-linux-android" ]; then
            ORIGIN_PREFIX="aarch64-linux-android"
            PREFIX="${ORIGIN_PREFIX}-"
        elif [ "${DDK_CROSS_ORIGIN_PREFIX}" = "i686-linux-android" ]; then
            ORIGIN_PREFIX="i686-linux-android"
            PREFIX="${ORIGIN_PREFIX}-"
        elif [ "${DDK_CROSS_ORIGIN_PREFIX}" = "x86_64-linux-android" ]; then
            ORIGIN_PREFIX="x86_64-linux-android"
            PREFIX="${ORIGIN_PREFIX}-"
        fi

        CROSS_HOME="${DDK_NDK_HOME}/toolchains/llvm/prebuilt/${HOST_TAG}/bin"
        CC="${ORIGIN_PREFIX}${VERSION}-clang"
        CXX="${ORIGIN_PREFIX}${VERSION}-clang++"

        if test ! -f "${CROSS_HOME}/${CC}" ; then
            echo "Not found ${DDK_CROSS_HOME}/${DDK_CROSS_PREFIX}${DDK_CC} or ${CC}"
	    exit 1
	fi

        DDK_REAL_CC="${CROSS_HOME}/${CC}"
	DDK_REAL_CXX="${CROSS_HOME}/${CXX}"
    fi

}

# -------------------------------------------------------

ddk_crosscp_init

ddk_crosscp_ready

