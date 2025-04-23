#/bin/bash

export GPTERM_VERSION="0.1.0"
export CONFIG_FILE_PATH=""
export RESPONSE_FILE_PATH="/tmp"
export FILENAME_RESPONSE="chatgpt_response.json"
export CONFIG_FILE_PATH="$HOME/.config/gpterm"
export FILENAME_CONFIG="config.json"
export CHATS_PATH="$HOME/.local/share/gpterm/chats_history"
export MODELS=("gpt-3.5-turbo" "gpt-3.5-turbo-16k" "gpt-4" "gpt-4-turbo" "gpt-4o")
export GREEN="\033[0;32m"
export RESET="\033[0m"

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

Usage: []

Commands:



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
  local response=$(jq -r '.choices[0].message.content' "${RESPONSE_FILE_PATH}/${FILENAME_RESPONSE}")
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
    -H "Authorization: Bearer $(get_api_key)" \
    -d "$(jq -n --arg prompt "'$1'" '{
          model: "gpt-4o",
          messages: [
            { role: "user", content: $prompt }
          ]
        }')" > "${RESPONSE_FILE_PATH}/${FILENAME_RESPONSE}"
}

edit_config_json() {
  local key="$1"
  local value="$2"

  jq --arg val "$value" "$key = \$val" \
    "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}" > /tmp/config.json && \
    mv /tmp/config.json "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}"
}


set_api_key() {
  edit_config_json ".config.API_KEY" "$1"
}

get_api_key() {
  jq -r '.config.API_KEY' "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}"
}

get_selected_chat() {
  jq -r '.config.ChatSelected' "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}"
}

get_selected_model() {
  jq -r '.config.ModelSelected' "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}"
}

get_actual_chat_path() {
  local selected_chat="$(get_selected_chat)"
  
  printf "%s\n" "${CHATS_PATH}/${selected_chat}"
}

is_api_key_defined() {
  [[ -n "$(get_api_key)" ]] && echo true || echo false
}

show_config() {
  echo "Actual chat: $(get_selected_chat)"
  echo "Model selected: $(get_selected_model)"
  echo "Api key defined: $(is_api_key_defined)"
}

get_chats() {
  while IFS= read -r -d '' dir; do
    basename "$dir"
  done < <(find "$CHATS_PATH" -mindepth 1 -maxdepth 1 -type d -print0)
}

list_chats() {
  local selected_chat=$(get_selected_chat)
  mapfile -t chat_dirs < <(get_chats)

  for chat in "${chat_dirs[@]}"; do
    if [[ "$chat" == "$selected_chat" ]]; then
      echo -e '*' "${GREEN} $chat ${RESET}"
    else
      echo "$chat"
    fi
  done
}

list_models() {
  local selected_model=$(get_selected_model)

  for model in "${MODELS[@]}"; do
    if [[ "$model" == "$selected_model" ]]; then
      echo -e '*' "${GREEN} $model ${RESET}"
    else
      echo "$model"
    fi
  done
}

change_model() {
  local model_to_set="$1"
  local is_model_changed=false

  for model in "${MODELS[@]}"; do
    if [[ "$model" == "$model_to_set" ]]; then
      edit_config_json ".config.ModelSelected" "$model_to_set"
      is_model_changed=true
      break
    fi
  done

  if [ "$is_model_changed" = true ]; then
    echo "Model changed successfully"
  else
    echo "Model not found"
  fi
}

change_chat() {
  local chat_to_set="$1"
  local is_new_chat=true
  mapfile -t chat_dirs < <(get_chats)

  for chat in "${chat_dirs[@]}"; do
    if [[ "$chat" == "$chat_to_set" ]]; then
      is_new_chat=false
      break;
    fi
  done
  
  edit_config_json ".config.ChatSelected" "$chat_to_set"

  if [ "$is_new_chat" = true ]; then
    mkdir -p "${CHATS_PATH}/$chat_to_set"
    echo "Switched to a new chat"
  else
    echo "Switched to: '$chat_to_set' chat"
  fi
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
    send_prompt "$2"
    print_prompt
    ;;
  config)
    case $2 in
      --list|-l)
        show_config
        ;;
      --api-key)
        set_api_key "$3"
        ;;
      *)
      echo "Unrecognized option: '$2'"
      ;;
    esac
    ;;
  chat)
    list_chats
    ;;
  model)
    list_models
    ;;
  switch)
    case $2 in
      --chat|-c)
        change_chat "$3"
        ;;
      --model|-m)
        change_model "$3"
        ;;
      *)
      echo "Unrecognized option: '$2'"
      ;;
    esac
    ;;
  *)
    echo "Unrecognized option: '$1'"
    ;;
esac