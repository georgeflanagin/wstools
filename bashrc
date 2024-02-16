[ -z "$PS1" ] && return
# .bashrc

alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific aliases and functions
source /usr/local/etc/bash.sh
cd
export COLUMBUS=/usr/local/columbus722
