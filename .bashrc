#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export PATH="/home/marques/.local/bin:$PATH"

eval "$(starship init bash)"

# aliases
if [ -e ~/.bashrc.aliases ] ; then
   source ~/.bashrc.aliases
fi

# scripts
if [ -e ~/.bashrc.scripts ] ; then
   source ~/.bashrc.scripts
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# pnpm
export PNPM_HOME="/home/marques/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

complete -cf sudo
neofetch

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/marques/.lmstudio/bin"
# End of LM Studio CLI section

