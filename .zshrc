#!/usr/bin/env zsh

# Envvars
if [ -e ~/.zshrc.envvars ] ; then
   source ~/.zshrc.envvars
fi

# Python Env
if [ -e ~/.zshrc.python_env ] ; then
   source ~/.zshrc.python_env
fi


# Aliases
if [ -e ~/.zshrc.aliases ] ; then
   source ~/.zshrc.aliases
fi

# Functions
if [ -e ~/.zshrc.functions ] ; then
   source ~/.zshrc.functions
fi

eval "$(starship init zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
