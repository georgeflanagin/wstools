#!/bin/bash 
##################
# Script to assist with installation of cuda/NVIDIA drivers.
#
# Version 1.0 11 July 2023 George Flanagin -- original version.
# Version 1.1 17 July 2023 George Flanagin -- fully tested, added
#   numerous checks for exit codes, root user login, is this 
#   Linux Version 8 or 9, etc. Added step numbers, and tarted
#   up the messages.
#
# Based on "Cuda Installation Guide Linux"
#   version of 28 June 2023, by NVIDIA.
###################

if [ ! -z $1 ]; then
    case $1 in
        -h)

    esac
fi

export step=0
function echo_step
{
    sleep 1
    echo " "
    echo "##### Step $(( step++ )) #####"
    echo " "
    sleep 1
}

function confirm
{
    read -p "$1 (y/n) " yn
    if [ "$yn" == "n" ]; then
        exit 1
    fi
    true
}

function test_version
{
    if [ -z $2 ]; then
        echo "Usage: test_version version required_version"
        exit 1
    fi 
    least=$(echo -e "$1\n$2" | sort -V | head -1)
    [ "$least" == "$2" ]
}

if [ $(whoami) != 'root' ]; then
    echo "you must be root to install NVIDIA and CUDA"
    exit 1
fi


if grep -q -e '\(^VERSION="8\|^VERSION="9\)' /etc/os-release ; then
    true
else
    echo "This process will only work with Linux 8 and Linux 9"
    exit 1
fi

###
# Determines whether we are on EL8 or EL9. The expression evaluated
# below is either "8" or "9", and can be used to build repo names.
###
eight_or_nine=$(grep VERSION_ID /etc/os-release | sed 's!VERSION_ID="!!' | sed 's!\..*$!!')

clear
cat << EOF

    Welcome to the NVIDIA/CUDA installer/updater. The script will narrate its
    activities as it goes, asking you to confirm a few of the steps before
    it continues. The script has already confirmed that you have the 
    permissions necessary to execute the script, and that your version
    of Linux is supported.

    The steps are numbered, but some of them will be skipped because not
    every step is required --- it depends on the previous state of the 
    computer, what was installed, and how the installation was done. In all
    cases, the previous installations of NVIDIA/CUDA are replaced with 
    fresh ones that are compatible with this computer's setup.

    If you answer any question with some version of "no," the script will
    stop at the point you decline.

EOF

confirm "Do you want to continue? We will update the system before continuing.  "

echo_step
echo "Ensuring the installation directory exists."
mkdir -p /opt/cuda

echo_step
echo "Unmounting /usr/local if required."
if grep /usr/local /etc/fstab | grep -q nfs ; then
    echo "/usr/local is an NFS mount. Let's unmount it."
    umount /usr/local
    if [ $? ]; then 
        echo "Unmount successful."
    else
        echo "Could not unmount; cannot continue."
        exit 1
    fi
else
    echo "/usr/local is not an NFS mount. No action needed."
fi 
        
echo_step
echo "Updating system."
dnf -y update

confirm "System updated. Are you ready to continue? "

# echo_step
# if ps -ef | grep /usr/sbin/gdm | grep -v -q grep ; then
#     echo "Stopping the Graphic Display Manager (gdm)"
#     systemctl stop gdm
#     if [ $? ]; then
#         echo "gdm has stopped."
#     else
#         echo "Failed to stop gdm. Cannot continiue."
#         exit 1
#     fi 
# else
#     echo "Graphic Display Manager is not running."
# fi

echo_step
sed -i 's!^SELINUX=.*$!SELINUX=disabled!' /etc/selinux/config
if [ $? ]; then 
    echo "SELinux is now off."
else
    echo "SELinux is already off."
fi
setenforce 0

echo "Pre-installation Actions / Pages 11-14"

####################################
# 5.1
echo_step
echo "Checking for graphics cards."

update-pciids
if lspci | grep -q -i nvidia ; then
    echo "Found NVIDIA graphics card."
else
    echo "This computer does not have an NVIDIA graphics card, or"
    echo "  it does not have power."
    exit 1
fi

####################################
# 5.3

echo_step
echo "Checking the version of gcc"
gcc_version=$(gcc --version | head -1 | awk '{print $3}')
if [ ! $? ]; then
    echo "gcc is not installed."
    exit 1
fi

if test_version $gcc_version "8.0" ; then
    echo "gcc version $gcc_version found."
else
    echo "gcc is installed, but it is too old to use."
    confirm "Would you like to update it now? (It will take a minute or two.) "
    dnf -y install gcc\*
fi


####################################
# 5.4

echo_step
echo "Making sure that kernel headers and development packages"
echo "  are installed."

dnf -y install kernel-devel-$(uname -r) kernel-headers-$(uname -r)
if [ ! $? ]; then
    echo "install of kernel packages failed."
    exit 1
fi 

####################################
# 5.8

echo_step
echo "saving any previous xorg.conf file."
if [ -f "/etc/X11/xorg.conf" ]; then
    mv -f /etc/X11/xorg.conf /etc/X11/old.xorg.conf
    echo "saved to /etc/X11/old.xorg.conf"
else
    echo "no xorg.conf file found."
fi


####################################
# 5.9

echo_step
echo "We are going to remove any older installations."

###
# This section relies on the fact that the installation of either
# cuda or the video driver is done with dnf or a runfile, but 
# cannot possibly be both simultaneously. 
###


cuda_files=$(rpm -qa cuda\* | wc -l)
nvidia_files=$(rpm -qa nvidia\* | wc -l)

if (( cuda_files > 0 )); then
    echo "Found cuda files installed with dnf." 
    confirm "Do you want to remove them?"
    dnf -y remove cuda\*
    if [ ! $? ]; then
        echo "Unable to remove cuda files."
        exit 1
    fi
fi

if (( nvidia_files > 0 )); then
    echo "Found NVIDIA files installed with dnf." 
    confirm "Do you want to remove them?"
    dnf -y module remove nvidia-driver:latest-dkms
    if [ ! $? ]; then
        echo "Unable to remove NVIDIA files."
        exit 1
    fi
fi


cuda_uninstaller_exe=$(find /usr/local -name cuda-uninstaller -type f | head -1)
nvidia_uninstaller_exe=$(find /usr/bin -name nvidia-uninstall -type f | head -1)

if [ ! -z $cuda_uninstaller_exe ]; then
    echo "Running the CUDA uninstaller."
    $cuda_uninstaller_exe
    if [ ! $? ]; then
        echo "Execution of $cuda_uninstaller_exe failed."
        exit 1
    fi
fi

if [ ! -z $nvidia_uninstaller_exe ]; then
    echo "Running the NVIDIA uninstaller."
    $nvidia_uninstaller_exe
    if [ ! $? ]; then
        echo "Execution of $nvidia_uninstaller_exe failed."
        exit 1
    fi
fi

echo_step
echo "The system is clean and ready for the install."
confirm "Are you ready to continue?"

####################################
# 5.7 

echo_step
if dnf repolist | grep -q cuda | grep -q "$eight_or_nine" ; then
    echo "The cuda repo is already enabled."
else
    echo "Adding the cuda repo."
    dnf config-manager --add-repo "https://developer.download.nvidia.com/compute/cuda/repos/rhel$eight_or_nine/x86_64/cuda-rhel$eight_or_nine.repo"
fi

echo_step
if dnf repolist | grep -q epel ; then
    echo "The EPEL repo is already enabled."
else
    echo "Adding the EPEL repo."
    dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$eight_or_nine.noarch.rpm"
fi

echo_step
echo "Removing any outdated signing key."
rpm --erase gpg-pubkey-7fa2af80*
if [ $? ]; then
    echo "Outdated signing key 7fa2af80 removed."
else
    echo "Outdated signing key not present, or has already been removed."
fi


echo_step
echo "Rebuilding the package manager (dnf) database."
dnf clean expire-cache
dnf clean all

echo_step
echo "Installing the driver and dkms."
dnf -y module install nvidia-driver:latest-dkms
if [ ! $? ]; then 
    echo "The install of the nvidia-driver has failed."
    cat << EOF
        
        You will need to consult one or more of these files to determine 
        the cause[s]:

        1. journalctl 
        2. /var/log/nvidia*
EOF
    exit 1
fi 

echo "dnf install of nvidia-driver succeeded."
nvidia-smi
if [ ! $? ]; then
    echo "Do not know what happened here. The driver seems to not be running."
    exit 1
fi 

confirm "Are you ready to install CUDA?"

echo_step
echo "Installing cuda."
dnf -y install cuda-11-3
if [ ! $? ]; then 
    echo "The install of the CUDA libraries have failed."
    cat << EOF
        
        You will need to consult one or more of these files to determine 
        the cause[s]:

        1. journalctl 
        2. /var/log/nvidia*
EOF
    exit 1
fi 

echo_step
echo "For the changes to take effect, you must reboot."
confirm "Would you like to do that now? (well, after a one minute wait ....) "

shutdown -r +1

