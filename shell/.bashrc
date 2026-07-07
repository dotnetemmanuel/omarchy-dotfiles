
# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

export PATH="$HOME/.local/bin:$PATH"

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

export PATH="$HOME/.local/bin:$PATH"

eval "$($HOME/.local/bin/oh-my-posh init bash --config $HOME/.config/oh-my-posh/Retro-82.omp.json)"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'


export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH="$PATH:$HOME/.dotnet/tools"
export PATH="$PATH:$HOME/Android/Sdk/platform-tools"


export DOTNET_ROOT=/usr/share/dotnet

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
