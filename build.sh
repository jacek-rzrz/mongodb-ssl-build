#!/bin/bash

if [ $EUID -ne 0 ]
then
  echo "root access needed, re-running with sudo:"
  SCRIPT=$(readlink -e -- "$0")
  COMMAND="sudo $SCRIPT $@"
  echo $COMMAND
  eval $COMMAND
  exit
fi

# helper function for logging all commands being run
function run() {
  echo $@
  eval "$@ || { echo 'Exiting with error code 1'; exit 1; }"
}

function delete_link() {
  if [ -h $0 ]
  then
    run rm $0
  fi
}

MONGODB_VERSION=r2.6.7
MONGODB_SRC_DIR=mongodb_${MONGODB_VERSION}_src
MONGODB_SRV_DIR=/srv/mongodb
MONGODB_INS_DIR=$MONGODB_SRV_DIR/mongodb_${MONGODB_VERSION}_ssl
MONGODB_INS_LNK=$MONGODB_SRV_DIR/mongodb
COMPILATION_THREADS=2

echo "Preparing directories"
run rm -rf $MONGODB_SRC_DIR
for DIR in $MONGODB_SRC_DIR $MONGODB_SRV_DIR $MONGODB_INS_DIR
do
  if [ ! -d $DIR ]
  then
    run mkdir $DIR
  fi
done

echo "Installing required libraries"
run apt-get install -y build-essential libssl-dev python2.7 scons git

echo "Cloning MongoDB $MONGODB_VERSION from git"
run git clone git://github.com/mongodb/mongo.git $MONGODB_SRC_DIR
run git --git-dir=$MONGODB_SRC_DIR/.git --work-tree=$MONGODB_SRC_DIR checkout $MONGODB_VERSION

echo Compiling
run "(cd $MONGODB_SRC_DIR && scons -j $COMPILATION_THREADS --64 --ssl all)"

echo Installing
run "(cd $MONGODB_SRC_DIR && scons -j $COMPILATION_THREADS --64 --ssl --prefix=$MONGODB_INS_DIR install)"

echo Cleaning up
run rm -rf $MONGODB_SRC_DIR

echo Creating a symlink $MONGODB_INS_LNK
delete_link $MONGODB_INS_LINK
run ln -s $MONGODB_INS_DIR $MONGODB_INS_LNK

USRBIN=/usr/bin
MNGBIN=$MONGODB_INS_LNK/bin
echo Creating symlinks in $USRBIN
ls -1 $MNGBIN | while read BIN
do
  delete_link $USRBIN/$BIN
  run ln -s $MNGBIN/$BIN $USRBIN/$BIN
done

echo "All done"
