#!/bin/sh

call(){
    tmp_call_cmd=`expr "${1}" : '\([a-zA-Z0-9_-]\+\)'`
    tmp_call_val=`expr "${1}" : '[a-zA-Z0-9_-]\+\([[:print:]]*\)'`
    #echo "call: [$1]"
    #echo "call: [$1], cmd=[$tmp_call_val]"

    case "${tmp_call_cmd}" in
    my-dir)
        echo "${DDK_ARG_DEST}"
    ;;
    esac
}

