#!/bin/bash -e
set -e
has() {
  type "$1" > /dev/null 2>&1
  return $?
}


if has "curl"; then
  DOWNLOAD="curl -sSOL"
elif has "wget"; then
  DOWNLOAD="wget -nc"
else
  echo "Error: you need curl or wget to proceed" >&2;
  exit 1
fi

VERSION=1
NODE_VERSION=v0.10.23
C9_DIR=$HOME/.c9
NPM=$C9_DIR/node/bin/npm
NODE=$C9_DIR/node/bin/node

start() {
  if [ $# -lt 1 ]; then
    start base
    return
  fi

  check_deps
  
  # Try to figure out the os and arch for binary fetching
  local uname="$(uname -a)"
  local os=
  local arch="$(uname -m)"
  case "$uname" in
    Linux\ *) os=linux ;;
    Darwin\ *) os=darwin ;;
    SunOS\ *) os=sunos ;;
    FreeBSD\ *) os=freebsd ;;
  esac
  case "$uname" in
    *x86_64*) arch=x64 ;;
    *i*86*) arch=x86 ;;
    *armv6l*) arch=arm-pi ;;
  esac
  
  if [ $os != "linux" ] && [ $os != "darwin" ]; then
    echo "Unsupported Platform: $os $arch" 1>&2
    exit 1
  fi
  
  if [ $arch != "x64" ] && [ $arch != "x86" ]; then
    echo "Unsupported Architecture: $os $arch" 1>&2
    exit 1
  fi
  
  case $1 in
    "help" )
      echo
      echo "Cloud9 Installer"
      echo
      echo "Usage:"
      echo "    install help                       Show this message"
      echo "    install install [name [name ...]]  Download and install a set of packages"
      echo "    install ls                         List available packages"
      echo
    ;;

    "ls" )
      echo "!node - Node.js"
      echo "!tmux_install - TMUX"
      echo "!nak - NAK"
      echo "!vfsextend - VFS extend"
      echo "!ptyjs - pty.js"
      echo "coffee - Coffee Script"
      echo "less - Less"
      echo "sass - Sass"
      echo "typescript - TypeScript"
      echo "stylus - Stylus"
      # echo "go - Go"
      # echo "heroku - Heroku"
      # echo "rhc - RedHat OpenShift"
      # echo "gae - Google AppEngine"
    ;;
    
    "install" )
      shift
    
      # make sure dirs are around
      mkdir -p $C9_DIR/bin
      mkdir -p $C9_DIR/node_modules
      cd $C9_DIR
    
      # install packages
      while [ $# -ne 0 ]
      do
        time eval ${1} $os $arch
        shift
      done
      
      # finalize
      pushd $C9_DIR/node_modules/.bin
      for FILE in $C9_DIR/node_modules/.bin/*; do
        if [ `uname` == Darwin ]; then
          sed -i "" -E s:'#!/usr/bin/env node':"#!$NODE":g $(readlink $FILE)
        else
          sed -i -E s:'#!/usr/bin/env node':"#!$NODE":g $(readlink $FILE)
        fi
      done
      popd
      
      echo $VERSION > $HOME/.c9/installed
      echo :Done.
    ;;
    
    "base" )
      echo "Installing base packages. Use --help for more options"
      start install node tmux_install nak ptyjs vfsextend
    ;;
    
    * )
      start base
    ;;
  esac
}

check_deps() {
  for DEP in make gcc; do
    if ! has $DEP; then
      echo "Error: you need $DEP to proceed" >&2
      exit 1
    fi
  done
}

# NodeJS

node(){
  # clean up 
  rm -rf node 
  rm -rf node-$NODE_VERSION*
  
  echo :Installing Node $NODE_VERSION
  
  $DOWNLOAD http://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-$1-$2.tar.gz
  tar xvfz node-$NODE_VERSION-$1-$2.tar.gz
  mv node-$NODE_VERSION-$1-$2 node
  rm node-$NODE_VERSION-$1-$2.tar.gz
}

compile_tmux(){
  cd "$C9_DIR"
  tar xzvf libevent-1.4.14b-stable.tar.gz
  rm libevent-1.4.14b-stable.tar.gz
  cd libevent-1.4.14b-stable
  echo ":Configuring Libevent"
  ./configure --prefix="$C9_DIR/local"
  echo ":Compiling Libevent"
  make
  echo ":Installing libevent"
  make install
 
  cd "$C9_DIR"
  tar xzvf ncurses-5.9.tar.gz
  rm ncurses-5.9.tar.gz
  cd ncurses-5.9
  echo ":Configuring Ncurses"
  ./configure --prefix="$C9_DIR/local"
  echo ":Compiling Ncurses"
  make
  echo ":Installing Ncurses"
  make install
 
  cd "$C9_DIR"
  tar zxvf tmux-1.6.tar.gz
  rm tmux-1.6.tar.gz
  cd tmux-1.6
  echo ":Configuring Tmux"
  ./configure CFLAGS="-I$C9_DIR/local/include -I$C9_DIR/local/include/ncurses" CPPFLAGS="-I$C9_DIR/local/include -I$C9_DIR/local/include/ncurses" LDFLAGS="-static-libgcc -L$C9_DIR/local/lib" LIBEVENT_CFLAGS="-I$C9_DIR/local/include" LIBEVENT_LIBS="-static -L$C9_DIR/local/lib -levent" LIBS="-L$C9_DIR/local/lib/ncurses -lncurses" --prefix="$C9_DIR/local"
  echo ":Compiling Tmux"
  make
  echo ":Installing Tmux"
  make install
}

tmux_download(){
  echo ":Downloading tmux source code"
  $DOWNLOAD https://raw.github.com/c9/install/master/packages/tmux/libevent-1.4.14b-stable.tar.gz
  $DOWNLOAD https://raw.github.com/c9/install/master/packages/tmux/ncurses-5.9.tar.gz
  $DOWNLOAD https://raw.github.com/c9/install/master/packages/tmux/tmux-1.6.tar.gz
}

check_tmux_version(){
  tmux_version=$(tmux -V | cut -d' ' -f2)  
  if [ $(python -c "ok = 1 if $tmux_version>=1.6 else 0; print ok") -eq 1 ]; then
    return 0
  else
    return 1
  fi
}

tmux_install(){
  echo :Installing TMUX
  mkdir -p "$C9_DIR/bin"

if has "tmux" && check_tmux_version; then
  echo ':A good version of tmux was found, creating a symlink'
  ln -sf $(which tmux) ~/.c9/bin/tmux
  return 0
# If tmux is not present or at the wrong version, we will install it
else
  if [ $os = "darwin" ]; then
    if ! has "brew"; then
      ruby -e "$($DOWNLOAD https://raw.github.com/mxcl/homebrew/go/install)"
    fi
    brew install tmux > /dev/null ||
      (brew remove tmux &>/dev/null && brew install tmux >/dev/null)
    ln -sf $(which tmux) ~/.c9/bin/tmux
  # Linux
  else
    tmux_download  
    compile_tmux
    ln -sf "$C9_DIR"/local/bin/tmux "$C9_DIR"/bin/tmux
  fi
fi
}

vfsextend(){
  echo :Installing VFS extend
  $DOWNLOAD https://raw.github.com/c9/install/master/packages/extend/c9-vfs-extend.tar.gz
  tar xvfz c9-vfs-extend.tar.gz
  rm c9-vfs-extend.tar.gz
}

nak(){
  echo :Installing Nak
  $NPM install nak@0.3.1
}

ptyjs(){
  echo :Installing pty.js
  $NPM install pty.js@0.2.3
}

coffee(){
  echo :Installing Coffee Script
  $NPM install coffee
}

less(){
  echo :Installing Less
  $NPM install less
}

sass(){
  echo :Installing Sass
  $NPM install sass
}

typescript(){
  echo :Installing TypeScript
  $NPM install typescript  
}

stylus(){
  echo :Installing Stylus
  $NPM install stylus  
}

# go(){
  
# }

# heroku(){
  
# }

# rhc(){
  
# }

# gae(){
  
# }

start $@
