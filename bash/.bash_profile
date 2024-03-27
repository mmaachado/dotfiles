#!/usr/bin/env bash

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"


if [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi