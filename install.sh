#!/bin/bash -ex

has() {
  type "$1" > /dev/null 2>&1
  return $?
}


if has "curl"; then
  DOWNLOAD="curl -sSOL"
elif has "wget"; then
  DOWNLOAD="wget -nc"
else
  echo "You need curl or wget to proceed" >&2;
exit 1
fi

C9_DIR=$HOME/.c9
NPM=$C9_DIR/node/bin/npm
NODE=$C9_DIR/node/bin/node

start() {
  if [ $# -lt 1 ]; then
    start base
    return
  fi
  
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
      echo "!tmux - TMUX"
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
      cd $HOME
      mkdir -p .c9/bin
      mkdir -p .c9/node_modules
      cd .c9
    
      # install packages
      while [ $# -ne 0 ]
      do
        eval ${1} $os $arch
        shift
      done
      
      # finalize
      pushd $C9_DIR/node_modules/.bin
      for FILE in $C9_DIR/node_modules/.bin/* 
      do
          perl -i -p -e 's/#!\/usr\/bin\/env node/#!'${NODE//\//\\\/}'/' $(readlink $FILE)
      done
      popd
      
      echo 1 > $HOME/.c9/installed
      echo :Done.
    ;;
    
    "base" )
      echo "Installing base packages. Use --help for more options"
      start install node tmux nak ptyjs vfsextend
    ;;
    
    * )
      start base
    ;;
  esac
}

# NodeJS

node(){
  NODE_VERSION=v0.10.23
  
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
  echo "## Configuring Libevent"
  ./configure --prefix="$C9_DIR/local"
  echo "## Compiling Libevent"
  make
  echo "## Installing libevent"
  make install
 
  cd "$C9_DIR"
  tar xzvf ncurses-5.9.tar.gz
  rm ncurses-5.9.tar.gz
  cd ncurses-5.9
  echo "## Configuring Ncurses"
  ./configure --prefix="$C9_DIR/local"
  echo "## Compiling Ncurses"
  make
  echo "## Installing Ncurses"
  make install
 
  cd "$C9_DIR"
  tar zxvf tmux-1.6.tar.gz
  rm tmux-1.6.tar.gz
  cd tmux-1.6
  echo "## Configuring Tmux"
  ./configure CFLAGS="-I$C9_DIR/local/include -I$C9_DIR/local/include/ncurses" CPPFLAGS="-I$C9_DIR/local/include -I$C9_DIR/local/include/ncurses" LDFLAGS="-static-libgcc -L$C9_DIR/local/lib" LIBEVENT_CFLAGS="-I$C9_DIR/local/include" LIBEVENT_LIBS="-static -L$C9_DIR/local/lib -levent" LIBS="-L$C9_DIR/local/lib/ncurses -lncurses" --prefix="$C9_DIR/local"
  echo "## Compiling Tmux"
  make
  echo "## Installing Tmux"
  make install
}

tmux(){
  echo :Installing TMUX
  mkdir -p "$C9_DIR/bin"

  # Max os x
  if [ $os = "darwin" ]; then
    if ! has "brew"; then
      ruby -e "$($DOWNLOAD https://raw.github.com/mxcl/homebrew/go/install)"
    fi
    brew install tmux > /dev/null
    ln -sf $(which tmux) ~/.c9/bin/tmux

  # Linux
  else
    ln -sf $(which tmux) ~/.c9/bin/tmux
    echo "########## Downloading deps ###########"
    $DOWNLOAD https://raw.github.com/c9/install/install-tmux/packages/tmux/libevent-1.4.14b-stable.tar.gz
    $DOWNLOAD https://raw.github.com/c9/install/install-tmux/packages/tmux/ncurses-5.9.tar.gz
    $DOWNLOAD https://raw.github.com/c9/install/install-tmux/packages/tmux/tmux-1.6.tar.gz
    compile_tmux
    ln -sf "$C9_DIR"/local/bin/tmux "$C9_DIR"/bin/tmux
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
  $NPM install nak
}

ptyjs(){
  echo :Installing pty.js
  $NPM install pty.js
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
