#/bin/bash

export GPTERM_VERSION="0.1.0"
export OPENAI_API_KEY=""
export CONFIG_FILE_PATH=""
export FILE_RESPONSE_PATH="/tmp"
export FILENAME_RESPONSE="chatgpt_response.json"

print_version() {
  echo $GPTERM_VERSION
}

print_help() {
  echo "    
  ____ ____ _____                   
 / ___|  _ \_   _|__ _ __ _ __ ___  
| |  _| |_) || |/ _ \ '__| '_ \` _ \ 
| |_| |  __/ | |  __/ |  | | | | | |
 \____|_|    |_|\___|_|  |_| |_| |_|


Version: '$GPTERM_VERSION'

By: Alonso González-Leal @agopdev


  "
}

send_prompt() {
  
  if [ -z "$1" ]; then
      echo "Error: You should write a prompt."
      exit 1
  fi

  call_api "$1"
}


print_prompt() {
  local response=$(jq -r '.choices[0].message.content' "${FILE_RESPONSE_PATH}/${FILENAME_RESPONSE}")
  local response_size=${#response}

  for i in $(seq $response_size); do
    printf "%s" "${response:$i-1:1}"
    sleep 0.01
  done

  echo ""
}

call_api() {
  curl -sS "https://api.openai.com/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$(jq -n --arg prompt "'$1'" '{
          model: "gpt-4o",
          messages: [
            { role: "user", content: $prompt }
          ]
        }')" > "${FILE_RESPONSE_PATH}/${FILENAME_RESPONSE}"
}


# Inputs
case $1 in
  --version|-v)
    print_version
    ;;
  --help|-h)
    print_help
    ;;
  --prompt|-p)
    send_prompt "'$2'"
    print_prompt
    ;;
  *)
    echo "Unrecognized option: '$1'"
    ;;
esac