#!/usr/bin/env bash

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

Usage: gpterm [<command>|<global option>] [<command option>|<user input>] [<user input>]

Commands:
  chat                  List all chats.
  config                Allows gpterm customizations. See config options for more details.
  model                 List all available models.
  switch                Allows chat or model switching. See switch options for more details.

Global options:
  --version, -v         Prints gpterm version.
  --help, -h            Prints this screen.
  --prompt, -p          Send a prompt to OpenAI. Ej.: gpterm -p 'Hi!'.

Commands options:

  Config options:
    --list, -l          Prints gpterm config parameters.
    --api-key, -A       Set API KEY for API calls. Ej.: gpterm config --api-key 'XXXXXX'
    --output-speed, -M  Set the numerical value for the divisor of the speed for the prompt output. Value 0 will disable this function. Ej.: gpterm config -M 2

  Chat options:
    --list, -l          Prints all created chats.
    --delete, -d        Delete an existing chat. Ej.: gpterm chat -d 'MyChat'

  Model options:
    --list, -l          Prints all available models.

  Switch options:
    --chat, -c          Allows chat switching
    --model, -m         Allows model switching
  "
}

# Utils
is_empty() {
  local input="$1"

  trimmed=$(echo "$input" | xargs)

  if [[ -z "$trimmed" ]]; then
    return 0
  else
    return 1
  fi
}

# Functionality
save_history() {
  local role="$1"
  local message="$2"
  local chat_name=$(get_chat_selected)
  local history_file="${CHATS_PATH}/${chat_name}/history.json"
  local tmp_file=$(mktemp)

  if [ ! -f "$history_file" ]; then
    echo "[]" > "$history_file"
  fi

  jq --arg role "$role" --arg content "$message" \
     '. += [{"role": $role, "content": $content}]' \
     "$history_file" > "$tmp_file" && mv "$tmp_file" "$history_file"
}

edit_config_json() {
  local key="$1"
  local value="$2"

  jq --arg val "$value" "$key = \$val" \
    "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}" > /tmp/config.json && \
    mv /tmp/config.json "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}"
}

send_prompt() {
  
  if [ -z "$1" ]; then
      echo "Error: You should write a prompt."
      exit 1
  fi

  save_history "user" "$1"

  call_api "$1"
}


print_prompt() {
  local response=$(jq -r '.choices[0].message.content' "${RESPONSE_FILE_PATH}/${FILENAME_RESPONSE}")
  local response_size=${#response}
  local output_speed_divisor=$(get_output_speed_divisor)
  local speed_base="0.0009"
  local output_speed=$(bc -l <<<"${speed_base}/${output_speed_divisor}")

  save_history "assistant" "$response"

  printf "\n\n"

  for i in $(seq $response_size); do
    printf "%s" "${response:$i-1:1}"

    if (( $(echo "$output_speed_divisor > 0" | bc -l) )); then
      sleep $output_speed
    fi
  done

  printf "\n\n"
}

call_api() {
  local actual_chat=$(get_chat_selected)
  local chat_history_file="${CHATS_PATH}/${actual_chat}/history.json"
  local model_selected=$(get_model_selected)

  jq -n --arg model "$model_selected" --slurpfile messages "$chat_history_file" \
    '{
      model: $model,
      messages: $messages[0]
    }' | curl -sS "https://api.openai.com/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $(get_api_key)" \
      -d @- > "${RESPONSE_FILE_PATH}/${FILENAME_RESPONSE}"
}

set_api_key() {
  edit_config_json ".config.API_KEY" "$1"
}

set_output_speed_divisor() {
  edit_config_json ".config.OutputSpeedDivisor" "$1"
  echo "Output speed divisor set to $1"
}

get_api_key() {
  jq -r '.config.API_KEY' "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}"
}

get_chat_selected() {
  jq -r '.config.ChatSelected' "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}"
}

get_model_selected() {
  jq -r '.config.ModelSelected' "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}"
}

get_output_speed_divisor() {
  jq -r '.config.OutputSpeedDivisor' "${CONFIG_FILE_PATH}/${FILENAME_CONFIG}"
}

get_actual_chat_path() {
  local selected_chat="$(get_chat_selected)"
  
  printf "%s\n" "${CHATS_PATH}/${selected_chat}"
}

is_api_key_defined() {
  [[ -n "$(get_api_key)" ]] && echo true || echo false
}

show_config() {
  echo "Actual chat: $(get_chat_selected)"
  echo "Model selected: $(get_model_selected)"
  echo "Api key defined: $(is_api_key_defined)"
  echo "Output speed divisor: $(get_output_speed_divisor)"
}

get_chats() {
  while IFS= read -r -d '' dir; do
    basename "$dir"
  done < <(find "$CHATS_PATH" -mindepth 1 -maxdepth 1 -type d -print0)
}

list_chats() {
  local selected_chat=$(get_chat_selected)
  mapfile -t chat_dirs < <(get_chats)

  if [ ${#chat_dirs[@]} -eq 0 ]; then
    echo "No chats found"
    exit 0
  fi

  for chat in "${chat_dirs[@]}"; do
    if [[ "$chat" == "$selected_chat" ]]; then
      echo -e '*' "${GREEN} $chat ${RESET}"
    else
      echo "$chat"
    fi
  done
}

list_models() {
  local selected_model=$(get_model_selected)

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

is_chat_selected() {
  local chat_selected=$(get_chat_selected)

  if is_empty "$chat_selected"; then
    echo "No chat selected"
    return 1
  fi

  return 0
}

delete_selected_chat() {
  edit_config_json ".config.ChatSelected" ""
  echo "No chat selected"
}

change_chat() {
  local chat_to_set="$1"
  local is_new_chat=true
  mapfile -t chat_dirs < <(get_chats)

  if is_empty "$chat_to_set"; then
    echo "Please enter a valid name"
    exit 1
  fi

  for chat in "${chat_dirs[@]}"; do
    if [[ "$chat" == "$chat_to_set" ]]; then
      is_new_chat=false
      break;
    fi
  done
  
  edit_config_json ".config.ChatSelected" "$chat_to_set"

  if [ "$is_new_chat" = true ]; then
    mkdir -p "${CHATS_PATH}/$chat_to_set"
    echo "[]" > "${CHATS_PATH}/${chat_to_set}/history.json"
    echo "Switched to a new chat: '$chat_to_set'"
  else
    echo "Switched to chat: '$chat_to_set'"
  fi
}

delete_chat() {
  local chat_exists=false
  local chat_to_delete="$1"
  mapfile -t chat_dirs < <(get_chats)

  for chat in "${chat_dirs[@]}"; do
    if [[ "$chat" == "$chat_to_delete" ]]; then
      chat_exists=true
      break;
    fi
  done

  if [ "$chat_exists" = false ]; then
    echo "Chat '$chat_to_delete' not found"
    exit 0
  fi
  
  read -p "Are you sure to delete chat: '$chat_to_delete'? [y/N] " confirm

  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    rm -rf "${CHATS_PATH}/${chat_to_delete}"
    echo "Chat '$chat_to_delete' deleted successfully"
    delete_selected_chat
  else
    echo "Operation cancelled."
    exit 1
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
    if is_chat_selected; then
      send_prompt "$2"
      print_prompt
      exit 0
    fi
    ;;
  config)
    case $2 in
      --list|-l)
        show_config
        ;;
      --api-key|-A)
        set_api_key "$3"
        ;;
      --output-speed|-M)
        set_output_speed_divisor "$3"
        ;;
      *)
        echo "Unrecognized option: '$2'"
        ;;
    esac
    ;;
  chat)
    case $2 in
      --list|-l)
        list_chats
        ;;
      --delete|-d)
        delete_chat "$3"
        ;;
      *)
        echo "Unrecognized option '$2'"
        ;;
    esac
    ;;
  model)
    case $2 in
      --list|-l)
        list_models
        ;;
      *)
        echo "Unrecognized option '$2'"
        ;;
    esac
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
  '')
    print_help
    ;;
  *)
    echo "Unrecognized option: '$1'"
    ;;
esac