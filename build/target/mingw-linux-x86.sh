#!/bin/sh

DDK_ENV_TARGET_OS="windows"
DDK_ENV_TARGET_CPU="x86"

DDK_CROSS_HOME="/usr/bin"
DDK_CROSS_PREFIX="i686-w64-mingw32-"
DDK_ENV_INCLUDES="/usr/i686-w64-mingw32/include"
#DDK_ENV_LIBS="/usr/i686-w64-mingw32/lib /usr/lib/gcc/i686-w64-mingw32/4.9-win32"
DDK_ENV_LIBS="/usr/i686-w64-mingw32/lib /usr/lib/gcc/i686-w64-mingw32/7.3-win32"
DDK_CROSS_CFLAGS="${DDK_CROSS_CFLAGS} -m32"
DDK_CROSS_LDFLAGS="${DDK_CROSS_LDFLAGS} -m32"

DDC_STATIC_LIB_EXT="a"
DDC_SHARED_LIB_EXT="dll"
DDC_EXCUTE_EXT="exe"

