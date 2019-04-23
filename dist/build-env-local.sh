#!/bin/bash
# This modifies things on the build servers. Things like PAR::Packer etc. versions.
# build-env-local.sh [[osx10.5] [osx10.6] | [osxen]] [[w32] [w64] | [win]] [[l32] [l64] | [linux]]

me=$(whoami)
if [ "$me" = "root" ]; then
  echo "You should be logged on as the vbox user to do this!"
  exit 1
fi

function vmon {
  VM=$(pgrep -f -- "-startvm bbf-$1")
  if [ ! -z "$VM" ]; then
    echo "Biber build farm VM already running with PID: $VM"
  else
    nohup VBoxHeadless --startvm bbf-$1 &
  fi
}

function vmoff {
  VBoxManage controlvm bbf-$1 savestate
}

# get dir of script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Things to do on each server. In an external file ignored by git
. $DIR/build-env-cmds

# Build farm OSX 64-bit intel LECAGY (10.5<version<10.13)
# ntpdate is because Vbox doesn't timesync OSX and ntp never works because the
# time difference is too great between boots
if [[ $@ =~ "osx10.6" || $@ =~ "osxen" || $@ =~ "ALL" ]]; then
  vmon osx10.6
  sleep 5
  ssh philkime@bbf-osx10.6 "sudo ntpdate ch.pool.ntp.org;$COMMANDS_OSX"
  vmoff osx10.6
fi

# Build farm OSX 64-bit intel
# ntpdate is because Vbox doesn't timesync OSX and ntp never works because the
# time difference is too great between boots
if [[ $@ =~ "osx10.12" || $@ =~ "osxen" || $@ =~ "ALL" ]]; then
  vmon osx10.12
  sleep 5
  ssh philkime@bbf-osx10.12 "sudo ntpdate ch.pool.ntp.org;$COMMANDS_OSX"
  vmoff osx10.12
fi

# Build farm WMSWIN32
# DON'T FORGET THAT installdeps WON'T WORK FOR STRAWBERRY INSIDE CYGWIN
# SO YOU HAVE TO INSTALL MODULE UPDATES MANUALLY
if [[ $@ =~ "w32" || $@ =~ "win" || $@ =~ "ALL" ]]; then
  vmon wxp32
  sleep 20
  ssh philkime@bbf-wxp32 "$COMMANDS_WINDOWS"
  vmoff wxp32
fi

# Build farm WMSWIN64
# DON'T FORGET THAT installdeps WON'T WORK FOR STRAWBERRY INSIDE CYGWIN
# SO YOU HAVE TO INSTALL MODULE UPDATES MANUALLY
if [[ $@ =~ "w64" || $@ =~ "win" || $@ =~ "ALL" ]]; then
  vmon w1064
  sleep 20
  ssh phili@bbf-w1064 "$COMMANDS_WINDOWS"
  vmoff w1064
fi

# Build farm Linux 64
if [[ $@ =~ "l64" || $@ =~ "linux" || $@ =~ "ALL" ]]; then
  vmon l64
  sleep 20
  ssh philkime@bbf-l64 "sudo ntpdate ch.pool.ntp.org;$COMMANDS_LINUX"
  vmoff l64
fi

