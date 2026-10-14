# ~/.zprofile — login zsh (also used by the Plasma Wayland session)
# ~/.profile is managed outside this repo (e.g. by installers); load it in sh mode.
[[ -f ~/.profile ]] && emulate sh -c '. ~/.profile'
