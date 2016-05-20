#!/bin/sh

DDK_ENV_HOME=$DFRAMEWORK_DDK_HOME

DDK_ENV_TARGET_OS="android"
DDK_ENV_TARGET_CPU="armv7"

DDK_CROSS_HOME="/usr/bin"
DDK_CROSS_PREFIX=""
DDK_ENV_INCLUDES="/usr/include"

DDC_STATIC_LIB_EXT="a"
DDC_SHARED_LIB_EXT="so"
DDC_EXCUTE_EXT=""


. "${DDK_ENV_HOME}/build/target/android-utils.sh"

