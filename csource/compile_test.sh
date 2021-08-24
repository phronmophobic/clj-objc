#!/bin/bash

set -e
set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

clang++ \
    `pkg-config --cflags libffi` \
    -I "$DIR/../library" \
    -c \
    -DGRAAL \
    -arch x86_64 \
    clj_objc.mm

clang++ \
    -c \
    -I "$DIR/../library" \
    `pkg-config --cflags libffi` \
    -DGRAAL=1 \
    -arch x86_64 \
    ffi_test.mm


clang++ \
    -framework Foundation \
    -arch x86_64 \
    ffi_test.o \
    clj_objc.o \
    -I ./thirdparty/include/ffi \
    -L "$DIR/../library" \
    -L "." \
    -DGRAAL=1 \
    `pkg-config --static --libs --cflags libffi` \
    -l cljobc \
    -o ffi_test
    


 
