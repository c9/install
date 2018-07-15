#!/bin/bash

# Script for installing tmux on systems where you don't have root access.
# tmux will be installed in $BASE/local/bin.
# It's assumed that wget and a C/C++ compiler are installed.

# exit on error
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE=~/.c9

# create our directories
mkdir -p $BASE/local $BASE/tmux_tmp
cd $BASE/tmux_tmp

# Try to figure out the os and arch
uname="$(uname -a)"
arch="$(uname -m)"
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

# download source files for tmux, libevent, and ncurses
wget -O tmux-1.6.tar.gz http://sourceforge.net/projects/tmux/files/tmux/tmux-1.6/tmux-1.6.tar.gz/download
wget https://github.com/libevent/libevent/releases/download/release-2.1.8-stable/libevent-2.1.8-stable.tar.gz 
wget ftp://ftp.gnu.org/gnu/ncurses/ncurses-5.9.tar.gz

# extract files, configure, and compile

############
# libevent #
############
tar xvzf libevent-2.1.8-stable.tar.gz
cd libevent-2.1.8-stable
./configure --prefix=$BASE/local --disable-shared
make
make install
cd ..

############
# ncurses  #
############
tar xvzf ncurses-5.9.tar.gz
cd ncurses-5.9
./configure --prefix=$BASE/local
make
make install
cd ..

# ###########
# tmux     #
# ###########
tar xvzf tmux-1.6.tar.gz
cd tmux-1.6
if [ $os = 'darwin' ]; then
  ./configure CFLAGS="-I$BASE/local/include -I$BASE/local/include/ncurses" LDFLAGS="-static-libgcc -L$BASE/local/lib -L$BASE/local/include/ncurses -L$BASE/local/include"
else
  ./configure --enable-static CFLAGS="-I$BASE/local/include -I$BASE/local/include/ncurses" LDFLAGS="-static-libgcc -L$BASE/local/lib -L$BASE/local/include/ncurses -L$BASE/local/include"
fi
CPPFLAGS="-I$BASE/local/include -I$BASE/local/include/ncurses" LDFLAGS="-static -static-libgcc -L$BASE/local/include -L$BASE/local/include/ncurses -L$BASE/local/lib" make
cp tmux $BASE/local/bin
cd ..

# cleanup
rm -rf $BASE/tmux_tmp

# package
tar -cvzf $DIR/tmux-$os-$arch.tar.gz $BASE/local

echo "$BASE/local/bin/tmux is now available. The package can be found at $DIR/tmux-$os-$arch.tar.gz"
