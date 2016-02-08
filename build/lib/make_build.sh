#!/bin/sh

tmp_ck_method=
tmp_ck_local_srcs=
tmp_ck_local_objs=
tmp_time_max=
tmp_time_max_nm=
tmp_rm_dirs=

CLEAR_VARS(){
    TEST_A=called
}


build_get_static_archives(){
    # $(build_get_static_archives "")
    # $1 : $tmp_static_short_libs
    local archives=""
    if [ "$1" != "" ]; then
        case $DDK_ENV_TARGET_OS in
        darwin|ios) archives="-Wl,-all_load $1" ;;
        *) archives="-Wl,--whole-archive $1 -Wl,--no-whole-archive" ;;
        esac
    fi
    echo "${archives}"
}

build_addlib_static_libs(){
    tmp_c=0
    if [ "${2}" = "" ]; then
        tmp_buf="create ${1}\n"
    else
        tmp_c=$(($tmp_c+1))
        tmp_buf="create ${1}\naddlib ${2}\n"
    fi

    for tmp_l in $3
    do
        tmp_c=$(($tmp_c+1))
        tmp_buf="${tmp_buf}addlib ${tmp_l}\n"
    done

    if [ $tmp_c -ne 0 ]; then
        tmp_buf="${tmp_buf}save\nend"
    else
        tmp_buf=""
    fi

    tmp_addlibs=$tmp_buf
}

build_make_static_archives(){
    local current=""
    current=`pwd`
    if [ "$tmp_static_libs" = "" ]; then
        return 0
    fi

    cd $DDK_ENV_TARGET_BUILD
    ddk_exit $? "error: cd $DDK_ENV_TARGET_BUILD"

    local use_libtool=0
    local res=""
    if test -f $DDC_LIBTOOL ; then
        case $DDK_ENV_TARGET_OS in
        darwin|ios) use_libtool=1 ;;
        esac
    fi

    if [ $use_libtool -eq 1 ] ; then
        if [ -f $tmp_ck_last_obj ]; then
            libtool -static ${tmp_ck_last_obj} ${tmp_static_libs} -o ${tmp_ck_origin_obj} > /dev/null
            res=$?
            rm -f $tmp_ck_last_obj
        else
            libtool -static ${tmp_static_libs} -o ${tmp_ck_origin_obj} > /dev/null
            res=$?
        fi
        ddk_exit $res "error: libtool -static ${tmp_ck_last_obj} ${tmp_static_libs} -o ${tmp_ck_origin_obj}"
    else
        if [ -f $tmp_ck_last_obj ]; then
            build_addlib_static_libs "${tmp_ck_origin_obj}" "${tmp_ck_last_obj}" "${tmp_static_libs}"
        else
            build_addlib_static_libs "${tmp_ck_origin_obj}" "" "${tmp_static_libs}"
        fi
        #echo $tmp_addlibs
        #echo "build_addlib_static_libs \"${tmp_ck_origin_obj}\" \"${tmp_ck_last_obj}\" \"${tmp_static_libs}\""
        if [ "$tmp_addlibs" != "" ]; then
            local tmp_ddc_ar=""
            tmp_ddc_ar="${DDC_AR} -M"
            `echo "${tmp_addlibs}" | ${tmp_ddc_ar}`
            res=$?
            if test -f tmp_ck_last_obj ; then
                rm $tmp_ck_last_obj
            fi
            ddk_exit $res "error: echo -e ${tmp_addlibs} | ${tmp_ddc_ar}"
        else
            rm $tmp_ck_last_obj
            ddk_exit $? "error: rm $tmp_ck_last_obj in $DDK_ENV_TARGET_BUILD"
        fi
    fi        

    tmp_ck_last_obj=$tmp_ck_origin_obj
    cd $current
    return 0
}

BUILD_STATIC_LIBRARY(){
    if [ "${DDK_ENV_CMD}" != "" ]; then
        return 0
    fi

    tmp_ck_method="static"
    ddk_build_version
    ddk_build_objects

    if [ "$tmp_static_libs" = "" ]; then
        tmp_ck_last_obj="${LOCAL_MODULE}.${DDC_STATIC_LIB_EXT}"
        tmp_ck_last_cmd="${DDC_AR} rcs ${tmp_ck_last_obj} ${tmp_objs}"
    else
        tmp_ck_origin_obj="${LOCAL_MODULE}.${DDC_STATIC_LIB_EXT}"
        tmp_ck_last_date=`date +%Y%m%d%H%I%S`
        tmp_ck_last_obj="${LOCAL_MODULE}-${tmp_ck_last_date}.${DDC_STATIC_LIB_EXT}"
        tmp_ck_last_cmd="${DDC_AR} rcs ${tmp_ck_last_obj} ${tmp_objs}"
    fi

    local use_build=0
    if [ "${tmp_objs}" != "" ]; then
      use_build=1
      ddk_build_last_object
    fi

    build_make_static_archives

    local current=""
    current=`pwd`
    cd $DDK_ENV_TARGET_BUILD
    ddk_exit $? "error: cd $DDK_ENV_TARGET_BUILD"

    $DDC_RANLIB "${tmp_ck_last_obj}"
    res=$?
    cd $current
    if [ $res -ne 0 ]; then
       ddk_exit 1 "    \033[31mERROR: $DDC_RANLIB ${tmp_ck_last_obj}\033[0m"
    fi

    if [ $use_build -ne 1 ]; then
        echo "    \`-- \033[32mMake ${tmp_ck_last_obj} ... OK\033[0m"
    fi
    echo ""
}

BUILD_SHARED_LIBRARY(){
    if [ "${DDK_ENV_CMD}" != "" ]; then
        return 0
    fi

    tmp_ck_method="shared"
    ddk_build_version
    ddk_build_objects

    tmp_noversion=0
    if [ ${DDK_ENV_TARGET_OS} = "windows" ]; then
        tmp_noversion=1
    else
      if [ "${LOCAL_NO_VERSION}" != "" ]; then
        tmp_noversion=1
      fi
    fi

    if [ $tmp_noversion -ne 0 ]; then
        tmp_mname="${LOCAL_MODULE}.${DDC_SHARED_LIB_EXT}"
        tmp_soname="${tmp_mname}"
        tmp_objname="${tmp_soname}"
    else 
        if [ "${DDK_ENV_TARGET_OS}" = "darwin" ]; then
            tmp_mname="${LOCAL_MODULE}.${DDC_SHARED_LIB_EXT}"
            tmp_soname="${LOCAL_MODULE}.${GLOBAL_MAJOR_VERSION}.${DDC_SHARED_LIB_EXT}"
            tmp_objname="${LOCAL_MODULE}.${GLOBAL_MAJOR_VERSION}.${GLOBAL_MINOR_VERSION}.${GLOBAL_PATCH_VERSION}.${DDC_SHARED_LIB_EXT}"
        else
            tmp_mname="${LOCAL_MODULE}.${DDC_SHARED_LIB_EXT}"
            tmp_soname="${tmp_mname}.${GLOBAL_MAJOR_VERSION}"
            tmp_objname="${tmp_soname}.${GLOBAL_MINOR_VERSION}.${GLOBAL_PATCH_VERSION}"
        fi
    fi

    local archives=""
    archives=$(build_get_static_archives "${tmp_static_short_libs}")
    tmp_ck_last_obj="${tmp_objname}"
    if [ $tmp_noversion -ne 0 ]; then
        tmp_ck_last_cmd="${DDC_CXX} ${tmp_last_cflags} -shared -o ${tmp_ck_last_obj} ${tmp_objs} ${DDC_LDFLAGS} ${DDK_CROSS_LDFLAGS} ${tmp_shared_libs} ${archives}"
    else
        if [ ${DDK_ENV_TARGET_OS} = "darwin" ]; then
            tmp_ck_last_cmd="${DDC_CXX} ${tmp_last_cflags} -dynamiclib -o ${tmp_ck_last_obj} ${tmp_objs} ${DDC_LDFLAGS} ${DDK_CROSS_LDFLAGS} ${tmp_shared_libs} ${archives}"
        else
            tmp_ck_last_cmd="${DDC_CXX} ${tmp_last_cflags} -shared -Wl,-soname,${tmp_soname} -o ${tmp_ck_last_obj} ${tmp_objs} ${DDC_LDFLAGS} ${DDK_CROSS_LDFLAGS} ${tmp_shared_libs} ${archives}"
        fi
    fi

    ddk_build_last_object

    if [ $tmp_noversion -eq 0 ]; then
      if [ $tmp_can_last_make -ne 0 ]; then
        tmp_current=`pwd`
        cd $DDK_ENV_TARGET_BUILD
            if test -f "${tmp_mname}"; then
                rm "$tmp_mname"
            fi
            if test -f "$tmp_soname"; then
                rm "$tmp_soname"
            fi
            ln -s "${tmp_objname}" "${tmp_soname}"
            ln -s "${tmp_soname}" "${tmp_mname}"
        cd $tmp_current
      fi
    fi

    echo ""
}

BUILD_EXCUTABLE(){
    if [ "${DDK_ENV_CMD}" != "" ]; then
        return 0
    fi

    tmp_ck_method="executable"
    ddk_build_version
    ddk_build_objects

    if [ "${DDC_EXCUTE_EXT}" = "" ]; then
        tmp_ck_last_obj="${LOCAL_MODULE}"
    else
        tmp_ck_last_obj="${LOCAL_MODULE}.${DDC_EXCUTE_EXT}"
    fi

    if [ "${tmp_objs}" != "" ]; then
        local archives=""
        archives=$(build_get_static_archives "${tmp_static_short_libs}")
        tmp_ck_last_cmd="${DDC_CXX} ${DDC_LDFLAGS} ${DDK_CROSS_LDFLAGS} -o ${tmp_ck_last_obj} ${tmp_objs}  ${DDC_LDFLAGS} ${tmp_shared_libs} ${archives}"
        ddk_build_last_object
    fi

    echo ""
}

ddk_build_version(){
    if [ "${LOCAL_VERSION}" = "" ]; then
        LOCAL_VERSION="0.0.1"
    fi
    val="$LOCAL_VERSION"
    GLOBAL_MAJOR_VERSION=`expr "$val" : '\(^[0-9]\{1,\}\)\.[[:print:]]\{1,\}'`
    GLOBAL_MINOR_VERSION=`expr "$val" : '^[0-9]\{1,\}\.\([0-9]\{1,\}\)\.[[:print:]]\{1,\}'`
    GLOBAL_PATCH_VERSION=`expr "$val" : '^[0-9]\{1,\}\.[0-9]\{1,\}\.\([[:print:]]\{1,\}\)'`
    if [ "${GLOBAL_MAJOR_VERSION}" = "" ]; then
        GLOBAL_MAJOR_VERSION=0
    fi
    if [ "${GLOBAL_MINOR_VERSION}" = "" ]; then
        GLOBAL_MINOR_VERSION=0
    fi
    if [ "${GLOBAL_PATCH_VERSION}" = "" ]; then
        GLOBAL_PATCH_VERSION=0
    fi
}

ddk_build_check_headers(){
    if [ $tmp_is_compile -eq 1 ]; then
        ddk_plo_save
    else
        ddk_plo_load
        if [ $? -ne 0 ]; then
            tmp_is_compile=1
            ddk_plo_save
        fi
    fi
}

# $(ddk_build_get_tool "extend")
ddk_build_get_tool(){
    case "${1}" in
    c)
       echo $DDC_CC
    ;;
    cpp)
       echo $DDC_CXX
    ;;
    *)
       echo $DDC_CXX
    ;;
    esac
}

ddk_build_get_toolname(){
    case "${1}" in
    c)
       echo $DDK_CC
    ;;
    cpp)
       echo $DDK_CXX
    ;;
    *)
       echo $DDK_CXX
    ;;
    esac
}

ddk_build_src(){
    tmp_src_input="${1}"
    tmp_src="${DDK_ARG_DEST}/${tmp_src_input}"
    if test ! -f "$tmp_src"; then
        ddk_exit 1 "Not find ${tmp_src}"
    fi

    tmp_src_count=$(($tmp_src_count+1))

    tmp_ext=`expr "${tmp_src_input}" : '[[:print:]]\{1,\}\.\([a-zA-Z0-9_-]\{1,\}\)$'`
    tmp_pnm=`expr "${tmp_src_input}" : '\([[:print:]]\{1,\}\)\.[a-zA-Z0-9_-]*$'`
    tmp_tnm=`echo "${tmp_pnm}" | sed -e 's/[\/]/+s+/g'`
    tmp_tnm=`echo "${tmp_tnm}" | sed -e 's/[\.]/+d+/g'`

    tmp_obj_folder="${DDK_ENV_TARGET_WORKING}${DDK_ARG_DEST}"
    tmp_obj_test="${tmp_ck_method}-${LOCAL_MODULE}-${tmp_tnm}"
    tmp_obj_nm="${tmp_obj_test}.o"
    tmp_plo_nm="${tmp_obj_test}.Plo"

    tmp_obj="${tmp_obj_folder}/${tmp_obj_nm}"
    tmp_plo="${tmp_obj_folder}/${tmp_plo_nm}"
    tmp_plo_test="${tmp_obj_folder}/${tmp_obj_test}.headers.Plo"

    tmp_is_compile=0
    tmp_time_src=$(ddk_call_mtime "$tmp_src")
    tmp_time_obj=$(ddk_call_mtime "$tmp_obj")
    if [ $tmp_time_src -gt $tmp_time_max ]; then
        tmp_time_max=$tmp_time_src
        tmp_time_max_nm=$tmp_src
    fi
    if [ $tmp_time_src -ne $tmp_time_obj ]; then
        tmp_is_compile=1
    fi

    ddk_build_check_headers
    if [ $tmp_is_compile -eq 0 ]; then
        return
    fi

    # -----------------------------------------------------
    tmp_toolname=$(ddk_build_get_toolname "${tmp_ext}")
    echo "    ${tmp_toolname}: [${DDK_ENV_TARGET_NM}] ${LOCAL_MODULE} <= ${tmp_src_input}"

    tmp_tool=$(ddk_build_get_tool "${tmp_ext}")
    #tmp_cflags=$(ddk_build_get_cflags)
    tmp_cflags="${DDK_CROSS_CFLAGS} ${DDK_CROSS_CPPFLAGS}"
    tmp_cflags="${tmp_cflags} ${DDC_CFLAGS}"
    tmp_cflags="${tmp_cflags} -DGLOBAL_MAJOR_VERSION=${GLOBAL_MAJOR_VERSION}"
    tmp_cflags="${tmp_cflags} -DGLOBAL_MINOR_VERSION=${GLOBAL_MINOR_VERSION}"
    tmp_cflags="${tmp_cflags} -DGLOBAL_PATCH_VERSION=${GLOBAL_PATCH_VERSION}"

    ${tmp_tool} -o ${tmp_obj} -c ${tmp_src} ${tmp_cflags}
    #    echo  "    ${tmp_tool} -o ${tmp_obj} -c ${tmp_src} ${tmp_cflags}"

    if [ $? -ne 0 ]; then
        ddk_exit 1 "    error: ${tmp_tool} -o ${tmp_obj} -c ${tmp_src} ${tmp_cflags}"
    fi

    touch -r ${tmp_src} ${tmp_obj}
    if [ $? -ne 0 ]; then
        ddk_exit 1 "    error: touch -r ${tmp_src} ${tmp_obj}"
    fi

    tmp_build_count=$(($tmp_build_count+1))
}


ddk_build_objects(){
    tmp_ck_local_srcs=""
    tmp_ck_local_objs=""
    tmp_build_count=0
    tmp_src_count=0
    tmp_time_max=0
    tmp_time_max_nm=""
    tmp_objs=""

    if [ "${tmp_ck_method}" = "excutable" ]; then
        echo "  @ Build ${tmp_ck_method} ${DDK_ARG_DEST}"
    else
        echo "  @ Build ${tmp_ck_method} library ${DDK_ARG_DEST}"
    fi

    if [ "${LOCAL_MODULE}" = "" ]; then
        return 0
    fi

    ddk_cflags_init
    ddk_ldflags_init
    ddk_ldflags_static_libs
    ddk_ldflags_shared_libs

    tmp_ck_local_srcs=$(echo "${LOCAL_SRC_FILES}" | tr " " "\n")
    for src_x in $tmp_ck_local_srcs
    do
        ddk_build_src "${src_x}"
        tmp_objs="${tmp_objs} ${tmp_obj_nm}"
    done

    for tmp_x in $tmp_static_libs
    do
        tmp_time_x=$(ddk_call_mtime "$tmp_x")
        if [ $tmp_time_max -lt $tmp_time_x ]; then
            tmp_time_max=$tmp_time_x
            tmp_time_max_nm=$tmp_x
        fi
    done
}

ddk_build_last_object(){
    tmp_can_last_make=1
    tmp_last_obj="${DDK_ENV_TARGET_BUILD}/${tmp_ck_last_obj}"

    if [ $tmp_build_count -eq 0 ]; then
        tmp_time_last=$(ddk_call_mtime "${tmp_last_obj}")
        if [ $tmp_time_last -ne 0 ]; then
            if [ $tmp_time_max -eq $tmp_time_last ]; then
                tmp_can_last_make=0
            fi
        fi
    fi

    if [ $tmp_can_last_make -eq 0 ]; then
        echo "    \033[33m\`-- Nothing make ${tmp_ck_last_obj} ... OK\033[0m"
        return
    fi

    if test -f "${tmp_last_obj}"; then
        rm "${tmp_last_obj}"
    fi

    tmp_current=`pwd`
    cd "${DDK_ENV_TARGET_WORKING}/${DDK_ARG_DEST}"
    $tmp_ck_last_cmd
    tmp_res=$?
    if [ $tmp_res -eq 0 ]; then
        cp "${tmp_ck_last_obj}" "${DDK_ENV_TARGET_BUILD}/"
        if [ $? -ne 0 ]; then
            ddk_exit 1 "error: cp \"${tmp_ck_last_obj}\" \"${DDK_ENV_TARGET_BUILD}/\""
        fi
    fi
    cd $tmp_current

    if [ $tmp_res -ne 0 ]; then
        ddk_exit 1 "    \033[33m\`-- error: ${tmp_ck_last_cmd}\033[0m"
    fi

    if [ "${tmp_time_max_nm}" != "" ]; then
        touch -r ${tmp_time_max_nm} ${tmp_last_obj}
        if [ $? -ne 0 ]; then
            ddk_exit 1 "    \`-- \033[32merror: touch -r ${tmp_time_max_nm} ${tmp_last_obj}\033[0m"
        fi
    fi

    tmp_test="(${tmp_build_count}/${tmp_src_count})"
    echo "    \`-- \033[32mMake ${tmp_ck_last_obj} ${tmp_test} ... OK\033[0m"
}


