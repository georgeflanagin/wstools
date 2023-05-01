###
# Set the history time format 
###
export LS_COLORS=$LS_COLORS:'di=0;35:'
export PROMPT_COLOR=$YELLOW
export HISTTIMEFORMAT="%y/%m/%d %T "
HOSTNAME=`hostname`
# The next line chops off the .richmond.edu part of the hostname.
export HOSTNAME=${HOSTNAME%%.*}
# We are only interested in users who have a $HOME directory.
export all_users=$(ls -1d /home/* | sed 's!/home/!!g')

function all_users_to_users
{
    for u in $all_users; do
        sudo usermod -a -G users $u
    done
}

# On coltrane and billieholiday we do this a bit differently.
case $(hostname) in 
    coltrane|billieholiday)
    if [[ ${my_computers:-"unset"} == "unset" ]]; then
        export my_computers="adam anna boyi cooper dirac elion evan franklin hamilton irene justin marie mayer newton pople sarah thais "
    fi
    ;;

    *)
    export my_computers="adam anna boyi cooper dirac elion evan franklin hamilton irene justin marie mayer newton pople sarah thais "
    ;;
esac



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

unalias checkdiscs 2>/dev/null
###
# Generate a report on disc health.
###
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
        sudo cp -f ~/bashrc "/home/$u/.bashrc" 2>/dev/null
        sudo chown "$u" "/home/$u/.bashrc" 2>/dev/null
    done
}

function remove_starred_users
{
    cp -f /etc/passwd /etc/passwd.old
    sed -i '/:\*:/d' /etc/passwd
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
        echo "Usage: on_all_computers 'command'"
        return
    fi

    for host in $my_computers; do 
        echo $host
        ssh root@$host "source ~/wstools.bash && $1"
    done
}

###
# push a file out to all computers. Just a files spec,
# not a directory tree. Use rsync for that.
###
function to_all_computers
{
    if [ -z $1 ]; then
        echo "Usage: to_all_computers {file-to-copy}"
        return
    fi

    for host in $my_computers; do
        hecho $host
        scp "$1" "root@$host:$1"
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
        useradd $newuser -u $id -s /bin/csh >/dev/null 2>&1
        result=$?
        hecho "changing shell to csh"
        ###
        # Be cautious of adding a user twice, or changing the
        # default shell of a user who is already present.
        ###
        if grep -q $newuser /etc/passwd; then
            hecho "user already in /etc/passwd"
        else
            echo $(getent passwd $newuser) | sed 's/bash$/csh/' >> /etc/passwd
            hecho "User info appended to /etc/passwd"
        fi
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
        cp ~root/.cshrc /home/$newuser
        chown $newuser /home/$newuser/.cshrc 
    fi

    # This will fix a problem with reactivating users.
    hecho "Resetting owner of any existing files in /home/$newuser"
    chown -R $newuser:users /home/$newuser

    # and add group read/execute with the setgid bit on.
    hecho "Setting gid bit on /home/$newuser"
    chmod 2755 /home/$newuser

    usermod -a -G users $newuser

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


unalias perms 2>/dev/null
function perms
{
    if [ -z $1 ]; then
        echo "Usage: perms {file-or-directory-name} "
        echo " Shows the permissions for the argument, and all the containing dirs."
        return
    fi

    namei -l $(readlink -f $1)
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


###
# Report the basic state of readiness of a workstation.
###

export k_config="/etc/krb5.conf"
export sss_config="/etc/sssd/sssd.conf"
export sss_db="/var/lib/sss/db/sssd.ldb"


unalias has_gondor 2>/dev/null
function has_gondor
{
    sudo grep -q GONDOR "$1"
    if [ $? ]; then
        echo "$1 is setup for the UR environment."
    else
        echo "$1 is NOT setup for the UR environment."
    fi
}

unalias checkworkstation 2>/dev/null
function checkworkstation
{
    echo "checking workstation setup on $(hostname)"
    echo '#####################################'
    echo "checking Kerberos config."
    echo '#####################################'
    has_gondor $k_config
    sudo namei -l $(sudo readlink -f "$k_config")

    echo '#####################################'
    echo "checking SSSD config."
    echo '#####################################'
    has_gondor $sss_config
    sudo namei -l $(sudo readlink -f "$sss_config")

    echo '#####################################'
    echo "checking SSSDB config."
    echo '#####################################'
    sudo namei -l $(sudo readlink -f "$sss_db")

    echo "checking to see if SSSD is running."
    is_running sssd

    echo '#####################################'
    echo "Checking NVIDIA driver and installation."
    echo '#####################################'
    nvcc -V
}


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
    ss -t | grep -v 127.0.0.1
}

unalias showpipes 2>/dev/null
function showpipes
{
    lsof | head -1
    lsof | grep FIFO | grep -v grep | grep -v lsof
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
    chmod g+s $(pwd)
    chmod -R go-rwx *
    chmod -R -x+X *
}

unalias hogs 2>/dev/null
function hogs
{
    d=${1:-$(pwd)}
    find $d -size +100M -exec ls -l {} \;
}

unalias be 2>/dev/null
function be
{
    sudo -u $1 bash
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
    tree -D -F -p ${1-$PWD}
}

function libdelhere
{
    HERE=:`pwd`
    export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed "s/$HERE//")
    echo LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
}

export config=~/.ssh/config

whoisin()
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

    rpm -qa "$1"\*
}

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function latest
{
    vim $(ls -1t | head -1)
}

function blockip
{
    if [ -z $1 ]; then
        echo "Usage: blockip {host|ipaddress}"
        echo " NOTE: The change will be permanent and take effect immediately."
        return
    fi 
 
    is_ip_address=$(valid_ip "$1")
    if [ ! $(valid_ip "$1") ]; then
        info=$(host "$1")
        info=${info##* }
    else
        info="$1" 
    fi
   
    sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$info' reject"
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
            source wstools.bash
            tar -cf wstools.tar wstools.bash git.bash .cshrc .vimrc .vim/* bash.sh
            ls -l wstools.tar
            ;;

        push)
            if [ -z $2 ]; then
                echo "Usage: wstools push {hostname}"
                echo " If {hostname} is 'all', then the push will"
                echo ' go to all hosts in $my_computers.'
            fi

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
