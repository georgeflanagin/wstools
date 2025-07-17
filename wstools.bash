###
# Set the history time format
###
###
# This is the place for the very few aliases.
###
alias vi=vim
###
# There are many workstations, and they are down more often
# than computers in the rack. Let's not wait forever.
###
alias ssh="ssh -o ConnectTimeout=5 "
alias scp="scp -o ConnectTimeout=5 "

export LS_COLORS=$LS_COLORS:'di=0;35:'
export PROMPT_COLOR=$YELLOW
export HISTTIMEFORMAT="%y/%m/%d %T "
HOSTNAME=`hostname -s`
# We are only interested in users who have a $HOME directory.
export all_users=$(ls -1d /home/* | sed 's!/home/!!g' | tr '\n' ' ')
export all_nases="141.166.223.243 141.166.186.35 141.166.222.28"

function userexists
{
    if [[ $# -ne 1 ]]; then
        echo "Usage: userexists <username>" >&2
        return 2
    fi

    local user="$1"

    if ! getent passwd "$user" > /dev/null; then
        echo "User '$user' does not exist"
        false
        return
    fi

    if grep -q "^$user:" /etc/passwd; then
        echo "User '$user' exists (local)"
    else
        echo "User '$user' exists (LDAP)"
    fi

    true
}

function groupexists
{
    if [[ $# -ne 1 ]]; then
        echo "Usage: groupexists <groupname>" >&2
        return 2
    fi

    if getent group "$1" > /dev/null; then
        if grep -q "^$1:" /etc/group; then
            echo "Group '$1' exists (local)"
        else
            echo "Group '$1' exists (remote, e.g. LDAP)"
        fi
        true

    else
        echo "Group '$1' does not exist"
        false
    fi
}

function adduserkey
{
    if [ -z "$1" ]; then
        cat<<EOF
    Usage: adduserkey {user} {keyfile}

    This will append the contents of keyfile to the
    .ssh/authorized_keys file of the user. It will
    create the user using the default profile if the
    user does not exist.
EOF
    fi

    if [ $(id -u) -ne 0 ]; then
        echo "addkey must be run as root."
        return
    fi

    user="$1"
    keyfile="$2"
    sshdir="/home/$user/.ssh"
    authkeys="$sshdir/authorized_keys"

    if [ ! userexists "$user" ]; then
        useradd -m "$user"
        echo "User $user added."
    else
        echo "User $user exists."
    fi

    if [ ! -d "/home/$user/.ssh" ]; then
        echo "Creating ssh directory."
        mkdir -p "$sshdir"
        chmod 700 "$sshdir"
        touch "$authkeys"
        chmod 600 "$authkeys"
        chown -R "$user" "$sshdir"
    fi

    if [ -e "$keyfile" ]; then
        cat "$keyfile" >> "$authkeys"
        echo "$keyfile appened to $authkeys"
    else
        "$keyfile not found"
    fi
}

function list_disks
{
    echo '---------------------------------------------'
    echo $(hostname)
    lsblk | grep "^sd. " | grep -v run/media
    echo '============================================='
}

function all_users_to_users
{
    for u in $all_users; do
        all_users_to_group users
    done
}

function all_users_to_group
{
    if [ -z "$1" ]; then
        echo "Usage all_users_to_group {groupname}"
        return
    fi

    for u in $all_users; do
        echo "Adding $u to $1"
        sudo usermod -a -G "$1" "$u"
    done
}

function remount_all
{
    sudo mount -v -a -t nfs -o remount | grep -v ignored | grep -v grep
    result=$?
    if (( $result & 1 )); then
        echo "Bad permissions or invocation"
    fi
    if (( $result & 2 )); then
        echo "Hard error: out of memory, cannot fork, etc."
    fi
    if (( $result & 4 )); then
        echo "Internal mounting error."
    fi
    if (( $result & 8 )); then
        echo "You interrupted the process. Incomplete."
    fi
    if (( $result & 16 )); then
        echo "Could not get a write lock on /etc/mtab"
    fi
    if (( $result & 32 )); then
        echo "Total failure."
    fi
    if (( $result & 64 )); then
        echo "At least one mount succeeded."
    else
        echo "Success!"
    fi
}

export my_computers="aamy adam alexis boyi camryn cooper evan hamilton irene2 josh justin kevin khanh mayer michael sarah thais "
export all_computers="$my_computers"

# echo '$my_computers' is set to "$my_computers"
# echo '$all_users' is set to "$all_users"
export  LY="\[\033[1;33m\]"
export  NO_COLOR="\[\e[0m\]"

function myconfig
{
    r=$(head -2 /etc/os-release | tr '\n' ' ' | sed 's/ $//' | sed 's/NAME=//' | sed 's/ VERSION=/, version /')
    g=$(lspci | grep VGA | grep NVIDIA | grep -v T400 | sed 's/.*NVIDIA/NVIDIA/' | tr '\n' '. ')
    b="$(who -b | sed 's/ *system boot  //')."
    h=$(hostname -s)
    mem=$(head -1 /proc/meminfo | sed 's/MemTotal: *//')
    cores=$(cat /proc/cpuinfo | grep -c siblings)
    cpu=$(grep "model name" /proc/cpuinfo | head -1 | sed 's/^.*: //')
    discs=$(lsblk | grep "^s.*disk" | awk '{print $1 " -> " $4}' | tr '\n' ',')

    s1="This computer is $h. It was last booted on $b"
    s2="The OS is $r."
    s3="The CPU is an $cpu with $cores cores and $mem of memory."
    s4="The disks are $discs and"
    if [ -z "$g" ]; then
        s5="this computer has no GPU."
        s6=""
    else
        s5="this computer has (this|these) GPU[s]: $g"
        s6="$(nvidia-smi --query-gpu=memory.total,memory.used,power.draw,temperature.gpu --format=csv,noheader)"
    fi

    eyes="bdgpstwy"
    num_eyes=${#eyes}
    idx=$((RANDOM % num_eyes))
    e=${eyes:$idx:1}

    cowsay -W 55 "-$e" "$s1  $s2  $s3  $s4 $s5"
    if [ ! -z "$s6" ]; then
        echo ""
        echo " GPU INFO "
        echo "$s6"
    fi

}


function apc
{
    sudo systemctl restart apcupsd
    if [ ! $? ]; then
        echo "apcupsd not found"
        return
    fi
    sleep 1
    sudo systemctl status apcupsd | tee | grep -q "running"
    if [ ! $? ]; then
        echo "apcupsd is not running."
        sudo journalctl -xe
        return
    fi
    echo "apcupsd is running."
    sudo apcaccess status
}

# hecho is echo with a timestamp, and a check to see
# if anything at all should be printed.
unalias hecho 2>/dev/null
function hecho
{
    if [[ ${verbose:-"unset"} == "unset" ]]; then
        return
    else
        echo "$(hostname) :: $(date +%D-%H:%M:%S) :: $@"
    fi
}

###
# Generate a report on disc health.
###
unalias checkdiscs 2>/dev/null
function checkdiscs
{
    drives=$(ls -1 /dev/sd?)
    sudo touch "$HOSTNAME.disc.report.txt"
    sudo rm -f *.disc.report.txt*
    for drive in $drives; do
        sudo smartctl --format=brief --info --attributes $drive >> "$HOSTNAME.disc.report.txt" 2>/dev/null
    done
}


###
# copy the /root/.cshrc file to all users on
# on the computer who have a $HOME.
###
unalias update_cshrc 2>/dev/null
function update_cshrc
{
    export all_users=$(echo $(ls -1d /home/*) | sed 's!/home/!!g')
    for u in $all_users; do
        echo "Updating $u"
        sudo cp -f ~/.cshrc "/home/$u" 2>/dev/null
        sudo chown $u /home/$u/.cshrc 2>/dev/null
    done
}


function update_bashrc
{
    export all_users=$(echo $(ls -1d /home/*) | sed 's!/home/!!g')
    for u in $all_users; do
        echo "Updating $u"
        sudo command cp -f ~/bashrc "/home/$u/.bashrc" 2>/dev/null
        sudo command chown "$u" "/home/$u/.bashrc" 2>/dev/null
    done
}

function update_bash_profile
{
    export all_users=$(echo $(ls -1d /home/*) | sed 's!/home/!!g')
    for u in $all_users; do
        echo "Update bash_profile for $u"
        sudo command cp -f /etc/skel/.bash_profile "/home/$u/.bash_profile" 2>/dev/null
        sudo command chown "$u" "/home/$u/.bash_profile" 2>/dev/null
    done
}


function update_bashprofile
{
    echo "Updating $1"
    sudo command cp -f ~/bash_profile "/home/$1/.bash_profile" 2>/dev/null
    sudo command chown "$u" "/home/$1/.bash_profile" 2>/dev/null
}

function reset_gpu_driver
{
    echo "Stopping the graphic display manager (GDM)"
    sudo systemctl stop gdm
    if [ ! $? ]; then
        echo "GDM not stopped."
        return
    fi
    echo "GDM stopped."
    cd
    echo "Resetting the NVIDIA driver."
    sudo ./NVIDIA-Linux*
    echo "Starting the GDM."
    sudo systemctl start gdm
    if [ ! $? ]; then
        echo "GDM did not start."
        return
    fi
    echo "Waiting 5 seconds to display GDM status."
    sudo isrunning gdm
}

###
# Very simple: run the same command on all computers. Note
# the loading of wstools so that its commands are also
# available in this mode.
###
unalias on_all_computers 2>/dev/null
function on_all_computers
{
    if [ -z $1 ]; then
        echo 'Usage: on_all_computers "command"'
        return
    fi


    for host in $my_computers; do
        if [ $host != $(hostname -s) ]; then
            echo " "
            echo "-------------------------"
            echo "*****   $host"
            ssh root@$host "source ~/wstools.bash && $1"
        fi
    done
    echo "Done."
}

function on_all_nases
{
    if [ -z $1 ]; then
        echo 'Usage: on_all_nases "command"'
        return
    fi

    for host in $all_nases; do
        ssh root@$host "$1"
    done
}

function weather
{
    curl wttr.in
}

###
# push a file out to all computers. Just a files spec,
# not a directory tree. Use rsync for that.
###
unalias to_all_computers 2>/dev/null
function to_all_computers
{
    if [ -z $1 ]; then
        echo "Usage: to_all_computers {file-to-copy}"
        echo " NOTE: the filename must be fully qualified (name starts with /),"
        echo "       and it will be placed in the same location on the destination"
        echo "       computer as it is on the source computer."
        return
    fi

    for host in $my_computers; do
        echo $host
        scp "$1" "root@$host:$1"
    done
}


unalias copy2ws 2>/dev/null
function copy2ws
{
    if [ -z $1 ]; then
        echo "Usage: copy2ws {dir-to-sync} [ workstation [workstation] .. ]"
        echo ' Syncs a directory to all the computers named in $my_computers'
        echo " if no computers are named in the command. Otherwise, the sync"
        echo " is only to the named computers."
        echo " "
        echo " NOTE 1: Builds the directory at the destination if required."
        echo " NOTE 2: Unlike using rsync directly, you need not worry about"
        echo "         the trailing slash in the directory name."
        echo " "
        return
    fi

    dir_to_sync="$1"

    if [ -z $2 ]; then
        these_computers="$my_computers"
    else
        shift
        these_computers="$@"
    fi

    for h in $these_computers; do
        echo $h
        if [ $(hostname -s) != $h ]; then
            rsync --timeout=3 -av "$dir_to_sync/" "root@$h:$dir_to_sync"
            if [ ! $? ]; then
                echo "$h could not be reached for sync-ing"
            else
                echo "$h:$1 updated."
            fi
        fi
    done
}

unalias syncws 2>/dev/null
function syncws
{
    if [ -z $1 ]; then
        echo "Usage: syncws {dir-to-sync} [ workstation [workstation] .. ]"
        echo ' Syncs a directory to all the computers named in $my_computers'
        echo " if no computers are named in the command. Otherwise, the sync"
        echo " is only to the named computers."
        echo " "
        echo " NOTE 1: Builds the directory at the destination if required."
        echo " NOTE 2: Unlike using rsync directly, you need not worry about"
        echo "         the trailing slash in the directory name."
        echo " "
        return
    fi

    dir_to_sync="$1"

    if [ -z $2 ]; then
        these_computers="$my_computers"
    else
        shift
        these_computers="$@"
    fi

    for h in $these_computers; do
        echo $h
        if [ $(hostname -s) != $h ]; then
            rsync --timeout=3 -av --delete "$dir_to_sync/" "root@$h:$dir_to_sync"
            if [ ! $? ]; then
                echo "$h could not be reached for sync-ing"
            else
                echo "$h:$1 updated."
            fi
        fi
    done
}

###
# This function creates a new user on Linux 6, 7, or 8, as
# well as a /home directory for the user. The home directory
# is appropriately provisioned.
###
unalias newuser 2>/dev/null
function newuser
{
    if [ -z $1 ]; then
        echo "Usage: newuser {netid}"
        return
    fi

    newuser="$1"
    newuserid=$(id $newuser 2>/dev/null)

    # add the user and send all output to the bitbucket.

    if [ -z "$newuserid" ]; then
        echo "$newuser is not in LDAP, or is expired."
        return
    else
        ###
        # The useradd command's request for /bin/csh will not have
        # an effect in the current UR environment. However, we might
        # make changes, and this will slightly raise the chances
        # of continuing correct operation.
        ###
        echo "User $newuser found in LDAP with id $newuserid"
        sudo useradd -m $newuser -u $id >/dev/null 2>&1
    fi

    if [ -d "/home/$newuser" ]; then
        # This would happen when we are re-activating a user.
        hecho "$newuser has a pre-existing home directory."
    else
        # Create the home directory if it does not exist. The -p
        # option prevents there being an error if the directory
        # is already present.
        mkdir -p /home/$newuser
        # and give the user a .cshrc file
        cp -f /root/.cshrc /home/$newuser
        sudo chown $newuser /home/$newuser/.cshrc

        # and give the user a .bashrc file
        cp -f /root/bashrc /home/$newuser/.bashrc
        cp -f /root/bash_profile /home/$newuser/.bash_profile
        sudo chown $newuser /home/$newuser/.bashrc
        sudo chown $newuser /home/$newuser/.bash_profile

    fi

    # This will fix a problem with reactivating users.
    hecho "Resetting owner of any existing files in /home/$newuser"
    sudo chown -R $newuser:users /home/$newuser

    # and add group read/execute with the setgid bit on.
    hecho "Setting gid bit on /home/$newuser"
    sudo chmod 2755 /home/$newuser

    sudo usermod -a -G users $newuser
    sudo usermod -a -G nogroup $newuser

}

function estimate_xfs_files
{
    sudo xfs_db -c 'stat' "$(df --output=source "$1" | tail -1)" | awk '/icount/ {total=$3} /ifree/ {free=$3} END {printf "Approximate file count on %s: %d\n", "'"$1"'", total-free}';
}


function freshen_login_files
{
    newuser="$1"
    cp -f /root/.cshrc /home/$newuser
    chown $newuser /home/$newuser/.cshrc

    cp -f /root/bashrc /home/$newuser/.bashrc
    chown $newuser /home/$newuser/.bashrc
}

###
# Create several users by calling newuser in a loop.
###
unalias newusers 2>/dev/null
function newusers
{
    if [ -z $1 ]; then
        echo "Usage newusers {netid} [netid [netid .. ]]"
        return
    fi
    for u in $@; do
        newuser $u
    done
}


###
# Create several users on another computer.
###
unalias newusers_remote 2>/dev/null
function newusers_remote
{
    if [ -z $2 ]; then
        echo "Usage newusers_remote {host} {netid} [ netid [ netid .. ]]"
        echo " If the {host} is 'all', then the command will be executed"
        echo ' on each host defined in $my_computers'
        return
    fi

    host=$1
    shift
    if [ $host != "all" ]; then
        ssh root@$host "source ~/wstools.bash && newusers $@"
    else
        for host in $my_computers; do
            echo "Adding users to $host."
            if [ $host == $(hostname) ]; then
                newusers $@
            else
                ssh root@$host "source ~/wstools.bash && newusers $@"
            fi
        done
    fi
}


unalias loginall 2>/dev/null
function loginall
{
    for host in $my_computers; do
        ssh "root@$host"
    done
}

unalias perms 2>/dev/null
function perms
{
    if [ -z $1 ]; then
        echo "Usage: perms {file-or-directory-name} "
        echo " Shows the permissions for the argument, and all the containing dirs."
        return
    fi

    sudo namei -l $(readlink -f $1)
}

unalias hg 2>/dev/null
function hg
{
    if [ -z $1 ]; then
        echo "Usage: hg {something} "
        echo "  finds 'something' in your history, and only prints those lines."
        return
    fi

    history | grep "$1"
}

unalias h 2>/dev/null
function h
{
    if [ -z $1 ]; then
        echo "Usage: ... just a shortcut for history."
        return
    fi

    history
}

unalias prompter 2>/dev/null
trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
function prompter
{
  if [[ $? -eq 126 || $? -eq 127 ]]; then
    cd $previous_command
  fi

  export colwidth=$(tput cols)
  export pwdtext=`pwd`
  export pwdlen=${#pwdtext}
  export promptsize=$((${#HOSTNAME} + ${#USER} + ${#pwdtext}))
  if [ $((pwdlen + 20)) -gt $((colwidth / 2)) ]; then
    pwdtext=${pwdtext:0:7}"..."
    export promptsize=$((${#HOSTNAME} + ${#USER} + ${#pwdtext}))
  fi

  export howfardown=$(echo `pwd` | sed 's/[^/]//g')

  if [ $((promptsize * 5)) -gt $((colwidth))  ]; then
    PS1="$PROMPT_COLOR\n$PROMPT_COLOR[$HOSTNAME($USER):$howfardown\W]:\e[m "
  else
    PS1="$PROMPT_COLOR\n$PROMPT_COLOR[$HOSTNAME($USER):\w]:\e[m "
  fi
}

PROMPT_COMMAND="prompter"


unalias reassign 2>/dev/null
function reassign
{
    if [ -z $1 ]; then
        echo "Usage: reassign {symlink} {something-else}"
        echo "  checks that symlink is already a link, and then assigns it to something-else."
        return
    fi

  if [ -z $1 ]; then
   read -p "Give the name of the link: " linkname
  fi
  if [ -z $2 ]; then
   read -p "Give the name of the new target: " target
  fi

  # Make sure the thing we are removing is a sym link.
  if [ ! -L $1 ]; then
   echo "Sorry. $1 is not a symbolic link"

  # attempt to create the file if it does not exist.
  else
   if [ ! -e $2 ]; then
     touch $2
     # mention the fact that we had to create it.
     echo "Created empty file named $2"
   fi

   # make sure the target is present.
   if [ ! -e $2 ]; then
     echo "Unable to find or create $2."
   else
     # nuke the link
     rm -f $1
     # link
     ln -s $2 $1
     # confirm by showing.
     ls -l $1
   fi
  fi
}

unalias mcd 2>/dev/null
function mcd
{
    if [ -z $1 ]; then
        echo "Usage: mcd {dir-name}"
        echo "  creates directory if it does not exist, and cd-s to it."
        return
    fi

    mkdir -p "$1"
    cd "$1"
}

unalias cd 2>/dev/null
function cd
{
    if [ -z $1 ]; then
        command pushd ~ >/dev/null
    elif [ -L $1 ]; then
        d=`readlink $1`
        command pushd "$d" 2>&1 >/dev/null
    else
        command pushd "$1" 2>&1 >/dev/null
    fi
}

unalias cdd 2>/dev/null
function cdd
{
    if [ -z $1 ]; then
        echo "Usage: cdd {dir-name}"
        echo " Finds dir-name beneath the current directory, and cd-s to it."
        return
    fi

    d_name=$(find . -type d -name "$1" 2>&1 | grep -v Permission | head -1)
    if [ -z $d_name ]; then
        d_name=$(find ~ -type d -name "$1" 2>&1 | grep -v Permission | head -1)
    fi
    if [ -z $d_name ]; then
        echo "no directory here named $1"
        return
    fi
    cd "$d_name"
}

unalias cdshow 2>/dev/null
function cdshow
{
    if [ -z $1 ]; then
        echo "Usage: cdshow"
        echo " Shows your cd history in case you get lost."
        return
    fi

    dirs -v -l
}

unalias up 2>/dev/null
function up
{
    levels=${1:-1}
    while [ $levels -gt 0 ]; do
        cd ..
        levels=$(( --levels ))
    done
}

unalias back 2>/dev/null
function back
{
    levels=${1:-1}
    while [ $levels -gt 0 ]; do
        popd 2>&1 > /dev/null
        levels=$(( --levels ))
    done
}


# >>>>>>>>>>>>>>>>>>>>>>>>>
# sockets, pipes, tunnels
# >>>>>>>>>>>>>>>>>>>>>>>>>

unalias showsockets 2>/dev/null
function showsockets
{
    sudo ss -t | grep -v 127.0.0.1
}

unalias showpipes 2>/dev/null
function showpipes
{
    sudo lsof | head -1
    sudo lsof | grep FIFO | grep -v grep | grep -v lsof
}

unalias tunnel 2>/dev/null
function tunnel
{
    if [ -z $4 ]; then
        echo "Usage: tunnel localport target targetport tunnelhost"
        echo " builds a tunnel connecting the current computer to another one."
        return
    fi

    ssh -f -N -L "$1:$2:$3 $4"
}

unalias fixperms 2>/dev/null
function fixperms
{
    sudo chmod g+s $(pwd)
    sudo chmod -R go-rwx *
    sudo chmod -R -x+X *
}

unalias hogs 2>/dev/null
function hogs
{
    d=${1:-$(pwd)}
    sudo nice command find $d -size +100M -exec ls -l {} \;
}

unalias be 2>/dev/null
function be
{
    sudo su - $1
}

# >>>>>>>>>>>>>>>>>>
# PATH stuff
# >>>>>>>>>>>>>>>>>>
function addhere
{
  export PATH=$PATH:`pwd`
  echo PATH is now $PATH
}

function delhere
{
  HERE=:`pwd`
  export PATH=$(echo $PATH | sed "s/$HERE//")
  echo PATH is now $PATH
}

function pyaddhere
{
    export PYTHONPATH="$PYTHONPATH":`pwd`
    echo PYTHONPATH="$PYTHONPATH"
}

function pydelhere
{
    HERE=:`pwd`
    export PYTHONPATH=$(echo $PYTHONPATH | sed "s/$HERE//")
    echo PYTHONPATH="$PYTHONPATH"
}

function libaddhere
{
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$PWD"
    echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
}

function treee
{
    sudo tree -D -F -p ${1-$PWD}
}

function libdelhere
{
    HERE=:`pwd`
    export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed "s/$HERE//")
    echo LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
}

export config=~/.ssh/config

function whoisin
{
    # Shell function to show users in a named group
    # and the date of the last activity.
    #
    #  Usage: whoisin [group]
    out=/tmp/whoisin
    rm -f $out
    touch $out
    export g=${1:-wheel}
    echo "Looking at users in group $g"
    echo " "
    export members=`getent group $g`
    IFS=',' read -ra MEMBERS <<< "$members"
    for member in "${MEMBERS[@]}" ; do
        if [ -d "/home/$member" ]; then
            line=`date -r "/home/$member" +'%F %T'`
            echo $member $line >> $out
        fi
    done
    cat $out | sort
    rm -f $out
}

function isrunning
{
    if [ -z $1 ]; then
        echo "Usage: isrunning {something} "
        echo " something can be a program, a user, or a pid."
        echo "Prints the user who is running the program, the pid, and ppid."
        return
    fi

    ps -ef | sed -n "1p; /$1/p;" | grep -v 'sed -n'
}

function isinstalled
{
    if [ -z $1 ]; then
        echo "Usage: isinstalled {something}"
        echo "  determines if something is installed, and prints its version."
        return
    fi

    rpm -qa | grep "$1"
}

function latest
{
    vim $(ls -1t | head -1)
}

function blockip
{
    if [ -z $1 ]; then
        echo "Usage: blockip {host}"
        echo " NOTE: The change will be permanent and take effect immediately."
        return
    fi

    sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$1' reject"
    sudo firewall-cmd --reload
}

function provide_cshrc
{
    for u in $@; do
        cp -f .cshrc /home/$u
    done
}

function wstools
{
    if [ -z $1 ]; then
        echo "Usage: wstools {update|push}"
        return
    fi

    case $1 in
        update)
	    cd ~/wstools
            source wstools.bash
            tar -cf wstools.tar users *config \
                dailybackup.sh wstools.bash git.bash \
                .cshrc bashrc bash.sh hosts install_cuda.sh \
                bash_profile *.conf usersetup.sh \
                simple_cuda_*txt apcupsd.conf upsdetect.sh \
                usersetup.sh
            ls -l wstools.tar
            echo " "
            echo "Contents of wstools.tar:"
            echo " "
            tar -tf wstools.tar
            ;;

        push)
            if [ -z $2 ]; then
                echo "Usage: wstools push {hostname}"
                echo " If {hostname} is 'all', then the push will"
                echo ' go to all hosts in $my_computers, i.e., these:'
                echo $my_computers
                return
            fi
	    cd ~/wstools

            if [ $2 != "all" ]; then
                scp wstools.tar root@$2:~/wstools.tar
                ssh root@$2 "tar -xf wstools.tar"
            else
                for host in $my_computers; do
                    hecho "moving wstools.tar to $host"
                    scp wstools.tar root@$host:~/wstools.tar
                    ssh root@$host "tar -xf wstools.tar"
                done

            fi

            ;;

        *)
            echo "$1 not [yet?] implemented."
            ;;

    esac
}

myconfig
