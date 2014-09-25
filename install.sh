#!/bin/bash -e
set -e
has() {
  type "$1" > /dev/null 2>&1
  return $?
}

# Redirect stdout ( > ) into a named pipe ( >() ) running "tee"
exec > >(tee /tmp/installlog.txt)

# Without this, only stdout would be captured - i.e. your
# log file would not contain any error messages.
exec 2>&1

if has "wget"; then
  DOWNLOAD="wget --no-check-certificate -nc"
elif has "curl"; then
  DOWNLOAD="curl -sSOL"
else
  echo "Error: you need curl or wget to proceed" >&2;
  exit 1
fi

VERSION=1
NODE_VERSION=v0.10.28
C9_DIR=$HOME/.c9
NPM=$C9_DIR/node/bin/npm
NODE=$C9_DIR/node/bin/node

export TMP=$C9_DIR/tmp
export TMPDIR=$TMP

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
  
  if [ "$(ls -la ~ | grep .npm$ | awk '{ print $3 }')" = "root" ] && [ $(id -u) != 0 ]; then
    echo "~/.npm is owned by root. Please chown to your user and try again."
    exit 1
  fi
  
  if [ `python -c 'import gyp; print gyp.__file__' 2> /dev/null` ]; then
  	echo "You have a global gyp installed. Please run 'sudo apt-get remove gyp'"
  	exit 100
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
      echo "!tmux - TMUX"
      echo "!nak - NAK"
      echo "!vfsextend - VFS extend"
      echo "!ptyjs - pty.js"
      echo "!collab - collab"
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
      mkdir -p $C9_DIR/tmp
      mkdir -p $C9_DIR/node_modules
      cd $C9_DIR
    
      # install packages
      while [ $# -ne 0 ]
      do
        if [ "$1" == "tmux" ]; then
          time tmux_install $os $arch
          shift
          continue
        fi
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
      start install node tmux_install nak ptyjs vfsextend collab
    ;;
    
    * )
      start base
    ;;
  esac
}

check_deps() {
  for DEP in make gcc; do
    if ! has $DEP; then
      echo "Error: please install $DEP to proceed" >&2
      if [[ `cat /etc/issue 2>/dev/null` =~ CentOS ]]; then
        echo "To do so, log into your machine and type 'yum groupinstall -y development'" >&2
      else if [[ `cat /proc/version 2>/dev/null` =~ Ubuntu|Debian ]]; then
        echo "To do so, log into your machine and type 'sudo apt-get install build-essential'" >&2
      fi
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
  echo ":Compiling libevent..."
  tar xzvf libevent-2.0.21-stable.tar.gz
  rm libevent-2.0.21-stable.tar.gz
  cd libevent-2.0.21-stable
  echo ":Configuring Libevent"
  ./configure --prefix="$C9_DIR/local"
  echo ":Compiling Libevent"
  make
  echo ":Installing libevent"
  make install
 
  cd "$C9_DIR"
  echo ":Compiling ncurses..."
  tar xzvf ncurses-5.9.tar.gz
  rm ncurses-5.9.tar.gz
  cd ncurses-5.9
  echo ":Configuring Ncurses"
  ./configure --prefix="$C9_DIR/local" --without-cxx
  echo ":Compiling Ncurses"
  make
  echo ":Installing Ncurses"
  make install
 
  cd "$C9_DIR"
  echo ":Compiling tmux..."
  tar zxvf tmux-1.9.tar.gz
  rm tmux-1.9.tar.gz
  cd tmux-1.9
  echo ":Configuring Tmux"
  ./configure CFLAGS="-I$C9_DIR/local/include -I$C9_DIR/local/include/ncurses" CPPFLAGS="-I$C9_DIR/local/include -I$C9_DIR/local/include/ncurses" LDFLAGS="-static-libgcc -L$C9_DIR/local/lib" LIBEVENT_CFLAGS="-I$C9_DIR/local/include" LIBEVENT_LIBS="-static -L$C9_DIR/local/lib -levent" LIBS="-L$C9_DIR/local/lib/ncurses -lncurses" --prefix="$C9_DIR/local"
  echo ":Compiling Tmux"
  make
  echo ":Installing Tmux"
  make install
}

tmux_download(){
  echo ":Downloading tmux source code"
  echo ":N.B: This will take a while. To speed this up install tmux 1.9 manually on your machine and restart this process."
  
  echo ":Downloading Libevent..."
  $DOWNLOAD https://raw.githubusercontent.com/c9/install/master/packages/tmux/libevent-2.0.21-stable.tar.gz
  echo ":Downloading Ncurses..."
  $DOWNLOAD https://raw.githubusercontent.com/c9/install/master/packages/tmux/ncurses-5.9.tar.gz
  echo ":Downloading Tmux..."
  $DOWNLOAD https://raw.githubusercontent.com/c9/install/master/packages/tmux/tmux-1.9.tar.gz
}

check_tmux_version(){
  if [ ! -x $1 ]; then
    return 1
  fi
  tmux_version=$($1 -V | sed -e's/[a-z ]//g')  
  if [ ! "$tmux_version" ]; then
    return 1
  fi

  if [ $(python -c "ok = 1 if 1.7<=$tmux_version else 0; print ok") -eq 1 ]; then
    return 0
  else
    return 1
  fi
}

tmux_install(){
  echo :Installing TMUX
  mkdir -p "$C9_DIR/bin"

  if check_tmux_version $C9_DIR/bin/tmux; then
    echo ':Existing tmux version is up-to-date'
  
  # If we can support tmux 1.9 or detect upgrades, the following would work:
  elif has "tmux" && check_tmux_version tmux; then
    echo ':A good version of tmux was found, creating a symlink'
    ln -sf $(which tmux) "$C9_DIR"/bin/tmux
    return 0
  
  # If tmux is not present or at the wrong version, we will install it
  else
    if [ $os = "darwin" ]; then
      if ! has "brew"; then
        ruby -e "$($DOWNLOAD https://raw.githubusercontent.com/mxcl/homebrew/go/install)"
      fi
      brew install tmux > /dev/null ||
        (brew remove tmux &>/dev/null && brew install tmux >/dev/null)
      ln -sf $(which tmux) "$C9_DIR"/bin/tmux
    # Linux
    else
      if ! has "make"; then
        echo ":Could not find make. Please install make and try again."
        exit 100;
      fi
    
      tmux_download  
      compile_tmux
      ln -sf "$C9_DIR"/local/bin/tmux "$C9_DIR"/bin/tmux
    fi
  fi
  
  if ! check_tmux_version $C9_DIR/bin/tmux; then
    echo "Installed tmux does not appear to work:"
    exit 100
  fi
}

vfsextend(){
  echo :Installing VFS extend
  $DOWNLOAD https://raw.githubusercontent.com/c9/install/master/packages/extend/c9-vfs-extend.tar.gz
  tar xvfz c9-vfs-extend.tar.gz
  rm c9-vfs-extend.tar.gz
}

collab(){
  echo :Installing Collab Dependencies
  $NPM install sqlite3@2.1.18
  $NPM install sequelize@2.0.0-beta.0
  mkdir -p "$C9_DIR"/lib
  cd "$C9_DIR"/lib
  $DOWNLOAD https://raw.githubusercontent.com/c9/install/master/packages/sqlite3/linux/sqlite3.tar.gz
  tar xvfz sqlite3.tar.gz
  rm sqlite3.tar.gz
  ln -sf "$C9_DIR"/lib/sqlite3/sqlite3 "$C9_DIR"/bin/sqlite3
}

nak(){
  echo :Installing Nak
  $NPM install https://github.com/c9/nak/tarball/c9
}

ptyjs(){
  echo :Installing pty.js
  
  PYTHONVERSION=`python --version 2>&1`
  if [[ $PYTHONVERSION != *2.7* ]]; then
    echo "Python version 2.7 is required to install pty.js. Please install python 2.7 and try again."
    exit 100
  fi

  $NPM install node-gyp
  PATH=$C9_DIR/node_modules/.bin:$PATH
  $NPM install pty.js@0.2.3
  
  HASPTY=`"$C9_DIR/node/bin/node" -e "console.log(require('pty.js'))" | grep createTerminal | wc -l`
  if [ $HASPTY -ne 1 ]; then
    echo "Unknown exception installing pty.js"
    echo `"$C9_DIR/node/bin/node" -e "console.log(require('pty.js'))"`
    exit 100
  fi
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
