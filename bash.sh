# make sure that we can see our module files with the /opt ones
# having priority
#
source /usr/local/bin/init/bash
export MODULEPATH="/opt/modulefiles:/usr/local/ur/modulefiles"
export PATH="/usr/local/anaconda/anaconda3/bin:$PATH:/usr/lib64/openmpi/bin:/usr/local/molden7"
export PATH="$PATH:/opt/obabel/bin"
export path="$PATH"

alias aws=/usr/local/bin/aws
export HISTSIZE=1000
export HISTFILESIZE=1000
mkdir -p /scratch/$USER

module load ur

#module load schrodinger/13
#module load mopac
#module load qchem

# SOURCE optional software or local environment changes
#if [ -f /op/csh.cshrc ]; then
#    source /opt/csh.cshrc
#fi

function gv
{
    export old_lib_path="$LD_LIBRARY_PATH"
    module load gaussian/16c02
    unalias gv >/dev/null 2>&1
    export LD_LIBRARY_PATH="/usr/local/gv6016/lib:/usr/local/gv6016/lib/MesaGL"
    /usr/local/gv6016/gview.sh
    export LD_LIBRARY_PATH="$old_lib_path"
}

function chimerax
{
    /usr/local/chimerax/bin/ChimeraX $@
}

alias chimera=chimerax
alias ChimeraX=chimerax

source /opt/intel/oneapi/setvars.sh
export COLUMBUS=/usr/local/columbus722

function backupnow
{
    sudo /root/backupnow.sh
}

function molden
{
    export old_lib_path="$LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH="/usr/local/anaconda/anaconda3/lib:$LD_LIBRARY_PATH"
    molden
    export LD_LIBRARY_PATH="$old_lib_path"
}

weather ()
{
    curl wttr.in
}

###
# Updated myconfig.
###
function myconfig
{
    use_cow=$([[ -n "$1" ]] && echo true || echo false)

    piton=$(python3 --version)
    r=$(head -2 /etc/os-release | tr '\n' ' ' | sed 's/ $//' | sed 's/NAME=//' | sed 's/ VERSION=/, version /')
    g=$(lspci | grep NVIDIA | grep -v ' Audio ' | grep -v T400 | grep -v ' Device ' | sed 's/.*NVIDIA/NVIDIA/' | tr '\n' '\n')
    b="$(who -b | sed 's/ *system boot  //')."
    h=$(hostname -s)
    mem=$(head -1 /proc/meminfo | sed 's/MemTotal: *//' | sed 's/ kB//')
    mem=$((mem / 1048576))
    sockets=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l);
    physical_cores=$(grep "cpu cores" /proc/cpuinfo | head -1 | awk '{print $NF}')
    cores=$((physical_cores * sockets))
    threads=$(cat /proc/cpuinfo | grep -c siblings)
    cpu=$(grep "model name" /proc/cpuinfo | head -1 | sed 's/^.*: //')
    discs=$(lsblk | grep "^s.*disk" | awk '{print $1 " -> " $4}' )

    s1="This computer is $h. It was last booted on $b"
    s2="The OS is $r."
    s3="The CPU: $cpu, $sockets sockets, $cores cores, $threads threads, and $mem GB of usable memory."
    s4="The disks are:\n$discs."

    if [ -z "$g" ]; then
        s5="$h has no GPU."
        s6=""
    else
        s5="Computational GPU[s] on $h:\n$g"
        s6="$(nvidia-smi --query-gpu=memory.total,memory.used,power.draw,temperature.gpu --format=csv,noheader)"
    fi

    echo " "
    echo "----- BEGIN STATUS at $(date) -----"
    echo " "
    echo "= $s1"
    echo "= $s2"
    echo "= Running kernel is $(uname -r)"
    echo "= $s3"
    echo -e "= $s4"
    echo -e "= $s5"
    echo "= $(graphical_target_active)"
    echo "= $(gdm_session)"
    echo "= $(gui_user)"
    echo "= $piton is the default Python."
    echo "= $(logins)"
    echo " "
    echo "= CPU saturation/load:"
    w | awk -F'load average:' -v cores="$cores" '{print $2}' | xargs | awk -F', ' -v cores="$cores" '{
        printf "previous  1 minute:  %s (%.2f per core)\n", $1, $1/cores;
        printf "previous  5 minutes: %s (%.2f per core)\n", $2, $2/cores;
        printf "previous 15 minutes: %s (%.2f per core)\n", $3, $3/cores;
    }'

    if [ ! -z "$s6" ]; then
        echo " "
        echo "= $(nvidia_versions)"
        echo " "
        echo "= GPU Activity: "
        echo "  Memory, Mem Used, Power, Temp"
        echo "  $s6"
    fi
    echo " "
    echo "----- END STATUS -----"
    echo " "
}

function logins
{
    echo "These users are logged in: $(users)"
}

function graphical_target_active
{
    if systemctl is-active --quiet graphical.target; then
        echo "GUI is enabled."
    elif systemctl is-active --quiet multiuser.target; then
        echo "GUI is disabled."
    else
        echo "GUI is running, but not on a GPU."
    fi
}

function gdm_session
{
    if ps -eo comm | grep -E 'gdm-(wayland|x)-session' > /dev/null; then
        echo "GUI session is active."
    else
        echo "No GUI session is currently running on a GPU."
    fi
}

function gui_user
{
    u=$(who | grep -E "login screen" | awk '{print $1}')
    if [ -z "$u" ]; then
        echo "No one is currently logged in at the GUI"
    else
        echo "$u is logged in at the GUI"
    fi
}

function nvidia_versions
{
    nvidia-smi --version | tail -2 > /tmp/v
    if [ ! $? ]; then
        rm -f /tmp/v
        echo "No info about NVIDIA tools."
        return
    fi

    driver=$(head -1 /tmp/v | awk '{print $4}')
    cuda=$(tail -1 /tmp/v | awk '{print $4}')
    rm -f /tmp/v

    echo "NVIDIA driver version $driver, cuda version $cuda"
}
