#!/bin/bash -e

#SBATCH --job-name=skel
#SBATCH --output=skel.%j.out
#SBATCH --ntasks=1
#SBATCH --time=00:00:00
#SBATCH --mail-type=ALL

##################### GPU ############################################
#SBATCH --partition=sci
#SBATCH --gres=gpu:tesla_a40:1
#SBATCH --cpus-per-task=6
##################### END GPU ########################################

#################### NON-GPU #########################################
#SBATCH --partition=basic
#SBATCH --cpus-per-task=50
#################### END NON-GPU ##################################### 

# Print the simulation start date/time
date


# Print the node the simulation is running on
echo "I ran on:"
echo "SLURM_NODELIST=$SLURM_NODELIST"

# Return the context/PWD to the directory where *this* file is located.
cd $SLURM_SUBMIT_DIR

# Load the necessary program libraries
##################### GPU ############################################
source /usr/local/sw/amber/amber20/amber.sh
export CUDA_HOME="/usr/local/cuda-11.4"
export CUDA_VISIBLE_DEVICES=0
export PYTHONPATH="/usr/local/sw/amber/amber20/lib/python3.8/site-packages:$PYTHONPATH"
export PATH="/usr/local/sw/amber/amber20/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/sw/amber/amber20/lib:/usr/local/cuda/lib64:/usr/local/cuda/lib64/stubs:$LD_LIBRARY_PATH"
##################### END GPU ########################################

#################### NON-GPU #########################################
source /usr/local/sw/amber/amber20/amber.sh
export PYTHONPATH="/usr/local/sw/amber/amber20/lib/python3.8/site-packages:$PYTHONPATH"
export PATH="/usr/local/sw/amber/amber20/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/sw/amber/amber20/lib:/usr/local/cuda/lib64:/usr/local/cuda/lib64/stubs:$LD_LIBRARY_PATH"
#################### END NON-GPU ##################################### 

# Run Amber Jobs
./min.sh
./heat.sh
./eq.sh
./md.sh

# Print the simulation end date/time
date
