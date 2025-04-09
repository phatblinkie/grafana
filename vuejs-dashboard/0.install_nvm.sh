curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh |bash
sleep 1
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

echo if this fails to work, relogin to ssh
#exit
