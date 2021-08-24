#!/bin/bash

set -e
set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"

clang++ \
    -arch x86_64 \
    -framework Foundation \
    `pkg-config --static --libs --cflags libffi` \
    -l ffi \
    -dynamiclib \
    -o libcljobjc.dylib \
    clj_objc.mm
