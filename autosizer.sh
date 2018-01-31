#!/bin/bash -e
# Automatic Image file resizer
# Written by SirLagz
# https://github.com/SirLagz/RaspberryPi-ImgAutoSizer
# set -x
strImgFile=$1
extraSpaceMB=$2
binDir=$(dirname $0)

if [[ ! $(whoami) =~ "root" ]]; then
echo ""
echo "**********************************"
echo "*** This should be run as root ***"
echo "**********************************"
echo ""
exit
fi

if [[ -z $1 ]]; then
echo "Usage: ./autosizer.sh <Image File> [<extra space in MB>]"
exit
fi

if [[ -z $2 ]]; then
extraSpaceMB=4
fi

if [[ ! -e $1 || ! ( $(file $1) =~ "MBR" || $(file $1) =~ "x86" ) ]]; then
echo "Error : Not an image file, or file doesn't exist"
exit
fi

# Determine the offset of filesystems in the image
partinfo=`parted -s -m $1 unit B print`
bootpartstart=`echo "$partinfo" | grep fat32 | head -1 | awk -F: ' { print substr($2,0,length($2)-1) } '`
rootpartstart=`echo "$partinfo" | grep ext4 | awk -F: ' { print substr($2,0,length($2)-1) } '`

# Mount the root filesystem via loopback
loopback=`losetup -f --show -o $rootpartstart $1`
e2fsck -f $loopback

# Calculate the new size of the root filesystem
minsize=`resize2fs -P $loopback | awk -F': ' ' { print $2 } '`
blocksize=$(dumpe2fs -h $loopback | grep 'Block size' | awk -F': ' ' { print $2 }')
blocksize=${blocksize// /}
let minsize=$minsize+$extraSpaceMB*1048576/$blocksize

# Resize the root filesystem
resize2fs -p $loopback $minsize
sync

# If there is a script to modify the root filesystem, run it 
if [ -x $binDir/update_root.sh ]
then
    echo "Patching root filesystem via update_root.sh"
    mkdir -p /tmp/mnt$$
    mount $loopback /tmp/mnt$$
    $binDir/update_root.sh /tmp/mnt$$
    sync
    umount $loopback
fi

# Remove the loopback mount
losetup -d $loopback

# If there is a script to modify the boot filesystem, run it
if [ -x $binDir/update_boot.sh ]
then
    echo "Patching boot filesystem via update_boot.sh"
    mkdir -p /tmp/mnt$$
    loopback=`losetup -f --show -o $bootpartstart $1`
    mount $loopback /tmp/mnt$$
    $binDir/update_boot.sh /tmp/mnt$$
    sync
    umount $loopback
    losetup -d $loopback
fi    

# Repair the partition table in the master boot record
let partnewsize=$minsize*$blocksize
let newpartend=$rootpartstart+$partnewsize
part1=`parted -s $1 rm 2`
part2=`parted -s $1 unit B mkpart primary $rootpartstart $newpartend`
endresult=`parted -s -m $1 unit B print free | tail -1 | awk -F: ' { print substr($2,0,length($2)-1) } '`

# Truncate the image after the end of all filesystems
truncate -s $endresult $1
