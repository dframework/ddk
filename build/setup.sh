#!/bin/sh

#####################################################################
#
#

DDK_ENV_CMD=""
DDK_ENV_HOME=""

export DDK_GLOBAL_ENV_TARGETS=""
export DDK_GLOBAL_ENV_HOME=""
export DDK_GLOBAL_ENV_DEBUG=""

ddk_help(){
  echo "  DDK setup helper"
  echo "  -------------------------------------------------------------"
  echo "  "
  echo "  Options:"
  echo "  --help :"
  echo "  --ddk-home :"
  echo "  --debug :"
  echo "  --without-debug :"
  echo "  --add-target :"
  echo "  "
}

ddk_add_target(){
    if [ "${1}" = "" ]; then
        return
    fi

    for tmp_target in $DDK_GLOBAL_ENV_TARGETS
    do
        if [ "$tmp_target" = "${1}" ]; then
            return
        fi
    done

    if [ "${DDK_GLOBAL_ENV_TARGETS}" = "" ]; then
        export DDK_GLOBAL_ENV_TARGETS="${1}"
    else
        export DDK_GLOBAL_ENV_TARGETS="${DDK_GLOBAL_ENV_TARGETS} ${1}"
    fi
}

ddk_ready_ddk_env_home(){
    if [ "${DDK_ENV_HOME}" = "" ]; then
        if [ "${DFRAMEWORK_DDK_HOME}" = "" ]; then
            ddk_exit 1 "ERROR: Not find DFRAMEWORK_DDK_HOME environment variable."
            return $?
        else
            DDK_ENV_HOME="${DFRAMEWORK_DDK_HOME}"
        fi
    fi
    if test ! -d "${DDK_ENV_HOME}"; then
        ddk_exit 1 "ERROR: [${DDK_ENV_HOME}] is not found."
        return $?
    fi
    if test ! -d "${DDK_ENV_HOME}/build"; then
        ddk_exit 1 "ERROR: [${DDK_ENV_HOME}/build] is not found."
        return $?
    fi
    if test ! -f "${DDK_ENV_HOME}/build/make.sh"; then
        ddk_exit 1 "ERROR: [${DDK_ENV_HOME}/build/make.sh] is not found."
        return $?
    fi
    export DDK_GLOBAL_ENV_HOME="${3}"
}

ddk_ready_arguments_2(){
    case "${2}" in
    --ddk-home)
        if [ "${3}" = "" ]; then
            ddk_exit 1 "ERROR: ${1}th argument: ${2} value is empty."
            return $?
        fi
        DDK_ENV_HOME="${3}"
    ;;
    --help)
      ddk_help
      return 1
    ;;
    --debug)
        export DDK_GLOBAL_ENV_DEBUG=1
    ;;
    --without-debug)
        export DDK_GLOBAL_ENV_DEBUG=""
    ;;
    --add-target)
        ddk_add_target "${3}"
    ;;
    *)
        ddk_exit 1 "ERROR: ${1}th argument: ${2}=${3}"
        return $?
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
    return $?
}

ddk_exit(){
    if [ "${2}" != "" ]; then
        echo "${2}"
        echo ""
    fi
    if [ $1 -ne 0 ]; then
        return $1
    fi
    return 0
}

main() {
  echo ""
  echo "  DDK GLOBAL ENVIRONMENTS SETUP"
  echo "  -------------------------------------------------------------"
  echo ""
  echo "  DFRAMEWORK_DDK_HOME    : ${DFRAMEWORK_DDK_HOME}"
  echo ""
  echo "  DDK_GLOBAL_ENV_HOME    : ${DDK_GLOBAL_ENV_HOME}"
  echo "  DDK_GLOBAL_ENV_DEBUG   : ${DDK_GLOBAL_ENV_DEBUG}"
  echo "  DDK_GLOBAL_ENV_TARGETS : ${DDK_GLOBAL_ENV_TARGETS}"
  echo ""
  echo "  alias ddk-build='${DDK_ENV_HOME}/build/make.sh'"
  echo ""
  echo "  -------------------------------------------------------------"
  echo ""
}

#####################################################################
#
#

DDC_PWD=`pwd`
xi=0
for x in $@
do
    xn=`expr "$x" : '\(^--[0-9a-zA-Z_-]\+\)[=]*[[:print:]]*'`
    xv=`expr "$x" : '^--[0-9a-zA-Z_-]\+[=]\{1\}\([[:print:]]\+\)'`
    if [ "${xn}" != "" ]; then
        ddk_ready_arguments_2 $xi "${xn}" "${xv}"
        if [ $? -ne 0 ]; then
            return
        fi
    else
        ddk_ready_arguments_1 $xi "${x}"
        if [ $? -ne 0 ]; then
            return
        fi
    fi
    xi=$(($xi+1))
done
  
ddk_ready_ddk_env_home
if [ $? -ne 0 ]; then
    return
fi
  
alias ddk-build='${DDK_ENV_HOME}/build/make.sh'

main

