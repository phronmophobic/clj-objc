#!/bin/bash

set -x
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

PROJECT_DIR="$DIR/.."

cd ..

clojure -X:depstar-objc

pushd library

rm -rf ./tmp
    # --native-compiler-options='-lffi' \
    # --native-compiler-options='-I/opt/local/include' \
    # --native-compiler-options='-L/opt/local/lib/' \
INITIALIZE_AT_BUILD_TIME="clojure,com.phronemophobic,tech.v3,tech.v3.datatype,tech.v3.datatype.ffi,tech.v3.parallel,tech.v3.resource,primitive_math,primitive_math$unuse_primitive_operators,primitive_math$using_primitive_operators_QMARK_,primitive_math$use_primitive_operators,primitive_math$variadic_predicate_proxy,primitive_math$variadic_proxy,primitive_math$unuse_primitive_operators,primitive_math$using_primitive_operators_QMARK_,primitive_math$use_primitive_operators,primitive_math$variadic_predicate_proxy,primitive_math$variadic_proxy"


time \
    $GRAALVM_HOME/bin/native-image \
    --report-unsupported-elements-at-runtime \
    --initialize-at-build-time="$INITIALIZE_AT_BUILD_TIME" \
    --no-fallback \
    --no-server \
    -H:+ReportExceptionStackTraces \
    -J-Dclojure.spec.skip-macros=true \
    -J-Dclojure.compiler.direct-linking=true \
    -J-Dtech.v3.datatype.graal-native=true \
    -jar ../target/clj-objc-uber.jar \
    --shared \
    -H:Name=libcljobc

popd
