# aliases

alias ls='ls --color=auto'
alias grep='grep --color=auto'

alias lt='tree'

# print IPv4/IPv6 address
alias ipv4="ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print \$2}' | cut -d/ -f1"
alias ipv6="ip addr show | grep 'inet6 ' | awk '{print \$2}' | sed -n '2p'"

# reload zsh config
alias src="clear && source ~/.zshrc"

# print errors from boot
alias error='journalctl -b -p err'

# show latest Arch Linux news
alias pacnews="arch_news_check"
