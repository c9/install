#!/bin/bash -e
set -ex

cd `dirname $0`
SOURCE=`pwd`

buildPtyRelease() {
  if [ "`"$C9_DIR/node/bin/node" -v`" != "$NODE_VERSION" ] ; then
    exit 1
  fi
  cd "$C9_DIR"
  buildPty
  pushd node_modules/pty.js/
  mkdir -p node_modules
  cp -R ../extend node_modules
  rm -rf tmp
  mkdir -p tmp
  cp build/Release/pty.node tmp/pty.node
  rm -rf build
  
  mkdir -p build/Release
  cp tmp/* build/Release
  rm -rf tmp deps node_modules/nan test
  if hasPty; then
    cd ..
    local target="$SOURCE/pty.js/pty-$NODE_VERSION-$os-$arch.tar.gz"
    rm -f "$target"
    tar -zcvf "$target" pty.js
  fi
  popd
}

. ../install.sh install buildPtyRelease