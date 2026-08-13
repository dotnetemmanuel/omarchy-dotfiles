
# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

export PATH="$HOME/.local/bin:$PATH"

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
# /etc/omarchy.conf is written by omarchy-dev-link. When absent, force the
# package default instead of preserving a stale inherited dev-link value before
# we decide which rc file to source.
if [[ -f /etc/omarchy.conf ]]; then
  source /etc/omarchy.conf
  export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
else
  export OMARCHY_PATH=/usr/share/omarchy
fi
source "$OMARCHY_PATH/default/bash/rc"

# Omarchy sets ignoreboth, which only skips a repeat run back to back.
HISTCONTROL=ignoreboth:erasedups

export PATH="$HOME/.local/bin:$PATH"

# eval "$($HOME/.local/bin/oh-my-posh init bash --config $HOME/.config/oh-my-posh/Retro-82.omp.json)"

# Profile follows the current Omarchy theme; set STARSHIP_STYLE=plain for the flat variant.
_starship_theme="$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme.name" 2>/dev/null)"
_starship_profile="$HOME/.config/starship/${_starship_theme}-${STARSHIP_STYLE:-powerline}.toml"
if [ -f "$_starship_profile" ]; then
  export STARSHIP_CONFIG="$_starship_profile"
else
  unset STARSHIP_CONFIG
fi
unset _starship_profile
unset _starship_theme
eval "$(starship init bash)"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'


export NVM_DIR="$HOME/.config/nvm"
set -h  # nvm calls "hash -r" on load, which errors under the "set +h" omarchy sets for mise
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
set +h
export PATH="$PATH:$HOME/.dotnet/tools"
export PATH="$PATH:$HOME/Android/Sdk/platform-tools"


export DOTNET_ROOT=/usr/share/dotnet

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

# Append: starship, the window title and zoxide are already in this array.
PROMPT_COMMAND+=('history -a')
