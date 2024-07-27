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

neofetch
