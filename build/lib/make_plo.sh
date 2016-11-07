#!/bin/sh

tmp_plo_max_time_includes=0

ddk_plo_has_include(){
    for tmp_inc in $tmp_headers
    do
        if [ "${tmp_inc}" = "${1}" ]; then
            return 1
        fi
    done
    return 0
}

ddk_plo_add_include(){
    tmp_headers="${tmp_headers} ${1}"
}

ddk_plo_col_includes(){
    `cat "${1}" | egrep "^#[[:blank:]]*include" > ${tmp_plo_test}`
    if [ $? -ne 0 ]; then
        tmp_test=`cat "${1}" | egrep "^#[[:blank:]]*include"`
        if [ "${tmp_test}" = "" ]; then
            return 0
        fi
        #echo "error: cat \"${1}\" | egrep \"^#[[:blank:]]*include\" > ${tmp_plo_test}"
        return 1
    fi

    tmp_col_test=""
    while read line
    do
        tmp_x=`expr "$line" : '^#[[:blank:]]*include[[:blank:]]\{1,\}[\"\<]\{1\}\([[:print:]]\{1,\}\)[\"\>]\{1\}[[:print:]]*'`

        if [ "${tmp_x}" = "" ]; then
            continue
        fi

        tmp_col_test="${tmp_col_test} ${tmp_x}"
    done < $tmp_plo_test
    rm -rf $tmp_plo_test

    ###################################################
    for tmp_x in $tmp_col_test
    do
        if [ "${tmp_x}" = "" ]; then
            continue
        fi

        tmp_fpath=""
        tmp_is_find=0
        for tmp_ei in ${ddk_cflags_include_paths}
        do
            tmp_fpath="${tmp_ei}/${tmp_x}"
            if test -f $tmp_fpath; then
                tmp_is_find=1
                break
            fi
        done

        if [ $tmp_is_find -eq 0 ]; then
            continue
        fi

        ddk_plo_has_include "${tmp_fpath}"
        if [ $? -eq 1 ]; then
            continue
        fi

        ddk_plo_add_include "${tmp_fpath}"

        tmp_time=$(ddk_call_mtime "$tmp_fpath")
        if [ $tmp_time -gt $tmp_plo_max_time_includes ]; then
            tmp_plo_max_time_includes=$tmp_time
            tmp_plo_max_time_includes_nm=$tmp_fpath
        fi

        ddk_plo_col_includes "${tmp_fpath}"
        ret=$?

        if [ $ret -ne 0 ]; then
            echo "error: ddk_plo_col_includes : ${tmp_fpath}"
            return $ret
        fi
    done

    return 0
}

ddk_plo_save(){
    tmp_plo_max_time_includes=0
    tmp_headers=""

    ddk_plo_col_includes "${tmp_src}"
    if [ $? -ne 0 ]; then
        ddk_exit 1 "error: ddk_plo_col_includes \"${tmp_src}\""
    fi

    tmp_time=$(ddk_call_mtime "$tmp_plo")
    if [ $tmp_time -ne $tmp_plo_max_time_includes ]; then
        if test -f ${tmp_plo}; then
            rm -rf "${tmp_plo}"
            if [ $? -ne 0 ]; then
                ddk_exit 1 "rm -rf \"${tmp_plo}\""
            fi
        fi

        for tmp_x in $tmp_headers
        do
            `echo "$tmp_x" >> "${tmp_plo}"`
            if [ $? -ne 0 ]; then
                ddk_exit 1 "error: Not save to ${tmp_plo}"
            fi
        done

        touch -r "${tmp_plo_max_time_includes_nm}" "${tmp_plo}"
        if [ $? -ne 0 ]; then
            ddk_exit 1 "error: touch -r \"${tmp_plo_max_time_includes_nm}\" \"${tmp_plo}\""
        fi
    fi

}

ddk_plo_load(){
    if test ! -f ${tmp_plo}; then
        return 1
    fi

    tmp_time_plo=$(ddk_call_mtime "${tmp_plo}")
    while read line
    do
        tmp_time_test=$(ddk_call_mtime "${line}")
        if [ $tmp_time_test -eq 0 ]; then
            return 1
        fi
        if [ $tmp_time_plo -lt $tmp_time_test ]; then
            return 1
        fi
    done < "${tmp_plo}"

    return 0
}

