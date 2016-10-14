#!/bin/sh

ddk_compile_add(){
    tmp_mkbuf="${tmp_mkbuf}\n${1}\n"
}

ddk_compile_clear_cmd_prefix(){
  if [ "${tmp_cmd_prefix}" != "" ]; then
    ddk_compile_add "}"
    tmp_cmd_prefix=""
  fi
}

ddk_compile_call_func(){
  tmp_nm=`expr "${tmp_call}" : '\([a-zA-Z0-9_-]\{1,\}\)[[:blank:]]*[[:print:]]*'`
  tmp_va=`expr "${tmp_call}" : '[a-zA-Z0-9_-]\{1,\}[[:blank:]]*\([[:print:]]*\)'`

  if [ "$tmp_nm" = "" ]; then
      ddk_exit 1 "syntax error(100): $tmp_call"
  fi

  case "${tmp_nm}" in
  call)
    ddk_compile_add "${tmp_val}"
  ;;
  mk)
    ddk_compile_add "call_make_dir \"${tmp_va}\""
  ;;
  mkdir)
    ddk_compile_add "call_make_dir \"${tmp_va}\""
  ;;
  target)
    tmp_va2=`echo "${tmp_va}" | sed -e 's/-/_/g'`
    ddk_compile_add "call_target ${tmp_va2}"
  ;;
  install)
    ddk_compile_add "call_install ${tmp_va}"
  ;;
  package-start)
    ddk_compile_add "call_package_start \"${tmp_va}\""
  ;;
  package-end)
    ddk_compile_add "call_package_end \"${tmp_va}\""
  ;;
  package-install)
    ddk_compile_add "call_package_install \"${tmp_va}\""
  ;;
  package)
    ddk_compile_add "call_package ${tmp_va}"
  ;;
  *)
    ddk_compile_add "${tmp_nm} ${tmp_va}"
  ;;
  esac
}

ddk_compile_mk_include(){
  tmp_nm=`expr "${tmp_val}" : '^[[:blank:]]*\$([[:blank:]]*\([a-zA-Z0-9_]\{1,\}\)[[:blank:]]*[[:print:]]*'`
  case "${tmp_nm}" in
  CLEAR_VARS)
    ddk_compile_add "CLEAR_VARS"
  ;;
  BUILD_STATIC_LIBRARY)
    ddk_compile_clear_cmd_prefix
    ddk_compile_add "BUILD_STATIC_LIBRARY"
  ;;
  BUILD_SHARED_LIBRARY)
    ddk_compile_clear_cmd_prefix
    ddk_compile_add "BUILD_SHARED_LIBRARY"
  ;;
  BUILD_EXCUTABLE)
    ddk_compile_clear_cmd_prefix
    ddk_compile_add "BUILD_EXCUTABLE"
  ;;
  *)
    ddk_compile_add "include \"${tmp_val}\""
  ;;
  esac
}

ddk_compile_mk_ifdef(){
  tmp_env=`env | egrep "^${1}="`
  if [ "${tmp_env}" = "" ]; then
    echo "0"
  else
    echo "1"
  fi
}

ddk_compile_mk_ifex(){

  tmp_if=`expr "$tmp_val" : '^[[:blank:]]*(\([[:print:]]\{1,\}\))[[:blank:]]*$'`
  tmp_a_if=$(echo "${tmp_if}" | tr "," "\n")

  tmp_no_if=0
  for tmp_o_if in $tmp_a_if
  do
    tmp_no_if=$(($tmp_no_if+1))
    if [ $tmp_no_if -eq 1 ]; then
      tmp_1_if=$tmp_o_if
    elif [ $tmp_no_if -eq 2 ]; then
      tmp_2_if=$tmp_o_if
    else
      ddk_exit 1 "syntax error(7): ${line}"
    fi
  done

  if [ $tmp_no_if -ne 2 ]; then
      ddk_exit 1 "syntax error(8): ${line}"
  fi

  case "${1}" in
  eq)
    ddk_compile_add "if [ ${tmp_1_if} = ${tmp_2_if} ]; then"
  ;;
  eleq)
    ddk_compile_add "elif [ ${tmp_1_if} = ${tmp_2_if} ]; then"
  ;;
  ne)
    ddk_compile_add "if [ ${tmp_1_if} != ${tmp_2_if} ]; then"
  ;;
  elne)
    ddk_compile_add "elif [ ${tmp_1_if} != ${tmp_2_if} ]; then"
  ;;
  gt)
    ddk_compile_add "if [ ${tmp_1_if} > ${tmp_2_if} ]; then"
  ;;
  elgt)
    ddk_compile_add "elif [ ${tmp_1_if} > ${tmp_2_if} ]; then"
  ;;
  lt)
    ddk_compile_add "if [ ${tmp_1_if} < ${tmp_2_if} ]; then"
  ;;
  ellt)
    ddk_compile_add "elif [ ${tmp_1_if} < ${tmp_2_if} ]; then"
  ;;
  esac
}

ddk_compile_mk_nomak(){
    case "${tmp_cmd}" in
    include)
      ddk_compile_mk_include
    ;;
    ifeq)
      ddk_compile_mk_ifex "eq"
    ;;
    ifne|ifneq)
      ddk_compile_mk_ifex "ne"
    ;;
    ifle|ifgt)
      ddk_compile_mk_ifex "gt"
    ;;
    ifge|iflt)
      ddk_compile_mk_ifex "lt"
    ;;
    elifeq|el-ifeq|else-ifeq|el_ifeq|else_ifeq|eleq)
      ddk_compile_mk_ifex "eleq"
    ;;
    elifne|el-ifne|else-ifne|el_ifne|else_ifne|elne)
      ddk_compile_mk_ifex "elne"
    ;;
    elifle|el-ifle|else-ifle|el_ifle|else_ifle|elle)
      ddk_compile_mk_ifex "elgt"
    ;;
    elifge|el-ifge|else-ifge|el_ifge|else_ifge|elge)
      ddk_compile_mk_ifex "ellt"
    ;;
    ifdef)
      if [ "${tmp_val}" = "" ]; then
          ddk_exit 1 "syntax error(9): ${line}"
      fi
      ddk_compile_add "if [ \"\$(ddk_compile_mk_ifdef \"${tmp_val}\")\" = \"1\" ]; then"
    ;;
    ifndef)
      if [ "${tmp_val}" = "" ]; then
          ddk_exit 1 "syntax error(10): ${line}"
      fi
      ddk_compile_add "if [ \"\$(ddk_compile_mk_ifdef \"${tmp_val}\")\" = \"0\" ]; then"
    ;;
    elifdef|el-ifdef|else-ifdef|el_ifdef|else_ifdef)
      if [ "${tmp_val}" = "" ]; then
          ddk_exit 1 "syntax error(11): ${line}"
      fi
      ddk_compile_add "elif [ \"\$(ddk_compile_mk_ifdef ${tmp_val})\" = \"1\" ]; then"
    ;;
    elifndef|el-ifndef|else-ifndef|el_ifndef|else_ifndef)
      if [ "${tmp_val}" = "" ]; then
          ddk_exit 1 "syntax error(12): ${line}"
      fi
      ddk_compile_add "elif [ \"\$(ddk_compile_mk_ifdef ${tmp_val})\" = \"0\" ]; then"
    ;;
    else)
      ddk_compile_add "else"
    ;;
    endif)
      ddk_compile_add "fi"
    ;;
    echo)
      if [ "${tmp_val}" = "" ]; then
        ddk_compile_add "echo \"\""
      else
        ddk_compile_add "echo ${tmp_val}"
      fi
    ;;
    *)
      #echo "x: $tmp_cmd, $tmp_val"
      tmp_cmd=`echo "${tmp_str}" | sed -e 's/-/_/g'`
      ddk_compile_add "${line}"
      #ddk_exit 1 "syntax error(13): ${line}"
    ;;
    esac
}

ddk_compile_mk_cmd_prefix_add_s(){
    if [ "${tmp_cmd_prefix_s}" != "" ]; then
      tmp_cmd_prefix_a_s=$(echo $tmp_cmd_prefix_s | tr " " "\n")
      for tmp_x in $tmp_cmd_prefix_a_s
      do
        if [ "${tmp_x}" = "${tmp_cmd_module}" ]; then
          return 0
        fi
      done
    fi

    tmp_cmd_prefix_s="${tmp_cmd_prefix_s} ${tmp_cmd_module}"
}

ddk_compile_mk_cmd_prefix_add_index(){
    if [ "${tmp_cmd_prefix_index}" != "" ]; then
      tmp_cmd_prefix_a_index=$(echo $tmp_cmd_prefix_index | tr " " "\n")
      for tmp_x in $tmp_cmd_prefix_a_index
      do
        if [ "${tmp_x}" = "${tmp_cmd}" ]; then
          return 0
        fi
      done
    fi

    tmp_cmd_prefix_index="${tmp_cmd_prefix_index} ${tmp_cmd}"
}

ddk_compile_mk_cmd_prefix(){
    if [ "${tmp_cmd_module}" = "" ]; then
      ddk_exit 1 "syntax error(3): ${line}\nsyntax error(3): This syntax between LOCAL_MODULE and BUILD_STATIC_LIBRARY, BUILD_SHARED_LIBRARY, BUILD_EXCUTABLE."
    fi

    tmp_has_prefix=0
    if [ "${tmp_cmd_prefix}" != "" ]; then
      tmp_has_prefix=1
      ddk_compile_clear_cmd_prefix
    fi

    tmp_str="${tmp_cmd_module}_${tmp_cmd}"
    tmp_str=`echo "${tmp_str}" | sed -e 's/-/_/g'`
    tmp_cmd_prefix="${tmp_cmd}"

    ddk_compile_mk_cmd_prefix_add_s
    ddk_compile_mk_cmd_prefix_add_index

    if [ $tmp_has_prefix -eq 1 ]; then
      ddk_compile_add "${tmp_str}(){"
    else
      ddk_compile_add "${tmp_str}(){"
    fi
}

ddk_compile_mk_set(){
    if [ "${tmp_val}" = "=" ]; then
        tmp_val=""
    fi
    case "${tmp_cmd}" in
    LOCAL_MODULE)
      tmp_cmd_module="${tmp_val}"
    ;;
    LOCAL_SUBDIRS)
      DDK_SET_SUBDIRS="${tmp_val}"
    ;;
    LOCAL_NO_SUBDIRS)
      DDK_SET_NO_SUBDIRS="${tmp_val}"
    ;;
    LOCAL_NO_VERSION)
       tmp_val="1"
    ;;
    esac

    if [ "${tmp_pfix}" = "\"" ]; then
        tmp_val=`echo "${tmp_val}" | sed -e 's/\"/\\\"/g'`
    fi

    ddk_compile_add "${tmp_cmd}=${tmp_pfix}${tmp_val}${tmp_sfix}"

    case "${tmp_cmd}" in
    LOCAL_MODULE)
      ddk_compile_add "LOCAL_MODULE_BIN=${tmp_pfix}\${DDK_ENV_TARGET_BUILD}/${tmp_val}${tmp_sfix}"
    ;;
    esac
}

ddk_compile_mk_plus(){
  tmp_pfix="\""
  tmp_sfix="\""

    if [ "${tmp_val}" = "=" ]; then
        tmp_val=""
    fi

  case "${tmp_cmd}" in
  LOCAL_SUBDIRS)
    DDK_SET_SUBDIRS="${DDK_SET_SUBDIRS} ${tmp_val}"
  ;;
  LOCAL_NO_SUBDIRS)
    DDK_SET_NO_SUBDIRS="${DDK_SET_NO_SUBDIRS} ${tmp_val}"
  ;;
  esac

  ddk_compile_add "${tmp_cmd}=${tmp_pfix}\${${tmp_cmd}} ${tmp_val}${tmp_sfix}"
}

ddk_compile_mk_hasmak(){
    tmp_s3=""
    tmp_s1=`expr "$tmp_val" : '^[[:blank:]]*\(\"\)[[:print:]]\{1,\}'`
    if [ "${tmp_s1}" != "" ]; then
      tmp_s2=`expr "$tmp_val" : '[[:print:]]\{1,\}\(\"\)[[:blank:]]*\$'`
      if [ "${tmp_s2}" != "\"" ]; then
        ddk_exit 1 "syntax error(4): ${line}"
      fi
      tmp_s3=`expr "$tmp_val" : '^[[:blank:]]*\"\([[:print:]]\{1,\}\)\"[[:blank:]]*\$'`
    fi

    tmp_pfix=""
    tmp_sfix=""
    if [ "${tmp_s3}" != "" ]; then
      tmp_pfix="\""
      tmp_sfix="\""
      tmp_val="${tmp_s3}"
    else
      tmp_sb=`echo "${tmp_val}" | grep " "`
      if [ "${tmp_sb}" != "" ]; then
        tmp_pfix="\""
        tmp_sfix="\""
      fi
    fi

    tmp_cmd=`echo "${tmp_cmd}" | sed -e 's/-/_/g'`

    case "${tmp_mak}" in
    :)
      ddk_compile_mk_cmd_prefix
    ;;
    =)
      ddk_compile_mk_set
    ;;
    :=)
      ddk_compile_mk_set
    ;;
    +=)
      ddk_compile_mk_plus
    ;;
    *)
      ddk_exit 1 "syntax error(5): ${line} at ${1}:${tmp_no}"
    ;;
    esac
}

ddk_compile_mk(){
# ${1} : directory
# ${2} : Dframework.mk or Application.mk

    tmp_mk_fnm="${1}/${2}"
    if test ! -f "${tmp_mk_fnm}"; then
      return 1
    fi

    tmp_mkbuf="#!/bin/sh\n"
    tmp_cmd_prefix_s=""
    tmp_cmd_prefix_index=""
    tmp_no=0

    ddk_compile_clear_cmd_prefix

    while read line
    do
      tmp_cmd=""
      tmp_call=""
      tmp_val=""
      tmp_mak=""
      tmp_nm=""
      tmp_no=$(($tmp_no+1))

      if [ "${line}" = "" ]; then
        continue
      fi

      cmt=`expr "$line" : '\(^[[:blank:]]*\#\)'`
      if [ "${cmt}" = "#" ]; then
        continue
      fi

      cmt=`expr "$line" : '\(^[[:blank:]]*\@\)'`
      if [ "${cmt}" = "@" ]; then
         tmp_val=`expr "$line" : '^[[:blank:]]*\@\([[:print:]]*\)'`
         ddk_compile_add "${tmp_val}"
        continue
      fi

      tmp_cmd=`expr "$line" : '\(^[a-zA-Z0-9_-]\{1,\}\)[[:blank:]\:\{1,\}]*'`
      if [ "${tmp_cmd}" = "" ]; then
        tmp_call=`expr "$line" : '^[[:blank:]]*\$(\([[:print:]]\{1,\}\))[[:blank:]]*$'`
        if [ "${tmp_call}" != "" ]; then
          ddk_compile_call_func
          continue
        else
          ddk_exit 1 "syntax error(6b): ${line} at ${tmp_mk_fnm}:${tmp_no}"
        fi
      fi

      tmp_mak=`expr "$line" : '^[a-zA-Z0-9_-]\{1,\}[[:blank:]]*\([\:\+\=]\{1,\}\)'`
      if [ "${tmp_mak}" != "" ]; then
        tmp_val=`expr "$line" : '^[a-zA-Z0-9_-]\{1,\}[[:blank:]]*[\:\+\=]\{1,\}[[:blank:]]*\([[:print:]]\{1,\}\)[[:blank:]]*$'`
      else
        tmp_val=`expr "$line" : '^[a-zA-Z0-9_-]\{1,\}[[:blank:]]\{1,\}\([[:print:]]\{1,\}\)[[:blank:]]*$'`
      fi

      if [ "${tmp_mak}" = "" ]; then
        ddk_compile_mk_nomak
      else
        ddk_compile_mk_hasmak
      fi

    done < "${tmp_mk_fnm}"

    ddk_compile_clear_cmd_prefix

    #################################################################
    if [ "${tmp_cmd_prefix_index}" != "" ]; then
      tmp_cmd_prefix_a_index=$(echo $tmp_cmd_prefix_index | tr " " "\n")
      for tmp_x in $tmp_cmd_prefix_a_index
      do
        if [ "${tmp_x}" != "" ]; then
          ddk_compile_add ""
          ddk_compile_add "${tmp_x}(){"
          if [ "${tmp_cmd_prefix_s}" != "" ]; then
            tmp_cmd_prefix_a_s=$(echo $tmp_cmd_prefix_s | tr " " "\n")
            for tmp_y in $tmp_cmd_prefix_a_s
            do
              if [ "${tmp_y}" != "" ]; then
                tmp_str="${tmp_y}_${tmp_x}"
                tmp_str=`echo "${tmp_str}" | sed -e 's/-/_/g'`
                ddk_compile_add " ${tmp_str}"
                tmp_count=$((tmp_count+1))
              fi
            done 
          fi
          ddk_compile_add "\n}"
        fi
      done
    fi

    ddk_compile_add "LOCAL_CMD_PREFIX=\"${tmp_cmd_prefix_index}\""

#echo $tmp_mkbuf

    return 0
}

ddk_get_app_mk(){
    tmp_find=1
    tmp_path=$1
    tmp_init_path=$1
    tmp_init_pwd=`pwd`
    tmp_app_nm=""
    cd $tmp_path
    ddk_exit $? "error:: cd $tmp_path"
    while [ "$tmp_path" != "/" ];
    do
        tmp_app_nm="${tmp_path}/Application.mk"
        if test -f $tmp_app_nm; then
            tmp_find=0
            break
        fi
        cd ..
        tmp_path=`pwd`
    done
    cd $tmp_init_pwd
    ddk_exit $? "error:: cd $tmp_init_pwd"
    return $tmp_find
}

ddk_app_mk(){
    ddk_get_app_mk "${1}"
    tmp_r=$?
    if [ $tmp_r -eq 0 ]; then
        ddk_compile_mk "${tmp_path}" "Application.mk"
        ddk_load_mk "${tmp_path}" "Application.mk"
    fi
}

ddk_excute_mk(){
    if [ "${2}" = "Dframework.mk" ]; then
        ddk_app_mk "${1}"
    fi

    . $3

    if [ "${2}" = "Dframework.mk" ]; then
    if [ "${DDK_ENV_CMD}" != "" ]; then
        tmp_find=0
        for tmp_x in $LOCAL_CMD_PREFIX
        do
            if [ "$tmp_x" = "$DDK_ENV_CMD" ]; then
                tmp_find=1
            fi
        done
        if [ $tmp_find -eq 1 ]; then
            $DDK_ENV_CMD
        fi
    fi
    fi
}

ddk_load_mk(){
# ${1} : directory
# ${2} : Dframework.mk or Application.mk

    tmp_mk_input="${1}/${2}"
    if test ! -f "${tmp_mk_input}"; then
      return 1
    fi

    tmp_mk_output_folder="${DDK_ENV_TARGET_WORKING}${1}"
    tmp_mk_output="${tmp_mk_output_folder}/${2}.S"
    tmp_mk_time_input=$(ddk_call_mtime "$tmp_mk_input")
    tmp_mk_time_output=$(ddk_call_mtime "$tmp_mk_output")
    if [ $tmp_mk_time_input -eq 1 ]; then
        ddk_exit 1 "don't get mtime: $tmp_mk_input"
    fi
    if [ $tmp_mk_time_output -eq 1 ]; then
        ddk_exit 1 "don't get mtime: $tmp_mk_output"
    fi

    if [ $tmp_mk_time_input -eq 0 ]; then
        ddk_exit 1 "ERROR: input file mtime : $tmp_mk_time_input"
    fi

    if [ $tmp_mk_time_input -ne 0 ]; then
        if [ $tmp_mk_time_input -eq $tmp_mk_time_output ]; then
            ddk_excute_mk "${1}" "${2}" "${tmp_mk_output}"
            return 0
        fi
    fi

    if [ "${2}" = "Dframework.mk" ]; then
    if test -d "${tmp_mk_output_folder}"; then
        rm -rf ${tmp_mk_output_folder}/*.Plo
        rm -rf ${tmp_mk_output_folder}/*.o
        rm -rf ${tmp_mk_output_folder}/*.mk.S
        rm -rf ${tmp_mk_output_folder}/*.a
        rm -rf ${tmp_mk_output_folder}/*.so
        rm -rf ${tmp_mk_output_folder}/*.dll
        rm -rf ${tmp_mk_output_folder}/*.exe
    fi
    fi

    if test ! -d "${tmp_mk_output_folder}"; then
      mkdir -p "${tmp_mk_output_folder}"
      if [ $? -ne 0  ]; then
          ddk_exit 1 "error: mkdir -p \"${tmp_mk_output_folder}\""
          exit 1
      fi
    fi

    case "$DDK_ENV_OSNAME" in
    centos|redhat)
        `echo -e ${tmp_mkbuf} > ${tmp_mk_output}`
        res=$?  
    ;;      
    *)
        `echo ${tmp_mkbuf} > ${tmp_mk_output}`
        res=$?
    ;;      
    esac   

    if [ $res -ne 0  ]; then
        ddk_exit 1 "error: write to ${tmp_mk_output}"
    fi

    ddk_excute_mk "${1}" "${2}" "${tmp_mk_output}"

    touch -r ${tmp_mk_input} ${tmp_mk_output}
    if [ $? -ne 0 ]; then
        ddk_exit 1 "touch -r ${tmp_mk_input} ${tmp_mk_output}"
    fi

    return 0
}

