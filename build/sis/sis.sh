#!/bin/sh

SIS_SELF=""
SIS_SELF_NM=""
SIS_SELF_PATH=""
SIS_PWD=""
SIS_ENV_CMD=""
SIS_WORK_DIR=""
SIS_MAKE_WORKDIR=0
SIS_SAVE_ARCH=0
SIS_SAVE_WDIR=0
SIS_STDOUT=0

ddk_ready_arguments_2(){
    case "${2}" in
    --help)
        echo ""
        echo "Usage: $SIS_SELF_NM [OPTIONS...]"
        echo ""
        echo "Options:"
        echo "--help          :  Print this."
        echo "--sis-wdir      :  Working folder."
        echo "--save-archive  :  Save your tar.gz file."
        echo "--save-wdir     :  Save your working folder."
        echo "--stdout        :  Print stdout."
        echo ""
        exit 1
    ;;
    --sis-working-dir)
        SIS_WORK_DIR="${3}"
    ;;
    --save-archive)
        SIS_SAVE_ARCH=1
    ;;
    --save-wdir)
        SIS_SAVE_WDIR=1
    ;;
    --stdout)
        SIS_STDOUT=1
    ;;
    *)
        ddk_exit 1 "ERROR: ${1}th argument: ${2}=${3}"
    ;;
    esac
    return 0
}

ddk_ready_arguments_1(){
    if [ $1 -eq 0 ]; then
        SIS_ENV_CMD="${2}"
        SIS_ENV_CMD=`echo "${SIS_ENV_CMD}" | sed -e 's/-/_/g'`
        return 0
    fi

    ddk_exit 1 "ERROR: ${1}th argument: ${2}"
}

ddk_exit(){
    if [ $1 -ne 0 ]; then
        if [ "${2}" != "" ]; then
           echo "${2}"
           echo ""
        fi
        exit $1
    fi
}

ddk_sis_install(){
    tmp_args_path=$1
    tmp_args_nm=$2
    tmp_new_path="${tmp_args_path}/${tmp_args_nm}"

    if test ! -d ${tmp_new_path} ; then
        mkdir -p ${tmp_new_path}
        ddk_exit $? "error(2): mkdir -p ${tmp_new_path}"
    fi

    cd $tmp_args_nm
    tmp_test_pwd=`pwd`
    for tmp_nm in ./*
    do
        tmp_onm=`expr "$tmp_nm" : '^./\([[:print:]]\{1,\}\)'`
        if [ "$tmp_onm" = "" ]; then
            continue
        fi
        if test -f $tmp_onm ; then
            cp $tmp_onm ${tmp_new_path}/
            ddk_exit $? "error: cp $tmp_onm ${tmp_new_path}/ at $tmp_test_pwd"
        fi
        if test -d $tmp_onm ; then
            tmp_err=$(ddk_sis_install "${tmp_new_path}" "${tmp_onm}")
            if [ "$tmp_err" != "" ]; then
                ddk_exit 1 "error: $tmp_err"
            fi
        fi
    done
    cd ../
}

ddk_sis_start(){
    SIS_MAKE_WORKDIR=0
    tmp_arch=`awk '/^____DDK_ARCHIVE_FOLLOWS____/ { print NR + 1; exit 0; }' $SIS_SELF`
    if [ "$SIS_WORK_DIR" = "" ]; then
        ddk_exit 1 "error: --sis-working-dir is empty."
    fi
    if test ! -d $SIS_WORK_DIR; then
        mkdir -p $SIS_WORK_DIR
        ddk_exit $? "error: mkdir -p $SIS_WORK_DIR"
        SIS_MAKE_WORKDIR=1
    fi
    tmp_curpwd=`pwd`

    if [ $SIS_PWD_EQ -eq 0 ]; then
        cp $SIS_SELF $SIS_WORK_DIR
        ddk_exit $? "error: cp $SIS_SELF $SIS_WORK_DIR"
    fi
    cd $SIS_WORK_DIR

    if [ $SIS_STDOUT -eq 0 ]; then
        tmp_err=`tail -n +$tmp_arch $SIS_SELF | tar xvz`
        ddk_exit $? "error: tail -n +$tmp_arch $SIS_SELF | tar xvz"
    else
        tail -n +$tmp_arch $SIS_SELF | tar xvz
        ddk_exit $? "error: tail -n +$tmp_arch $SIS_SELF | tar xvz"
    fi

    if test ! -d $SIS_SELF_ORGNM ; then
        ddk_exit 1 "error $SIS_SELF_ORGNM is not directory."
    fi

    if test -f $SIS_SELF_ORGNM/DDKSIS/presis ; then
        tmp_bg=`$SIS_SELF_ORGNM/DDKSIS/presis`
        ddk_exit $? "error: $SIS_SELF_ORGNM/DDKSIS/presis: ${tmp_bg}"
    fi

    cd $SIS_SELF_ORGNM
    tmp_test_pwd=`pwd`
    for tmp_nm in ./*
    do
        tmp_onm=`expr "$tmp_nm" : '^./\([[:print:]]\{1,\}\)'`
        if [ "$tmp_onm" = "" ]; then
            continue
        fi
        if [ "$tmp_onm" = "DDKSIS" ]; then
            continue
        fi
        if [ "$tmp_onm" = "DEBIAN" ]; then
            continue
        fi
        if test -f $tmp_onm ; then
            cp $tmp_test_pwd/$tmp_onm /$tmp_onm
            ddk_exit $? "error: cp $tmp_test_pwd/$tmp_onm /$tmp_onm"
        fi
        if test -d $tmp_onm ; then
            ddk_sis_install "" "${tmp_onm}"
        fi
    done
    cd ../

    if test -f $SIS_SELF_ORGNM/DDKSIS/postsis ; then
        tmp_bg=`$SIS_SELF_ORGNM/DDKSIS/postsis "${tmp_bg}"`
        ddk_exit $? "error: $SIS_SELF_ORGNM/DDKSIS/postsis: ${tmp_bg}"
    fi

    cd $tmp_curpwd
    if [ $SIS_MAKE_WORKDIR -eq 1 ]; then
        if [ $SIS_SAVE_ARCH -eq 0 ]; then
            if [ $SIS_SAVE_WDIR -eq 0 ]; then
                if [ $SIS_PWD_EQ -eq 0 ]; then
                    rm -rf $SIS_WORK_DIR
                fi
            fi
        else
            if [ $SIS_SAVE_WDIR -eq 0 ]; then
                if [ $SIS_PWD_EQ -eq 0 ]; then
                    rm -rf $SIS_WORK_DIR/$SIS_SELF_NM
                fi
            fi
        fi
    else
        if [ $SIS_SAVE_ARCH -eq 0 ]; then
            rm -rf $SIS_WORK_DIR/$SIS_SELF_ORGNM
        fi
        if [ $SIS_SAVE_WDIR -eq 0 ]; then
            if [ $SIS_PWD_EQ -eq 0 ]; then
                rm -rf $SIS_WORK_DIR/$SIS_SELF_NM
            fi
        fi
    fi
}


SIS_SELF=$0
SIS_PWD=`pwd`
SIS_PWD_EQ=0
SIS_WORK_DIR=$SIS_PWD
tmp_test=`expr "$SIS_SELF" : '\(^.\)[[:print:]]\{1,\}$'`
if [ "$tmp_test" = "." ]; then
    SIS_SELF="$SIS_PWD/$SIS_SELF"
fi
SIS_SELF_NM=`expr "$SIS_SELF" : '^[[:print:]]\{1,\}/\([[:print:]]\{1,\}$\)'`
SIS_SELF_PATH=`expr "$SIS_SELF" : '\(^[[:print:]]\{1,\}\)/[[:print:]]\{1,\}$'`
SIS_SELF_ORGNM=`expr "$SIS_SELF_NM" : '\(^[[:print:]]\{1,\}\)\.sh$'`

cd $SIS_SELF_PATH
tmp_test_pwd=`pwd`
if [ "$tmp_test_pwd" = "$SIS_PWD" ]; then
    SIS_PWD_EQ=1
fi
cd $SIS_PWD

xi=0
for x in "$@"
do
    xn=`expr "$x" : '\(^--[0-9a-zA-Z_-]\{1,\}\)[=]*[[:print:]]*'`
    xv=`expr "$x" : '^--[0-9a-zA-Z_-]\{1,\}[=]\{1\}\([[:print:]]\{1,\}\)'`
    if [ "${xn}" != "" ]; then
        ddk_ready_arguments_2 $xi "${xn}" "${xv}"
        ddk_exit $?
    else
        ddk_ready_arguments_1 $xi "${x}"
        ddk_exit $?
    fi
    xi=$(($xi+1))
done

ddk_sis_start

echo "    * DDK self install script complete ... OK"
exit 0

____DDK_ARCHIVE_FOLLOWS____
