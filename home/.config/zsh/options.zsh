# options — the defaults bash/readline gave us, plus completion

# history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt share_history hist_ignore_dups hist_ignore_space hist_reduce_blanks

setopt auto_cd interactive_comments no_beep

# keys (emacs mode, like bash)
bindkey -e
bindkey '^[[H' beginning-of-line   '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line  '^[[4~' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word     '^[[1;5D' backward-word
bindkey '^H' backward-kill-word

# completion
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# optional plugins (packages: zsh-autosuggestions, zsh-syntax-highlighting)
for p in /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
         /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [[ -f $p ]] && source "$p"
done
unset p
