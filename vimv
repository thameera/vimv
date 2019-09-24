#!/bin/bash

# Lists the current directory's files in Vim, so you can edit it and save to rename them
# USAGE: vimv [file1 file2]
# https://github.com/thameera/vimv

TMPDIR=${TMPDIR:-'/tmp'} 

if [ $# -ne 0 ]; then
    src=( "$@" )
else
    IFS=$'\r\n' GLOBIGNORE='*' command eval  'src=($(ls))'
fi

touch $TMPDIR/vimv.$$
for ((i=0;i<${#src[@]};++i)); do
    echo "${src[i]}" >> $TMPDIR/vimv.$$
done

${EDITOR:-vi} $TMPDIR/vimv.$$

IFS=$'\r\n' GLOBIGNORE='*' command eval  'dest=($(cat $TMPDIR/vimv.$$))'

count=0
for ((i=0;i<${#src[@]};++i)); do
    if [ "${src[i]}" != "${dest[i]}" ]; then
        mkdir -p "`dirname "${dest[i]}"`"
        if git ls-files --error-unmatch "${src[i]}" > /dev/null 2>&1; then
            git mv "${src[i]}" "${dest[i]}"
        else
            mv "${src[i]}" "${dest[i]}"
        fi
        ((count++))
    fi
done

echo "$count" files renamed.

rm $TMPDIR/vimv.$$
