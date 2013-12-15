#!/bin/bash -e

has() {
  type "$1" > /dev/null 2>&1
  return $?
}

# test for prereqs
if ! has "curl"; then
  echo 'Cloud9 installer needs curl to proceed.' >&2;
  exit 1
fi

NPM=$HOME/.c9/node/bin/npm
NODE=$HOME/.c9/node/bin/node

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
      for FILE in $HOME/.c9/node_modules/.bin/* 
      do
          perl -i -p -e 's/#!\/usr\/bin\/env node/#!'${NODE//\//\\\/}'/' $(readlink -f $FILE)
      done
      
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
  
  curl -sSOL http://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-$1-$2.tar.gz
  tar xvfz node-$NODE_VERSION-$1-$2.tar.gz
  mv node-$NODE_VERSION-$1-$2 node
  rm node-$NODE_VERSION-$1-$2.tar.gz
}

tmux(){
  echo :Installing TMUX

  curl -sSOL https://raw.github.com/c9/install/master/packages/tmux/tmux-$1-$2.tar.gz
  tar xvfz tmux-$1-$2.tar.gz
  rm tmux-$1-$2.tar.gz

  rm -f ~/.c9/bin/tmux
  ln -s ~/.c9/local/bin/tmux ~/.c9/bin/tmux
}

vfsextend(){
  echo :Installing VFS extend
  curl -sSOL https://raw.github.com/c9/install/master/packages/extend/c9-vfs-extend.tar.gz
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
