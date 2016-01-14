#/bin/sh

ddk_cflags_include_chunked(){
    if [ "$1" = "" ]; then
        return
    fi

    tmp_a="${ddk_cflags_include_paths}"
    for tmp_x in $1
    do
      tmp_y=`expr "$tmp_x" : '[[:blank:]]*-I\([[:print:]]\+\)[[:blank:]]*'`
      if [ "$tmp_y" != "" ]; then
        tmp_a="${tmp_a} ${tmp_y}"
      fi
    done
    ddk_cflags_include_paths="${tmp_a}"
}

ddk_cflags_get_include_path(){
    tmp_ss=`expr "${1}" : '^[[:blank:]]*\([[:print:]]\+\)[[:blank:]]*$'`
    tmp_si=`expr "$tmp_ss" : '\(^[[:print:]]\)'`
    if [ "$tmp_si" = "/" ]; then
        echo "${tmp_ss}"
        return 1
    fi
 
    for tmp_x in $ddk_cflags_include_paths
    do
        if test -d "${tmp_x}/${tmp_ss}"; then
            echo "${tmp_x}/${tmp_ss}"
            return 1
        fi
    done

    if test -d "${DDK_ARG_DEST}/${tmp_ss}"; then
        echo "${DDK_ARG_DEST}/${tmp_ss}"
        return 1
    fi

    echo "${1}"
    return 0
}

ddk_cflags_add_includes(){
    for tmp_x in ${1}
    do
      if [ "$tmp_x" = "" ]; then
        continue
      fi
      tmp_p=$(ddk_cflags_get_include_path "${tmp_x}")
      if [ $? -eq 1 ]; then
        if [ "${tmp_p}" != "" ]; then
          DDC_CFLAGS="${DDC_CFLAGS} -I${tmp_p}"
          ddk_cflags_include_paths="${ddk_cflags_include_paths} ${tmp_p}"
        fi
      else
        ddk_exit 1 "error: Not add include ${tmp_x} : ${tmp_p}"
      fi
    done
}

ddk_cflags_init(){
    ddk_cflags_include_paths=""
    DDC_CFLAGS=""

    if [ $DDK_ENV_DEBUG -eq 1 ]; then
        DDC_CFLAGS="-g -O0 -DDEBUG"
    fi
    DDC_CFLAGS="${DDC_CFLAGS} ${LOCAL_CFLAGS}"
    DDC_CFLAGS="${DDC_CFLAGS} ${LOCAL_CPPFLAGS}"

    ddk_cflags_include_chunked "${DDC_CFLAGS}"
    ddk_cflags_add_includes "${DDK_ENV_INCLUDES}"
    ddk_cflags_add_includes "${DDK_ENV_HOME}"
    if [ "${DDK_ENV_HOME}" != "${DDC_PWD}" ]; then
        ddk_cflags_add_includes "${DDC_PWD}"
    fi
    if [ "${DDK_ENV_HOME}" != "${DDK_ARG_DEST}" ]; then
        if [ "${DDC_PWD}" != "${DDK_ARG_DEST}" ]; then
            ddk_cflags_add_includes "${DDK_ARG_DEST}"
        fi
    fi
    ddk_cflags_add_includes "${LOCAL_INCLUDES}"
}

ddk_ldflags_path_chunked(){
    if [ "$1" = "" ]; then
        return
    fi

    for tmp_x in $1
    do
      tmp_y=`expr "$tmp_x" : '[[:blank:]]*-L\([[:print:]]\+\)[[:blank:]]*'`
      if [ "$tmp_y" != "" ]; then
        ddk_ldflags_paths="${ddk_ldflags_paths} ${tmp_y}"
      fi
    done
}

ddk_ldflags_get_lib_path(){
    tmp_ss=`expr "${1}" : '^[[:blank:]]*\([[:print:]]\+\)[[:blank:]]*$'`
    tmp_si=`expr "$tmp_ss" : '\(^[[:print:]]\)'`
    if [ "$tmp_si" = "/" ]; then
        echo "${tmp_ss}"
        return 1
    fi
 
    for tmp_x in $ddk_ldflags_paths
    do
        if test -d "${tmp_x}/${tmp_ss}"; then
            echo "${tmp_x}/${tmp_ss}"
            return 1
        fi
    done

    echo "${1}"
    return 0
}

ddk_cflags_add_libs(){
    for tmp_x in ${1}
    do
      if [ "$tmp_x" = "" ]; then
        continue
      fi
      tmp_p=$(ddk_ldflags_get_lib_path "${tmp_x}")
      if [ $? -eq 1 ]; then
        if [ "${tmp_p}" != "" ]; then
          DDC_LDFLAGS="${DDC_LDFLAGS} -L${tmp_p}"
          ddk_ldflags_paths="${ddk_ldflags_paths} ${tmp_p}"
        fi
      else
        ddk_exit 1 "error: add-libs: ${tmp_x} : ${tmp_p}"
      fi
    done
}

ddk_ldflags_init(){
    ddk_ldflags_paths=""
    DDC_LDFLAGS=""
    DDC_LDFLAGS="${DDC_LDFLAGS} ${LOCAL_LDFLAGS}"

    ddk_ldflags_path_chunked "${LOCAL_LDFLAGS}"

    ddk_cflags_add_libs "${DDK_ENV_TARGET_BUILD}"
    ddk_cflags_add_libs "${DDK_ENV_LIBS}"
}

ddk_ldflags_static_libs(){
    tmp_find_libs=""
    tmp_find_short_libs=""
    tmp_nofind_libs=""

    for tmp_x in $LOCAL_STATIC_LIBRARIES
    do
        tmp_prefix=`expr "${tmp_x}" : '\(lib\)[[:print:]]*'`
        if [ "${tmp_prefix}" = "lib" ]; then
            tmp_nm=`expr "${tmp_x}" : 'lib\([[:print:]]\+\)'`
        else
            tmp_nm=$tmp_x
        fi

        if [ "$tmp_nm" = "" ]; then
            ddk_exit 1 "Unknown static libs: ${tmp_x}"
        fi
#echo "static libs : $ddk_ldflags_paths"
        tmp_islib=0
        for tmp_p in $ddk_ldflags_paths
        do
            tmp_libp="${tmp_p}/lib${tmp_nm}.${DDC_STATIC_LIB_EXT}"
            if test -f "$tmp_libp"; then
                tmp_islib=1
                break
            fi
        done

        if [ $tmp_islib -eq 1 ]; then
            tmp_find_libs="${tmp_find_libs} ${tmp_libp}"
            tmp_find_short_libs="${tmp_find_short_libs} -l${tmp_nm}"
        else
            tmp_nofind_libs="${tmp_nofind_libs} ${tmp_x}"
        fi
    done

    if [ "${tmp_nofind_libs}" != "" ]; then
        ddk_exit 1 "error: Not find static libs: ${tmp_nofind_libs}"
    fi

    tmp_static_libs="${tmp_find_libs}"
    tmp_static_short_libs="${tmp_find_short_libs}"
}

ddk_ldflags_shared_libs(){
    tmp_find_libs=""
    tmp_find_short_libs=""
    tmp_nofind_libs=""

    for tmp_x in $LOCAL_SHARED_LIBRARIES
    do
        tmp_prefix=`expr "${tmp_x}" : '\(lib\)[[:print:]]*'`
        if [ "${tmp_prefix}" = "lib" ]; then
            tmp_nm=`expr "${tmp_x}" : 'lib\([[:print:]]\+\)'`
        else
            tmp_nm=$tmp_x
        fi

        if [ "$tmp_nm" = "" ]; then
            ddk_exit 1 "Unknown shared libs: ${tmp_x}"
        fi

        tmp_islib=0
        for tmp_p in $ddk_ldflags_paths
        do
            tmp_libp="${tmp_p}/lib${tmp_nm}.${DDC_SHARED_LIB_EXT}"
            if test -f "$tmp_libp"; then
                tmp_islib=1
                break
            fi
        done

        if [ $tmp_islib -eq 1 ]; then
            tmp_find_libs="${tmp_find_libs} ${tmp_libp}"
            tmp_find_short_libs="${tmp_find_short_libs} -l${tmp_nm}"
        else
            tmp_nofind_libs="${tmp_nofind_libs} ${tmp_libp}"
        fi
    done

    if [ "${tmp_nofind_libs}" != "" ]; then
        ddk_exit 1 "error: Not find shared libs: ${tmp_nofind_libs}"
    fi

    tmp_shared_libs="${tmp_find_libs}"
}

