# make sure that we can see our module files with the /opt ones
# having priority
#
source /usr/local/bin/init/bash
export MODULEPATH="/opt/modulefiles:/usr/local/ur/modulefiles"
export PATH="/usr/local/anaconda/anaconda3/bin:$PATH"
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
    module load gaussian/16
    unalias gv
    export LD_LIBRARY_PATH="/usr/local/gv6016/lib:/usr/local/gv6016/lib/MesaGL"
    /usr/local/gv6016/gview.sh
    export LD_LIBARY_PATH="$old_lib_path"
}
