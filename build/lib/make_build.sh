#!/bin/sh

tmp_ck_method=
tmp_ck_local_srcs=
tmp_ck_local_objs=
tmp_time_max=
tmp_time_max_nm=

CLEAR_VARS(){
    TEST_A=called
}

BUILD_STATIC_LIBRARY(){
    if [ "${DDK_ENV_CMD}" != "" ]; then
        return 0
    fi

    tmp_ck_method="static"
    ddk_build_version
    ddk_build_objects

    tmp_ck_last_obj="${LOCAL_MODULE}.${DDC_STATIC_LIB_EXT}"
    tmp_ck_last_cmd="${DDC_AR} ${tmp_ck_last_obj} ${tmp_objs} ${tmp_static_libs}"
    ddk_build_last_object

    if [ $tmp_can_last_make -eq 0 ]; then
        tmp_current=`pwd`
        cd $DDK_ENV_TARGET_BUILD
        $DDC_RANLIB "${tmp_ck_last_obj}"
        res=$?
        cd $tmp_current
        if [ $res -ne 0 ]; then
           ddk_exit 1 "    \033[31mERROR: $DDC_RANLIB ${tmp_ck_last_obj}\033[0m"
        fi
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
        tmp_mname="${LOCAL_MODULE}.${DDC_SHARED_LIB_EXT}"
        tmp_soname="${tmp_mname}.${GLOBAL_MAJOR_VERSION}"
        tmp_objname="${tmp_soname}.${GLOBAL_MINOR_VERSION}.${GLOBAL_PATCH_VERSION}"
    fi

    tmp_static_archives=""
    if [ "${tmp_static_short_libs}" != "" ]; then
        tmp_static_archives="-Wl,--whole-archive ${tmp_static_short_libs} -Wl,--no-whole-archive"
    fi

    tmp_last_cflags="-fPIC"
    tmp_ck_last_obj="${tmp_objname}"
    if [ $tmp_noversion -ne 0 ]; then
        tmp_ck_last_cmd="${DDC_CPP} ${tmp_last_cflags} -shared -o ${tmp_ck_last_obj} ${tmp_objs} ${DDC_LDFLAGS} ${tmp_shared_libs} ${tmp_static_archives}"
    else
        tmp_ck_last_cmd="${DDC_CPP} ${tmp_last_cflags} -shared -Wl,-soname,${tmp_soname} -o ${tmp_ck_last_obj} ${tmp_objs} ${DDC_LDFLAGS} ${tmp_shared_libs} ${tmp_static_archives}"
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
            ln -s "${tmp_soname}" "$tmp_mname"
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
        tmp_static_archives=""
        if [ "${tmp_static_short_libs}" != "" ]; then
            tmp_static_archives="-Wl,--whole-archive ${tmp_static_short_libs} -Wl,--no-whole-archive"
        fi
        tmp_ck_last_cmd="${DDC_CPP} -o ${tmp_ck_last_obj} ${tmp_objs} ${tmp_shared_libs} ${tmp_static_archives} ${DDC_LDFLAGS}"
        ddk_build_last_object
    fi
    echo ""
}

ddk_build_version(){
    if [ "${LOCAL_VERSION}" = "" ]; then
        LOCAL_VERSION="0.0.1"
    fi
    val="$LOCAL_VERSION"
    GLOBAL_MAJOR_VERSION=`expr "$val" : '\(^[0-9]\+\)\.[[:print:]]\+'`
    GLOBAL_MINOR_VERSION=`expr "$val" : '^[0-9]\+\.\([0-9]\+\)\.[[:print:]]\+'`
    GLOBAL_PATCH_VERSION=`expr "$val" : '^[0-9]\+\.[0-9]\+\.\([[:print:]]\+\)'`
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
       echo $DDC_CPP
    ;;
    *)
       echo $DDC_CPP
    ;;
    esac
}

ddk_build_get_toolname(){
    case "${1}" in
    c)
       echo $DDK_CC
    ;;
    cpp)
       echo $DDK_CPP
    ;;
    *)
       echo $DDK_CPP
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

    tmp_ext=`expr "${tmp_src_input}" : '[[:print:]]\+\.\([a-zA-Z0-9_-]\+\)$'`
    tmp_pnm=`expr "${tmp_src_input}" : '\([[:print:]]\+\)\.[a-zA-Z0-9_-]*$'`
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
    tmp_cflags=$DDC_CFLAGS

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


