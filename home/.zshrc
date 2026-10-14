# ~/.zshrc — interactive zsh
[[ $- != *i* ]] && return

export PATH="$HOME/.local/bin:$PATH"

for f in options aliases scripts; do
    [[ -f ~/.config/zsh/$f.zsh ]] && source ~/.config/zsh/$f.zsh
done
unset f

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

export PNPM_HOME="$HOME/.local/share/pnpm"
[[ ":$PATH:" != *":$PNPM_HOME:"* ]] && export PATH="$PNPM_HOME:$PATH"

export PATH="$HOME/tools/node-v14.15.4-linux-x64/bin:$PATH"

eval "$(starship init zsh)"

fastfetch
