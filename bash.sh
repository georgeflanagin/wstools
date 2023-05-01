# make sure that we can see our module files with the /opt ones
# having priority
#
echo "setting modulepath, path"
export MODULEPATH="/opt/modulefiles:/usr/local/ur/modulefiles"
export PATH="/usr/local/anaconda/anaconda3/bin:$PATH"
export path="$PATH"

echo "setting history, scratch"
alias aws=/usr/local/bin/aws
export HISTSIZE=1000
export HISTFILESIZE=1000
mkdir -p /scratch/$USER

echo "loading module ur"
module load ur

#module load schrodinger/13
#module load mopac
#module load qchem

# SOURCE optional software or local environment changes
#if [ -f /op/csh.cshrc ]; then 
#    source /opt/csh.cshrc
#fi

