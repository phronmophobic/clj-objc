#!/bin/bash

set -e
set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

clang++ \
    -I ./thirdparty/include/ffi \
    -I "$DIR/../library" \
    -c \
    -arch x86_64 \
    clj_objc.mm

clang++ \
    -c \
    -I "$DIR/../library" \
    -I ./thirdparty/include/ffi \
    -arch x86_64 \
    ffi_test.mm


clang++ \
    -framework Foundation \
    -lffi \
    -arch x86_64 \
    ffi_test.o \
    clj_objc.o \
    -L "$DIR/../library" \
    -L "." \
    -l cljobc \
    -o ffi_test
    


 
