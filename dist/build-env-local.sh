#!/bin/bash

# This modifies things on the build servers. Things like PAR::Packer etc. versions.

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

# Things to do on each server
COMMANDS_OSX="sudo cpan Module::ScanDeps"
COMMANDS_WINDOWS=""
COMMANDS_LINUX="sudo /usr/local/perl/bin/cpan Module::ScanDeps"

# Build farm OSX 64-bit intel
# ntpdate is because Vbox doesn't timesync OSX and ntp never works because the
# time difference is too great between boots
if [[ $@ =~ "osx10.6" || $@ =~ "ALL" ]]; then
  vmon osx10.6
  sleep 5
  ssh philkime@bbf-osx10.6 "sudo ntpdate ch.pool.ntp.org;$COMMANDS_OSX"
  vmoff osx10.6
fi

# Build farm OSX 32-bit intel (universal)
# ntpdate is because Vbox doesn't timesync OSX and ntp never works because the
# time difference is too great between boots
if [[ $@ =~ "osx10.5" || $@ =~ "ALL" ]]; then
  vmon osx10.5
  sleep 10
  ssh philkime@bbf-osx10.5 "sudo ntpdate ch.pool.ntp.org;$COMMANDS_OSX"
  vmoff osx10.5
fi


# Build farm WMSWIN32
# DON'T FORGET THAT installdeps WON'T WORK FOR STRAWBERRY INSIDE CYGWIN
# SO YOU HAVE TO INSTALL MODULE UPDATES MANUALLY
if [[ $@ =~ "wxp32" || $@ =~ "ALL" ]]; then
  vmon wxp32
  sleep 20
  ssh philkime@bbf-wxp32 "$COMMANDS_WINDOWS"
  vmoff wxp32
fi

# Build farm WMSWIN64
# DON'T FORGET THAT installdeps WON'T WORK FOR STRAWBERRY INSIDE CYGWIN
# SO YOU HAVE TO INSTALL MODULE UPDATES MANUALLY
if [[ $@ =~ "w1064" || $@ =~ "ALL" ]]; then
  vmon w1064
  sleep 20
  ssh phili@bbf-w1064 "$COMMANDS_WINDOWS"
  vmoff w1064
fi

# Build farm Linux 32
if [[ $@ =~ "jj32" || $@ =~ "ALL" ]]; then
  vmon jj32
  sleep 20
  ssh philkime@bbf-jj32 "sudo ntpdate ch.pool.ntp.org;$COMMANDS_LINUX"
  vmoff jj32
fi

# Build farm Linux 64
if [[ $@ =~ "jj64" || $@ =~ "ALL" ]]; then
  vmon jj64
  sleep 20
  ssh philkime@bbf-jj64 "sudo ntpdate ch.pool.ntp.org;$COMMANDS_LINUX"
  vmoff jj64
fi

