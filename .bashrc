#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

export PATH="/home/marques/.local/bin:$PATH"

eval "$(starship init bash)"

# aliases
if [ -e ~/.bashrc.aliases ] ; then
   source ~/.bashrc.aliases
fi

# python env
if [ -e ~/.bashrc.python_env ] ; then
   source ~/.bashrc.python_env
fi

neofetch
