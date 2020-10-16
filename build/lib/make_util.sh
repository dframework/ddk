#!/bin/sh

ddk_call_mtime(){
    if test ! -f $1; then
      echo "0"
      return;
    fi

    tmp_os=`uname -s 2>/dev/null`
    case "${tmp_os}" in
        Linux)
            mtime=`/usr/bin/stat -c '%Y' ${1} 2>/dev/null`
            ;;
        FreeBSD)
            mtime=`/usr/bin/stat -f '%m' ${1} 2>/dev/null`
            ;;
        Darwin)
            mtime=`/usr/bin/stat -f '%m' ${1} 2>/dev/null`
            ;;
        *)
            mtime=`/usr/bin/stat -c '%Y' ${1} 2>/dev/null`
            #echo "0"
            #return
            ;;
    esac

    echo ${mtime:-0}
}

ddk_has_subdir(){
    for tmp_x in $tmp_thiz_subdirs
    do
        if [ "$tmp_x" = "" ]; then
            continue
        fi
        if [ "$tmp_x" = "$1" ]; then
            return 1
        fi
    done
    return 0 
}

ddk_has_no_subdir(){
    for tmp_x in $tmp_thiz_no_subdirs
    do
        if [ "$tmp_x" = "" ]; then
            continue
        fi
        if [ "$tmp_x" = "$1" ]; then
            return 1
        fi
    done
    return 0 
}

ddk_load_subdirs(){
    tmp_folder=${1}
    for tmp_x in $tmp_thiz_subdirs
    do
        if [ "$tmp_x" != "" ]; then
            tmp_y="${tmp_folder}/${tmp_x}"
            if test -d "$tmp_y"; then
                ddk_call_private_dir "${tmp_y}"
            else
                echo "${tmp_y} is not directory."
                return 1
            fi
        fi
    done
    return 0
}

ddk_load_dir(){
    sub_dirs=""
    tmp_folder=${1}
    tmp_pwd=`pwd`

    cd ${tmp_folder}
    if [ $? -ne 0 ]; then
        ddk_exit 1 "cd ${tmp_folder}"
    fi

    for entry in ./*
    do
      if test -d "$entry"; then
        entry_name=`expr "$entry" : '^./\([[:print:]]\{1,\}\)'`
        if [ "$entry_name" = "" ]; then
            entry_name=$entry
        fi

        ddk_has_subdir "$entry_name"
        if [ $? -eq 1 ]; then
           continue
        fi
        ddk_has_no_subdir "$entry_name"
        if [ $? -eq 1 ]; then
           continue
        fi

        if [ "${sub_dirs}" = "" ]; then
            sub_dirs="${entry_name}"
        else
            sub_dirs="${sub_dirs} ${entry_name}"
        fi
      fi
    done

    cd ${tmp_pwd}
    if [ $? -ne 0 ]; then
        ddk_exit 1 "cd ${tmp_pwd}"
    fi

    sub_a_dirs=$(echo "${sub_dirs}" | tr " " "\n")
    for subdir in $sub_a_dirs
    do
      if [ "${subdir}" = "" ]; then
          continue
      fi
      sub_fname="${tmp_folder}/${subdir}"
      if test -d "${sub_fname}"; then
          ddk_call_private_dir "${sub_fname}"
      fi
    done
}

ddk_load_dest(){
    tmp_load_dest_hasmk=0
    ddk_compile_mk "${1}" "Dframework.mk"

    if [ $? -eq 0 ]; then
        tmp_load_dest_hasmk=1
    fi

    tmp_thiz_subdirs=$(echo $DDK_SET_SUBDIRS | tr " " "\n")
    tmp_thiz_no_subdirs=$(echo $DDK_SET_NO_SUBDIRS | tr " " "\n")

    ddk_load_subdirs "${1}"
    if [ $? -ne 0 ]; then
        ddk_exit 1 "error: in ${1}/Dframework.mk"
    fi
    ddk_load_dir "${1}"

    if [ $tmp_load_dest_hasmk -eq 1 ]; then
        ddk_load_mk "${1}" "Dframework.mk"
    fi
 
    mkres=$?
}

ddk_call_make(){
    args=""

    if [ "${DDK_ENV_CMD}" != "" ]; then
        args="${DDK_ENV_CMD}"
    fi
    
    if [ "${1}" != "" ]; then
        args="${args} ${1}"
    fi

    args="${args} --ddk-home=${DDK_ENV_HOME}"
    args="${args} --arg-cmd=${2}"
    args="${args} --arg-dest=${3}"

    if [ "${DDK_ENV_CALL_TARGET}" != "" ]; then
        args="${args} --call-target=${DDK_ENV_CALL_TARGET}"
    fi
    if [ "${DDK_ENV_TARGET_OS}" != "" ]; then
        args="${args} --target-os=${DDK_ENV_TARGET_OS}"
    fi
    if [ "${DDK_ENV_TARGET_CPU}" != "" ]; then
        args="${args} --target-cpu=${DDK_ENV_TARGET_CPU}"
    fi
    if [ "${DDK_CROSS_PREFIX}" != "" ]; then
        args="${args} --cross-prefix=${DDK_CROSS_PREFIX}"
    fi
    if [ "${DDK_CROSS_HOME}" != "" ]; then
        args="${args} --cross-home=${DDK_CROSS_HOME}"
    fi
    if [ $DDK_ENV_DEBUG -eq 1 ]; then
        args="${args} --debug"
    fi
    if [ "${4}" != "1" ]; then
        args="${args} --no-print"
    fi

    ${DDK_ENV_HOME}/build/make.sh ${args}
    ddk_exit $?
}

ddk_call_private_dir(){
    if [ "${1}" = "" ]; then
        ddk_exit 1 "DDK_ARG_DEST is empty."
    fi

    if test ! -d "${1}"; then
        ddk_exit 1 "${1} is not directory."
    fi

    ddk_call_make "" "load-dest" "${1}"
}

ddk_working(){
    if [ "${DDK_ARG_CMD}" = "" ]; then
        ddk_call_private_dir "${DDC_PWD}"
        return $?
    fi

    case "${DDK_ARG_CMD}" in
    load-dest)
        ddk_load_dest "${DDK_ARG_DEST}"
    ;;
    *)
        ddk_exit 1 "Unknown DDK_ARG_CMD."
    ;;
    esac

    return 0
}

ddk_sh_check_ddk_build()
{
    if [ "$DDK_ENV_HOME" = "" ]; then
        ddk_exit 1 "Unknwon DDK_ENV_HOME."
    fi

    local ddk_shell="$DDK_ENV_HOME/build/make.sh"
    if test ! -f $ddk_shell ; then
        ddk_exit 1 "Not found ddk-build excutable shell script : $ddk_shell"
    fi
}

ddk_android_working(){
    ddk_sh_check_ddk_build

    local D_TARGETS=""
    local iserror=0
    local list=
    local val=
    local target=
    local testtargets=`$DDK_ENV_HOME/build/make.sh --print-targets`
    for target in $testtargets
    do
       val=`expr "${target}" : '^android-\([[:print:]]\{1,\}\)'`
       if [ "$val" != "" ]; then
           case "${val}" in
           armv7) D_TARGETS="${D_TARGETS} ${val}" ;;
           arm64) D_TARGETS="${D_TARGETS} ${val}" ;;
           x86) D_TARGETS="${D_TARGETS} ${val}" ;;
           x86_64) D_TARGETS="${D_TARGETS} ${val}" ;;
           *)
               iserror=1
               echo "Uknown target ${val}"
           ;;
           esac
       fi
    done

    if [ $iserror -eq 1 ]; then
        exit 1
    fi

    local addtarget=""
    for target in $D_TARGETS
    do
        if [ "$addtarget" = "" ]; then
            addtarget="--add-target=android-$target"
        else
            addtarget="${addtarget} --add-target=android-$target"
        fi
    done

    if [ $DDK_ENV_DEBUG -eq 0 ]; then
        $DDK_ENV_HOME/build/make.sh $addtarget
    else
        $DDK_ENV_HOME/build/make.sh --debug $addtarget
    fi
}

ddk_ios_working(){
    ddk_sh_check_ddk_build

    local D_TARGETS=""
    local iserror=0
    local list=
    local val=
    local target=
    local testtargets=`$DDK_ENV_HOME/build/make.sh --print-targets`
    for target in $testtargets
    do
       val=`expr "${target}" : '^ios-\([[:print:]]\{1,\}\)'`
       if [ "$val" != "" ]; then
           case "${val}" in
           armv7) D_TARGETS="${D_TARGETS} ${val}" ;;
           armv7s) D_TARGETS="${D_TARGETS} ${val}" ;;
           arm64) D_TARGETS="${D_TARGETS} ${val}" ;;
           i386) D_TARGETS="${D_TARGETS} ${val}" ;;
           x86_64) D_TARGETS="${D_TARGETS} ${val}" ;;
           *)
               iserror=1
               echo "Uknown target ${val}"
           ;;
           esac
       fi
    done

    if [ $iserror -eq 1 ]; then
        exit 1
    fi

    local addtarget=""
    for target in $D_TARGETS
    do
        if [ "$addtarget" = "" ]; then
            addtarget="--add-target=ios-$target"
        else
            addtarget="${addtarget} --add-target=ios-$target"
        fi
    done

    if [ $DDK_ENV_DEBUG -eq 0 ]; then
        $DDK_ENV_HOME/build/make.sh $addtarget
    else
        $DDK_ENV_HOME/build/make.sh --debug $addtarget
    fi
}

