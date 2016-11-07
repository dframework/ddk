#!/bin/sh

call(){
    tmp_call_cmd=`expr "${1}" : '\([a-zA-Z0-9_-]\{1,\}\)'`
    tmp_call_val=`expr "${1}" : '[a-zA-Z0-9_-]\{1,\}\([[:print:]]*\)'`
    #echo "call: [$1]"
    #echo "call: [$1], cmd=[$tmp_call_val]"

    case "${tmp_call_cmd}" in
    my-dir)
        echo "${DDK_ARG_DEST}"
    ;;
    esac
}

call_target(){
    $1
}

call_make_dir(){
    if test ! -d "${1}"; then
        mkdir -p "${1}"
        ddk_exit $? "error:: mkdir -p \"${1}\""
    fi
}

call_install_array(){
    tmp_dst=""
    tmp_cnt=$#
    tmp_rnd=0
    for tmp_nm in "$@"
    do
        tmp_rnd=$(($tmp_rnd+1))
        if [ $tmp_rnd -eq $tmp_cnt ]; then
            tmp_dst=$tmp_nm
        fi
    done

    if [ "$tmp_dst" = "" ]; then
        ddk_exit 1 "error:: install \"$@\""
    fi

    tmp_rnd=0
    for tmp_nm in "$@"
    do
        tmp_rnd=$(($tmp_rnd+1))
        if [ $tmp_rnd -eq $tmp_cnt ]; then
            break
        fi
        call_install "$tmp_nm" "$tmp_dst"
    done
}

call_install(){
   if [ "${3}" != "" ]; then
       call_install_array "$@"
       return $?
   fi

   tmp_expr=`expr "${2}" : '\([[:print:]]\{1,\}\)/\{1,\}\$'`
   if [ "$tmp_expr" != "" ]; then
       call_make_dir "$tmp_expr"
   else
       call_make_dir "$2"
   fi

    if test -d "${1}"; then
        cp -R ${1} ${2}
        ddk_exit $? "error:: cp -R ${1} ${2}"
        echo "    install: ${1} ${2} ... OK"
        return 0
    fi

    if test -f "${1}"; then
        cp ${1} ${2}
        ddk_exit $? "error:: cp ${1} ${2}"
        echo "    install: ${1} ${2} ... OK"
        return 0
    fi

    ddk_exit 1 "error:: not install ${1} ${2}"
}

# -----------------------------------------------------------------
#
#     P A C K A G E
#
# -----------------------------------------------------------------

call_package_get_pkgname(){
    # 1: mod, 2: version 3: dst
    # $(call_package_get_pkgname "")
    local pkgnm=""
    if [ "${2}" != "" ]; then
        pkgnm="${1}-${2}-${3}"
    else
        pkgnm="${1}-${3}"
    fi

    if [ "${DDK_ENV_OSNAME}" = "" ]; then
        pkgnm="${pkgnm}-unknownos"
    else
        case $DDK_ENV_OSNAME in
        linux)
          if test -f "/etc/issue" ; then
            local issue=""
              issue=`cat /etc/issue`
              issue=`expr "$issue" : '^\([a-zA-Z0-0]\{1,\}\)[[:blank:]]\{1,\}'`
              issue=`echo "$issue" | tr '[A-Z]' '[a-z]'`
              pkgnm="${pkgnm}-${issue}"
          else
              pkgnm="${pkgnm}-${DDK_ENV_OSNAME}"
          fi
        ;;
        *)
            pkgnm="${pkgnm}-${DDK_ENV_OSNAME}"
        ;;
        esac
    fi
    echo $pkgnm
}

call_package_start(){
    tmp_pkg_nm=""
    tmp_pkg_target=""
    tmp_pkg_dst=""
    tmp_pkg_path=""
    tmp_pkg_mod=""
    tmp_pkg_version=""

    local tmp_a_va=""
    local tmp_c=""
    tmp_a_va=$(echo "$@" | tr "," "\n")
    tmp_c=0
    for tmp_x in $tmp_a_va
    do
        tmp_c=$(($tmp_c+1))
        case "$tmp_c" in
        1) tmp_pkg_target=$tmp_x ;;
        2) tmp_pkg_dst=$tmp_x ;;
        3) tmp_pkg_mod=$tmp_x ;;
        4) tmp_pkg_version=$tmp_x ;;
        esac
    done

    case "$tmp_pkg_dst" in
    bin) ;;
    lib) ;;
    dev) ;;
    *) ddk_exit 1 "  Has not pkg-dst (bin,lib,dev)" ;;
    esac

    case "$tmp_pkg_target" in
    deb) echo "  Build deb-${tmp_pkg_dst} Package ${DDK_ARG_DEST}" ;;
    sis) echo "  Build sis-${tmp_pkg_dst} Package ${DDK_ARG_DEST}" ;;
    #rpm) echo "  Build rpm-${tmp_pkg_dst} Package ${DDK_ARG_DEST}" ;;
    *) ddk_exit 1 "  Has not pkg-target (deb,sis) (1)" ;;
    esac

    tmp_pkg_nm=$(call_package_get_pkgname "${tmp_pkg_mod}" "${tmp_pkg_version}" "${tmp_pkg_dst}")
    tmp_pkg_path="${DDK_ENV_TARGET_PKG}/${tmp_pkg_mod}/${tmp_pkg_target}/${tmp_pkg_nm}"
    echo "    Purpose: [${tmp_pkg_path}]\n"

    if test -d $tmp_pkg_path; then
        rm -rf "${tmp_pkg_path}"
        ddk_exit $? "error: rm -rf \"${tmp_pkg_path}\""
    fi

    case "$tmp_pkg_target" in
    deb)
        mkdir -p "${tmp_pkg_path}/DEBIAN"
        ddk_exit $? "error: mkdir -p \"${tmp_pkg_path}/DEBIAN\""
    ;;
    sis)
        mkdir -p "${tmp_pkg_path}/DDKSIS"
        ddk_exit $? "error: mkdir -p \"${tmp_pkg_path}/DDKSIS\""
    ;;
    #rpm)
    #    mkdir -p "${tmp_pkg_path}"
    #    ddk_exit $? "error: mkdir -p \"${tmp_pkg_path}\""
    #;;
    *) ddk_exit 1 "  Has not pkg-target (deb,sis) (2)" ;;
    esac
}

call_package_deb_end(){
    if test ! -d ${DDK_ARG_DEST}/pkg-deb; then
        ddk_exit 1 "error: Not found ${DDK_ARG_DEST}/pkg-deb"
    fi

    cp ${DDK_ARG_DEST}/pkg-deb/* ${tmp_pkg_path}/DEBIAN/
    ddk_exit $? "error: cp ${DDK_ARG_DEST}/pkg-deb/* ${tmp_pkg_path}/DEBIAN/"
    echo "    * cp ${DDK_ARG_DEST}/pkg-deb/* ${tmp_pkg_path}/DEBIAN/ ... OK"

    if test -f ${tmp_pkg_path}/DEBIAN/preinst; then
        chmod 775 ${tmp_pkg_path}/DEBIAN/preinst
        ddk_exit $? "error: chmod 775 ${tmp_pkg_path}/DEBIAN/preinst"
        echo "    * chmod 775 ${tmp_pkg_path}/DEBIAN/preinst ... OK"
    fi

    if test -f ${tmp_pkg_path}/DEBIAN/postinst; then
        chmod 775 ${tmp_pkg_path}/DEBIAN/postinst
        ddk_exit $? "error: chmod 775 ${tmp_pkg_path}/DEBIAN/postinst"
        echo "    * chmod 775 ${tmp_pkg_path}/DEBIAN/postinst ... OK"
    fi

    tmp_err=`dpkg -b ${tmp_pkg_path}`
    ddk_exit $? "error: dpkg -b ${tmp_pkg_path}"
    echo "    * dpkg -b ${tmp_pkg_path} ... OK"
}

call_package_sis_end(){
    if test ! -d ${DDK_ARG_DEST}/pkg-sis; then
        ddk_exit 1 "error: Not found ${DDK_ARG_DEST}/pkg-sis"
    fi

    cp ${DDK_ARG_DEST}/pkg-sis/* ${tmp_pkg_path}/DDKSIS/
    ddk_exit $? "error: cp ${DDK_ARG_DEST}/pkg-sis/* ${tmp_pkg_path}/DDKSIS/"
    echo "    * cp ${DDK_ARG_DEST}/pkg-sis/* ${tmp_pkg_path}/DDKSIS/ ... OK"

    if test -f ${tmp_pkg_path}/DDKSIS/presis; then
        chmod 775 ${tmp_pkg_path}/DDKSIS/presis
        ddk_exit $? "error: chmod 775 ${tmp_pkg_path}/DDKSIS/presis"
        echo "    * chmod 775 ${tmp_pkg_path}/DDKSIS/presis ... OK"
    fi

    if test -f ${tmp_pkg_path}/DDKSIS/postsis; then
        chmod 775 ${tmp_pkg_path}/DDKSIS/postsis
        ddk_exit $? "error: chmod 775 ${tmp_pkg_path}/DDKSIS/postsis"
        echo "    * chmod 775 ${tmp_pkg_path}/DDKSIS/postsis ... OK"
    fi

    tmp_curpwd=`pwd`
    cd ${tmp_pkg_path}/../
    tmp_err=`tar cvfz ${tmp_pkg_nm}.tar.gz ${tmp_pkg_nm}`
    tmp_no=$?
    cd ${tmp_curpwd}
    ddk_exit $tmp_no "error: tar cvfz ${tmp_pkg_nm}.tar.gz ${tmp_pkg_nm}"
    echo "    * create ${tmp_pkg_nm}.tar.gz OK"

    cat ${DDK_ENV_HOME}/build/sis/sis.sh ${tmp_pkg_path}/../${tmp_pkg_nm}.tar.gz > ${tmp_pkg_path}/../${tmp_pkg_nm}.sh
    ddk_exit $? "error: cat ${DDK_ENV_HOME}/sis/sis.sh ${tmp_pkg_path}/../${tmp_pkg_nm}.tar.gz > ${tmp_pkg_path}/../${tmp_pkg_nm}.sh"
    chmod 775 ${tmp_pkg_path}/../${tmp_pkg_nm}.sh
    ddk_exit $? "error: chmod 775 ${tmp_pkg_path}/../${tmp_pkg_nm}.sh"
    rm -rf ${tmp_pkg_path}/../${tmp_pkg_nm}.tar.gz
    ddk_exit $? "error: rm -rf ${tmp_pkg_path}/../${tmp_pkg_nm}.tar.gz"
    echo "    * create ${tmp_pkg_path}/../${tmp_pkg_nm}.sh ... OK"
}

call_package_rpm_end(){
    echo ""
}

call_package_end(){
    if [ "$tmp_pkg_path" = "" ]; then
       ddk_exit 1 "  Has not pkg-path at package-end function."
    fi

    echo ""

    case "$tmp_pkg_target" in
    deb) call_package_deb_end ;;
    sis) call_package_sis_end ;;
    #rpm) call_package_rpm_end ;;
    *) ddk_exit 1 "  Has not pkg-target (deb,sis) at package-end function" ;;
    esac
}

call_package_install(){
    local tmp_a_va=""
    local tmp_c=""
    tmp_a_va=$(echo "$@" | tr "," "\n")
    tmp_c=0
    for tmp_x in $tmp_a_va
    do
        tmp_c=$(($tmp_c+1))
        case "$tmp_c" in
        1) tmp_pkg_target=$tmp_x ;;
        2) tmp_pkg_dst=$tmp_x ;;
        3) tmp_pkg_mod=$tmp_x ;;
        4) tmp_pkg_version=$tmp_x ;;
        esac
    done

    case "$tmp_pkg_dst" in
    bin) ;;
    lib) ;;
    dev) ;;
    *) ddk_exit 1 "  Has not pkg-dst (bin,lib,dev)" ;;
    esac

    case "$tmp_pkg_target" in
    deb) echo "  Install package deb-${tmp_pkg_dst}" ;;
    sis) echo "  Install package sis-${tmp_pkg_dst}" ;;
    #rpm) echo "  Install package rpm-${tmp_pkg_dst}" ;;
    *) ddk_exit 1 "  Has not pkg-target (deb,sis) for install package (1)" ;;
    esac

    tmp_pkg_nm=$(call_package_get_pkgname "${tmp_pkg_mod}" "${tmp_pkg_version}" "${tmp_pkg_dst}")
    tmp_pkg_path_p="${DDK_ENV_TARGET_PKG}/${tmp_pkg_mod}/${tmp_pkg_target}"
    tmp_pkg_path="${tmp_pkg_path_p}/${tmp_pkg_nm}"

    case "$tmp_pkg_target" in
    deb)
        sudo gdebi ${tmp_pkg_path_p}/${tmp_pkg_nm}.deb
        ddk_exit $? "error: sudo gdebi ${tmp_pkg_path_p}/${tmp_pkg_nm}.deb"
    ;;
    sis)
        sudo ${tmp_pkg_path_p}/${tmp_pkg_nm}.sh
        ddk_exit $? "error: sudo ${tmp_pkg_path_p}/${tmp_pkg_nm}.sh"
        
    ;;
    #rpm) echo "  Install package rpm-${tmp_pkg_dst}" ;;
    *) ddk_exit 1 "  Has not pkg-target (deb,sis) for install package (2)" ;;
    esac
}

call_package_array(){
    tmp_dst=""
    tmp_cnt=$#
    tmp_rnd=0
    for tmp_nm in "$@"
    do
        tmp_rnd=$(($tmp_rnd+1))
        if [ $tmp_rnd -eq $tmp_cnt ]; then
            tmp_dst=$tmp_nm
        fi
    done

    if [ "$tmp_dst" = "" ]; then
        ddk_exit 1 "error:: package \"$@\""
    fi

    tmp_rnd=0
    for tmp_nm in "$@"
    do
        tmp_rnd=$(($tmp_rnd+1))
        if [ $tmp_rnd -eq $tmp_cnt ]; then
            break
        fi
        call_package "$tmp_nm" "$tmp_dst"
    done
}

call_package(){
   if [ "${3}" != "" ]; then
       call_package_array "$@"
       return $?
   fi

   tmp_expr=`expr "${2}" : '\([[:print:]]\{1,\}\)/\{1,\}\$'`
   if [ "$tmp_expr" != "" ]; then
       call_make_dir "${tmp_pkg_path}/${tmp_expr}"
   else
       call_make_dir "${tmp_pkg_path}/${2}"
   fi

    if test -d "${1}"; then
        cp -R ${1} ${tmp_pkg_path}/${2}
        ddk_exit $? "error:: cp -R ${1} ${tmp_pkg_path}/${2}"
        echo "    * package: ${1} (purpose)${2} ... OK"
        return 0
    fi

    if test -f "${1}"; then
        cp ${1} ${tmp_pkg_path}/${2}
        ddk_exit $? "error:: cp ${1} ${tmp_pkg_path}/${2}"
        echo "    * package: ${1} (purpose)${2} ... OK"
        return 0
    fi

    ddk_exit 1 "error:: not package: ${1} ${tmp_pkg_path}/${2}"
}

