[[ $- != *i* ]] && return

export PATH="$HOME/.local/bin:$PATH"

eval "$(starship init zsh)"

autoload -Uz compinit
compinit

[[ -f ~/.config/zsh/aliases.zsh ]] && source ~/.config/zsh/aliases.zsh
[[ -f ~/.config/zsh/scripts.zsh ]] && source ~/.config/zsh/scripts.zsh

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

export PNPM_HOME="$HOME/.local/share/pnpm"
[[ ":$PATH:" != *":$PNPM_HOME:"* ]] && export PATH="$PNPM_HOME:$PATH"

export PATH="$HOME/tools/node-v14.15.4-linux-x64/bin:$PATH"

eval "$(starship init zsh)"

fastfetch
