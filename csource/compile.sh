#!/bin/bash

set -e
set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"


clang++ \
    -I ./thirdparty/include/ffi \
    -I "$DIR/../library" \
    -c \
    -g \
    -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
    -target arm64-apple-ios14.1 \
    -arch arm64 \
    clj_objc.mm








