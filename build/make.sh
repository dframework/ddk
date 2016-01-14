#!/bin/sh

#####################################################################
#
#

DDK_ENV_CMD=""
DDK_ENV_HOME=""
DDK_ENV_OUT=""
DDK_ENV_DEBUG=0
DDK_ENV_CALL_TARGET=""
DDK_ENV_TARGETS=""
DDK_ENV_TARGET_OS="linux"
DDK_ENV_TARGET_CPU="x86_64"
DDK_ENV_TARGET_PATH=""
DDK_ENV_TARGET_BUILD=""
DDK_ENV_TARGET_WORKING=""
DDK_ENV_NO_PRINT=0
DDK_ENV_PRINT_OS=0
DDK_ENV_PRINT_CPU=0
DDK_ENV_PRINT_TARGETS=0
DDK_ENV_PRINT_HELP=0
DDK_ENV_INCLUDES="/usr/include"
DDK_ENV_LIBS=""

DDK_ARG_CMD=""
DDK_ARG_DEST=""

DDK_SET_SUBDIRS=""
DDK_SET_NO_SUBDIRS=""

DDK_CC="gcc"
DDK_CPP="g++"
DDK_AR="ar rcs"
DDK_RANLIB="ranlib"

DDK_CROSS_HOME="/usr/bin"
DDK_CROSS_PREFIX=""

DDC_CC=""
DDC_CPP=""
DDC_AR=""
DDC_RANLIB=""
DDC_PWD=""
DDC_CFLAGS=""
DDC_LDFLAGS=""
DDC_STATIC_LIB_EXT="a"
DDC_SHARED_LIB_EXT="so"
DDC_EXCUTE_EXT=""

ddk_check_os(){
    case "${DDK_ENV_TARGET_OS}" in
    linux)
        return 0
    ;;
    windows)
        return 0
    ;;
    esac
    ddk_exit 1 "ERROR: Unknown target os (${1}). --print-os-list"
}

ddk_check_cpu(){
    case "${DDK_ENV_TARGET_CPU}" in
    x86)
        return 0
    ;;
    x86_64)
        return 0
    ;;
    amd64)
        return 0
    ;;
    i686)
        return 0
    ;;
    i386)
        return 0
    ;;
    esac
    ddk_exit 1 "ERROR: Unknown target cpu (${1}). --print-cpu-list"
}

ddk_print_os_list(){
    if [ $DDK_ENV_NO_PRINT -eq 1 ]; then
        return;
    fi
    echo ""
    echo "  DDK target os list"
    echo "  ------------------"
    echo "    linux"
    echo "    windows"
    echo ""
}

ddk_print_cpu_list(){
    if [ $DDK_ENV_NO_PRINT -eq 1 ]; then
        return;
    fi
    echo ""
    echo "  DDK target cpu list"
    echo "  -------------------"
    echo "    x86"
    echo "    x86_64"
    echo "    amd64"
    echo "    i686"
    echo "    i386"
    echo ""
}

ddk_print_targets(){
    if [ $DDK_ENV_NO_PRINT -eq 1 ]; then
        return;
    fi
    echo ""
    echo "  DDK targets"
    echo "  -------------------"
    echo "    linux-x86"
    echo "    linux-x86_64"
    echo "    mingw-linux-x86"
    echo "    mingw-linux-x86_64"
    #echo "    mingw-msys-x86"
    #echo "    mingw-msys-x86_64"
    echo ""
}

ddkinfo(){
    if [ $DDK_ENV_NO_PRINT -eq 1 ]; then
        return;
    fi
    echo ""
    echo "  DDK ENVIRONMENTS"
    echo "  ---------------------------------------------------------"
    echo ""
    echo "  DDK_ENV_HOME           : [${DDK_ENV_HOME}]"
    echo "  DDK_ENV_OUT            : [${DDK_ENV_OUT}]"
    echo "  DDK_ENV_DEBUG          : [${DDK_ENV_DEBUG}]"
    echo "  TARGET                 : [${DDK_ENV_CALL_TARGET}]"
    echo "  DDK_ENV_TARGET_OS      : [${DDK_ENV_TARGET_OS}]"
    echo "  DDK_ENV_TARGET_CPU     : [${DDK_ENV_TARGET_CPU}]"
    echo "  DDK_ENV_TARGET_PATH    : [${DDK_ENV_TARGET_PATH}]"
    echo "  DDK_ENV_TARGET_BUILD   : [${DDK_ENV_TARGET_BUILD}]"
    echo "  DDK_ENV_TARGET_WORKING : [${DDK_ENV_TARGET_WORKING}]"
    echo "  DDK_ENV_CMD            : [${DDK_ENV_CMD}]"
    echo "  DDC_PWD                : [${DDC_PWD}]"
    echo ""
    echo "  DDK_CC                 : [${DDK_CC}]"
    echo "  DDK_CPP                : [${DDK_CPP}]"
    echo "  DDK_AR                 : [${DDK_AR}]"
    echo "  DDK_RANLIB             : [${DDK_RANLIB}]"
    echo "  DDK_CROSS_PREFIX       : [${DDK_CROSS_PREFIX}]"
    echo "  DDK_CROSS_HOME         : [${DDK_CROSS_HOME}]"
    echo ""
    echo "  ---------------------------------------------------------"
    echo ""
}

ddk_print_help(){
    if [ $DDK_ENV_NO_PRINT -eq 1 ]; then
        return;
    fi
    echo " DDK helper"
    echo " -------------------"
    echo ""
    echo " Options:"
    echo "  --ddk-home     : "
    echo "  --debug        : "
    echo "  --help         : "
    echo "  --no-print     : "
    echo "  --print-os     : "
    echo "  --print-cpu    : "
    echo "  --add-target   : "
    echo "  --target-os    : "
    echo "  --target-cpu   : "
    echo "  --cross-prefix : "
    echo "  --cross-home   : "
    echo ""
}

ddk_check_global_vars(){
    if [ "${DDK_GLOBAL_ENV_HOME}" != "" ]; then
        DDK_ENV_HOME="${DDK_GLOBAL_ENV_HOME}"
    fi

    if [ "${DDK_GLOBAL_ENV_DEBUG}" != "" ]; then
        DDK_ENV_DEBUG=1
    fi

    if [ "$DDK_ENV_CALL_TARGET" = "" ]; then
        if [ "${DDK_GLOBAL_ENV_TARGETS}" != "" ]; then
            for tmp_x in $DDK_GLOBAL_ENV_TARGETS
            do
                ddk_add_target "${tmp_x}"
            done
        fi
    fi
}

ddk_add_target(){
    if [ "${1}" = "" ]; then
        return
    fi

    for tmp_y in $DDK_ENV_TARGETS
    do
        if [ "$tmp_y" = "${1}" ]; then
            return
        fi
    done
    DDK_ENV_TARGETS="$DDK_ENV_TARGETS $1"
}

ddk_ready_arguments_2(){
# check ddk_call_make function.
    case "${2}" in
    --ddk-home)
        if [ "${3}" = "" ]; then
            ddk_exit 1 "ERROR: ${1}th argument: ${2} value is empty."
        fi
        DDK_ENV_HOME="${3}"
    ;;
    --debug)
        DDK_ENV_DEBUG=1
    ;;
    --help)
        DDK_ENV_PRINT_HELP=1
    ;;
    --no-print)
        DDK_ENV_NO_PRINT=1
    ;;
    --print-os)
        DDK_ENV_PRINT_OS=1
    ;;
    --print-cpu)
        DDK_ENV_PRINT_CPU=1
    ;;
    --print-targets)
        DDK_ENV_PRINT_TARGETS=1
    ;;
    --add-target)
        ddk_add_target "${3}"
    ;;
    --target-os)
        DDK_ENV_TARGET_OS="${3}"
    ;;
    --target-cpu)
        DDK_ENV_TARGET_CPU="${3}"
    ;;
    --cross-prefix)
        DDK_CROSS_PREFIX="${3}"
    ;;
    --cross-home)
        DDK_CROSS_HOME="${3}"
    ;;
    --call-target)
        DDK_ENV_CALL_TARGET="${3}"
    ;;
    --arg-cmd)
        DDK_ARG_CMD="${3}"
    ;;
    --arg-dest)
        DDK_ARG_DEST="${3}"
    ;;
    *)
        ddk_exit 1 "ERROR: ${1}th argument: ${2}=${3}"
    ;;
    esac
    return 0
}

ddk_ready_arguments_1(){
    if [ $1 -eq 0 ]; then
        DDK_ENV_CMD="${2}"
        return 0
    fi

    ddk_exit 1 "ERROR: ${1}th argument: ${2}"
}

ddk_ready_ddk_env_home(){
    if [ "${DDK_ENV_HOME}" = "" ]; then
        if [ "${DFRAMEWORK_DDK_HOME}" = "" ]; then
            ddk_exit 1 "ERROR: Not find DFRAMEWORK_DDK_HOME environment variable."
        else
            DDK_ENV_HOME="${DFRAMEWORK_DDK_HOME}"
        fi
    fi
    if test ! -d "${DDK_ENV_HOME}"; then
        ddk_exit 1 "ERROR: [${DDK_ENV_HOME}] is not found."
    fi
    if test ! -d "${DDK_ENV_HOME}/build"; then
        ddk_exit 1 "ERROR: [${DDK_ENV_HOME}/build] is not found."
    fi
    if test ! -f "${DDK_ENV_HOME}/build/make.sh"; then
        ddk_exit 1 "ERROR: [${DDK_ENV_HOME}/build/make.sh] is not found."
    fi
}

ddk_ready_base_environments(){
    debug=""
    if [ $DDK_ENV_DEBUG -eq 1 ]; then
        debug="-debug"
    fi
    path="${DDK_ENV_TARGET_OS}-${DDK_ENV_TARGET_CPU}${debug}"
    DDK_ENV_OUT="${DDK_ENV_HOME}/out"
    DDK_ENV_TARGET_PATH="${DDK_ENV_OUT}/${path}"
    DDK_ENV_TARGET_BUILD="${DDK_ENV_TARGET_PATH}/build"
    DDK_ENV_TARGET_WORKING="${DDK_ENV_TARGET_PATH}/working"

    if [ "${DDK_CROSS_HOME}" = "" ]; then
      cross_prefix="${DDK_CROSS_PREFIX}"
    else
      cross_prefix="${DDK_CROSS_HOME}/${DDK_CROSS_PREFIX}"
    fi

    DDC_CC="${cross_prefix}${DDK_CC}"
    DDC_CPP="${cross_prefix}${DDK_CPP}"
    DDC_AR="${cross_prefix}${DDK_AR}"
    DDC_RANLIB="${cross_prefix}${DDK_RANLIB}"
}

ddk_make_base_environments(){
    ddk_make_dir "${DDK_ENV_OUT}"
    ddk_make_dir "${DDK_ENV_TARGET_PATH}"
    ddk_make_dir "${DDK_ENV_TARGET_BUILD}"
    ddk_make_dir "${DDK_ENV_TARGET_WORKING}"
}

ddk_target_environments(){
    if [ "${DDK_ENV_TARGETS}" = "" ]; then
        return 0
    fi

    for tmp_target in $DDK_ENV_TARGETS
    do
        if [ "$tmp_target" = "" ]; then
            continue
        fi

        target="${DDK_ENV_HOME}/build/target/${tmp_target}.sh"
        if test ! -f "${target}"; then
            ddk_exit 1 "error: not find target ${tmp_target}: $target"
        fi

        ddk_call_make "--call-target=${tmp_target}" "" "" "1"
    done
    exit 0
}

ddk_target_start(){
    if [ "${DDK_ENV_CALL_TARGET}" = "" ]; then
        return 0
    fi

    target="${DDK_ENV_HOME}/build/target/${DDK_ENV_CALL_TARGET}.sh"
    if test ! -f "$target"; then
        ddk_exit 1 "error: not find target ${target}"
    fi

    . $target
    return 0
}

ddk_exit(){
    if [ "${2}" != "" ]; then
        echo "${2}"
        echo ""
    fi
    if [ $1 -ne 0 ]; then
        exit $1
    fi
}

ddk_make_dir(){
    if test ! -d "${1}"; then
      mkdir -p "${1}"
      if [ $? -ne 0 ]; then
        ddk_exit 1 "    mkdir -p \"${INSTALLED_DIR}\" ... FAIL"
      fi
    fi
    return 0
}

#####################################################################
#
#

DDC_TEMP_ARGS=$@

DDC_PWD=`pwd`
xi=0
for x in $DDC_TEMP_ARGS
do
    xn=`expr "$x" : '\(^--[0-9a-zA-Z_-]\+\)[=]*[[:print:]]*'`
    xv=`expr "$x" : '^--[0-9a-zA-Z_-]\+[=]\{1\}\([[:print:]]\+\)'`
    if [ "${xn}" != "" ]; then
        ddk_ready_arguments_2 $xi "${xn}" "${xv}"
        ddk_exit $?
    else
        ddk_ready_arguments_1 $xi "${x}"
        ddk_exit $?
    fi
    xi=$(($xi+1))
done

if [ $DDK_ENV_PRINT_HELP -eq 1 ]; then
    ddk_print_help
    exit 0
fi

if [ $DDK_ENV_PRINT_OS -eq 1 ]; then
    ddk_print_os_list
    exit 0
fi

if [ $DDK_ENV_PRINT_CPU -eq 1 ]; then
    ddk_print_cpu_list
    exit 0
fi
if [ $DDK_ENV_PRINT_TARGETS -eq 1 ]; then
    ddk_print_targets
    exit 0
fi

ddk_check_global_vars

ddk_ready_ddk_env_home

. "${DDK_ENV_HOME}/build/lib/make_util.sh"
. "${DDK_ENV_HOME}/build/lib/make_mk.sh"
. "${DDK_ENV_HOME}/build/lib/make_cflags.sh"
. "${DDK_ENV_HOME}/build/lib/make_build.sh"
. "${DDK_ENV_HOME}/build/lib/make_calls.sh"
. "${DDK_ENV_HOME}/build/lib/make_plo.sh"

ddk_ready_base_environments

ddk_check_os

ddk_make_base_environments

ddk_target_environments

ddk_target_start

ddkinfo

ddk_working

if [ $DDK_ENV_NO_PRINT -eq 0 ]; then
    echo "  OK"
    echo ""
fi

