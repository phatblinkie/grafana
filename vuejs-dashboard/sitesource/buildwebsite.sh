~/.nvm/versions/node/v18.20.4/bin/npm set strict-ssl false
#if the build fails, make try this
#nvm install 18.20.4
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

nvm alias default 18.20.4

npm install
npm run build
