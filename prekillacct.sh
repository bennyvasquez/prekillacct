# !/bin/bash
# prekillacct.sh
# V0.0 May 2015 
# by bennyvasquez
# benny@encylia.com
#==========================================================================
# This script will package an account, move the pkgacct to /backup/suspended-acct-backups. Intended to be hooked as part of cPanel's account termination process.
# Adapted from http://whmscripts.net/wp-content/uploads/downloads/2010/07/prekillacct.txt
#
# Pkgacct
#  We also copy this stuff to the user's homedir, prior to the backup:
#   - zones (so we have the IP)
#   - local vs remotedomains status
#  
#==========================================================================
# To do:
# add helptext
# Add error checking/failing
#=================
ME=${0##*/}
backupdir=/backup/suspended-acct-backups

if [ ! -f "/usr/local/cpanel/cpanel" ]; then
	echo "This script only works on cPanel servers"
	exit 
fi

exec > /tmp/prekillacct.log 2>&1

if [[ ! -d "$backupdir"  && ! -L "$backupdir" ]]; then 
	echo 'Backup dir does not exist, creating backup directory'
	mkdir -p $backupdir -v
fi

#====================================
#   Parse argument pairs
#====================================
while [ $# != 0 ]
do
    eval cp_$1="$2"
    shift 2
done

eval homedir='~'$cp_user

#====================================
#  Add external files to the cpmove file:
#    - Backup a copy of the zone files in ~/.named_hostname
#    - Backup local/remote domain configuration to 
#====================================
hostname=$(hostname)
namedir=$homedir/.named_$hostname
test ! -d $namedir && mkdir $namedir
grep ": $cp_user\$" /etc/userdomains |
  while IFS=":$IFS" read domain u1
  do
    echo backing up $domain zone ...
    # keep them owned by root
    cp /var/named/${domain}.db $namedir
    # backup MX hosting for domain as well ...
    grep "^$domain$" /etc/localdomains /etc/remotedomains >> $namedir/.mxhost
  done
  # adding this in to correct file permissions, else pkgacct won't be able to access these files.
  chown $cp_user.$cp_user $namedir
  chown $cp_user.$cp_user $namedir/*

#====================================
#   Backup the account without overwriting the existing backup, if the existing backup is more than 24 hours old.
#====================================
filename=$backupdir/cpmove-${cp_user}.tar.gz
if [ -f $filename ] && [ "$(find $output -mtime 0 | wc -l)" -gt 0 ]
then
    echo
    echo $ME: $cp_user: not overwriting as existing backup is less than 24 hours old
    echo
else
    /scripts/pkgacct $cp_user $backupdir
fi

exit 0
