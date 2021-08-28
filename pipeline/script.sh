#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Identity: "TLBot/ButlerBot"
_checkIdentity() {
  if [[ ! -z ${Identity} ]]; then
    printf "Running the script for %s...\n\n" "${Identity}"
    if [[ ${Identity} = "TLBot" ]]; then
      echo 'export NGToken="${NGToken_TLBot}"' >> $BASH_ENV
      echo 'export ExecVars_Filename=ExecVarsSample.CircleCI_TLBot.py' >> $BASH_ENV
    elif [[ ${Identity} = "ButlerBot" ]]; then
      echo 'export NGToken="${NGToken_ButlerBot}"' >> $BASH_ENV
      echo 'export ExecVars_Filename=ExecVarsSample.CircleCI_ButlerBot.py' >> $BASH_ENV
    fi
  else
    printf "Identity not found. Exiting...\n" && exit 1
  fi
}

_gitAuth() {
  git config --global user.email "$GitHubMail"
  git config --global user.name "$GitHubName"
  git config --global credential.helper store
  git config --global color.ui true
  git clone -q "https://$GITHUB_TOKEN@github.com/$GitHubName/google-git-cookies.git" &> /dev/null
  if [ -e google-git-cookies ]; then
    bash google-git-cookies/setup_cookies.sh
    rm -rf google-git-cookies
  fi
}

_setWorkplace() {
  # Prepare pre-requisite
  apt-get update -qqy
  apt-get install -qqy xterm screen file nginx 1>/dev/null
  curl -fsSL https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip -o ngrok.zip
  unzip -q ngrok.zip ngrok && rm ngrok.zip
  chmod +x ngrok && mv ngrok /usr/local/bin/
  ngrok --version
  # Expose machine over ngrok
  screen -dmS ngproxy ngrok http ${PORT} --log /tmp/ngrok.log --authtoken "${NGToken}" --region ${NGRegion:-us}
  sleep 12s
  # Prepare TTK
  mkdir -p /torapp && chmod -R 777 /torapp
  export botBranch=${botBranch:-master}
  git clone https://github.com/yash-dk/TorToolkit-Telegram -b ${botBranch} --depth 1 /torapp
  cd /torapp
  # SAs
  mkdir -p /torapp/{sa,tortk/files}
  git clone https://${GITHUB_TOKEN}@github.com/rokibhasansagar/RcloneSA4Phantom --depth 1
  mv RcloneSA4Phantom/accounts/* sa/ && rm -rf RcloneSA4Phantom
  ls sa/ > sa_list
  # Pip packages
  echo -e "\nlaunchpadlib" >> requirements.txt
  pip3 install --no-cache-dir -r requirements.txt 1>/dev/null
  curl -sS -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/rokibhasansagar/random_gists/main/tortk/${ExecVars_Filename}" > tortoolkit/consts/ExecVarsSample.py
  # Rclone config
  mkdir -p ~/.config/rclone
  curl -sS -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.githubusercontent.com/rokibhasansagar/random_gists/main/tortk/rclone.conf" > ~/.config/rclone/rclone.conf
  chmod 777 alive.sh start.sh
  sleep 5s
  # Get server address
  export ServerAddr=$(grep "url=https" /tmp/ngrok.log | awk -F' url=' '{print $NF}')
  if [[ -z ${ServerAddr} ]]; then
    echo -e "\n[!] Server Address not found\n" && exit 1
  else
    echo -e "\nServer Address is ${ServerAddr}\n\n"
  fi
  sed -i 's|__SERVER__ADDRESS__|'"$ServerAddr"'|' tortoolkit/consts/ExecVarsSample.py
}

_randomSA() {
  while true; do
    sed -i 's|__ServiceAcc__|'"$(shuf -n 1 sa_list)"'|' ~/.config/rclone/rclone.conf
    sleep 20m
  done
}

_dummyEcho() {
  while true; do
    printf "\n...\n" && sleep 5m
  done
}

if [[ $1 == "_checkIdentity" ]]; then
  _checkIdentity
elif [[ $1 == "_gitAuth" ]]; then
  _gitAuth
elif [[ $1 == "_setWorkplace" ]]; then
  _setWorkplace
elif [[ $1 == "_runBot" ]]; then
  cd /torapp
  _randomSA & disown
  sleep 2s
  _dummyEcho & disown
  ./start.sh
fi
