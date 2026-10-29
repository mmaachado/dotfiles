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
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# optional plugins (packages: zsh-autosuggestions, zsh-syntax-highlighting,
# zsh-history-substring-search; order matters)
for p in zsh-autosuggestions/zsh-autosuggestions.zsh \
         zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
         zsh-history-substring-search/zsh-history-substring-search.zsh; do
    [[ -f /usr/share/zsh/plugins/$p ]] && source /usr/share/zsh/plugins/$p
done
unset p
(( $+widgets[history-substring-search-up] )) && {
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
}

# fzf (Ctrl-R history, Ctrl-T files, Alt-C cd) and zoxide (z / zi)
(( $+commands[fzf] ))    && source <(fzf --zsh)
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
