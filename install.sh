#!/usr/bin/env bash
set -euo pipefail

# install.sh — Interactive installer for awesome_openclaw_skills
#
# Usage:
#   ./install.sh [TARGET_DIR]           Interactive mode
#   ./install.sh --all [TARGET_DIR]     Install everything
#   ./install.sh --list                 List available skills
#   ./install.sh --dry-run [TARGET_DIR] Show what would be installed
#   ./install.sh --uninstall [TARGET_DIR] Remove installed skills

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Defaults ---
TARGET_DIR=""
DRY_RUN=false
UNINSTALL=false
INSTALL_ALL=false
LIST_ONLY=false

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Parse arguments ---
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)       INSTALL_ALL=true; shift ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --uninstall) UNINSTALL=true; shift ;;
    --list)      LIST_ONLY=true; shift ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS] [TARGET_DIR]"
      echo ""
      echo "Options:"
      echo "  --all        Install all skills and extras"
      echo "  --dry-run    Show what would be installed without making changes"
      echo "  --uninstall  Remove installed skills"
      echo "  --list       List available skills"
      echo "  --help       Show this help"
      echo ""
      echo "TARGET_DIR defaults to ~/.openclaw"
      exit 0
      ;;
    -*)
      echo "Error: Unknown option $1" >&2
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# Set target dir from positional args
if [[ ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
  TARGET_DIR="${POSITIONAL_ARGS[0]}"
else
  TARGET_DIR="$HOME/.openclaw"
fi

# --- Skill definitions ---
# Format: id|name|category|description|source_dir|has_bin|has_refs|deps
SKILLS=(
  "1|long-running-task|Task Management|Background task execution with PID monitoring and notifications|skills/long-running-task|yes|no|jq"
  "2|coding-agent|Task Management|AI coding agent delegation patterns and fallback strategy|skills/coding-agent|no|no|"
  "3|check-on-task|Task Management|Quick task status checker with deep agent analysis|skills/check-on-task|no|no|jq"
  "4|audio-summary|Audio Processing|Text-to-speech with multi-provider fallback (Gemini/OpenAI/ElevenLabs)|skills/audio-summary|yes|no|curl,jq,python3,base64"
  "5|audio-transcription|Audio Processing|Speech-to-text via Gemini multimodal API|skills/audio-transcription|yes|no|curl,jq,python3,base64"
  "6|clone-github-repository|GitHub & Planning|Clone repos with multi-account identity resolution|skills/clone-github-repository|yes|no|git,jq"
  "7|create-execution-plan-and-await-confirmation|GitHub & Planning|Structured planning workflow with confirmation protocol|skills/create-execution-plan-and-await-confirmation|no|yes|"
)

EXTRAS=(
  "8|session-context|Extras|Inject routing metadata on agent bootstrap|hooks/session-context|hook"
  "9|workspace|Extras|HEARTBEAT.md for periodic task monitoring|workspace|workspace"
)

# --- Helper functions ---

get_field() {
  echo "$1" | cut -d'|' -f"$2"
}

print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}awesome_openclaw_skills installer${NC}"
  echo -e "${CYAN}==================================${NC}"
  echo ""
}

check_deps() {
  local deps="$1"
  local missing=()

  if [[ -z "$deps" ]]; then
    return 0
  fi

  IFS=',' read -ra dep_list <<< "$deps"
  for dep in "${dep_list[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Warning: Missing dependencies: ${missing[*]}${NC}" >&2
    return 1
  fi
  return 0
}

install_skill() {
  local name="$1"
  local source_dir="$2"
  local has_bin="$3"
  local has_refs="$4"
  local dest="$TARGET_DIR/skills/$name"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${BLUE}[dry-run]${NC} Would install: $name → $dest"
    return 0
  fi

  mkdir -p "$dest"

  # Backup existing SKILL.md
  if [[ -f "$dest/SKILL.md" ]]; then
    cp "$dest/SKILL.md" "$dest/SKILL.md.bak"
    echo -e "  ${YELLOW}Backed up${NC} existing SKILL.md → SKILL.md.bak"
  fi

  # Copy SKILL.md
  if [[ -f "$SCRIPT_DIR/$source_dir/SKILL.md" ]]; then
    cp "$SCRIPT_DIR/$source_dir/SKILL.md" "$dest/SKILL.md"
  fi

  # Copy bin/ scripts
  if [[ "$has_bin" == "yes" && -d "$SCRIPT_DIR/$source_dir/bin" ]]; then
    mkdir -p "$dest/bin"
    cp "$SCRIPT_DIR/$source_dir/bin/"* "$dest/bin/" 2>/dev/null || true
    chmod +x "$dest/bin/"* 2>/dev/null || true
  fi

  # Copy references/
  if [[ "$has_refs" == "yes" && -d "$SCRIPT_DIR/$source_dir/references" ]]; then
    mkdir -p "$dest/references"
    cp -r "$SCRIPT_DIR/$source_dir/references/"* "$dest/references/" 2>/dev/null || true
  fi

  echo -e "  ${GREEN}Installed${NC} $name → $dest"
}

install_lib() {
  local dest="$TARGET_DIR/lib"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${BLUE}[dry-run]${NC} Would install: lib/resolve_github_account → $dest/"
    return 0
  fi

  mkdir -p "$dest"
  cp "$SCRIPT_DIR/lib/resolve_github_account" "$dest/resolve_github_account"
  chmod +x "$dest/resolve_github_account"
  echo -e "  ${GREEN}Installed${NC} lib/resolve_github_account → $dest/"
}

install_hook() {
  local dest="$TARGET_DIR/hooks/session-context"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${BLUE}[dry-run]${NC} Would install: session-context hook → $dest/"
    return 0
  fi

  mkdir -p "$dest"
  cp "$SCRIPT_DIR/hooks/session-context/handler.js" "$dest/handler.js"
  echo -e "  ${GREEN}Installed${NC} session-context hook → $dest/"
}

install_workspace() {
  local dest="$TARGET_DIR/workspace"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${BLUE}[dry-run]${NC} Would install: HEARTBEAT.md → $dest/"
    return 0
  fi

  mkdir -p "$dest"

  if [[ -f "$dest/HEARTBEAT.md" ]]; then
    cp "$dest/HEARTBEAT.md" "$dest/HEARTBEAT.md.bak"
    echo -e "  ${YELLOW}Backed up${NC} existing HEARTBEAT.md"
  fi

  cp "$SCRIPT_DIR/workspace/HEARTBEAT.md" "$dest/HEARTBEAT.md"
  echo -e "  ${GREEN}Installed${NC} HEARTBEAT.md → $dest/"
}

create_task_dirs() {
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${BLUE}[dry-run]${NC} Would create task directories in $TARGET_DIR/tasks/"
    return 0
  fi

  mkdir -p "$TARGET_DIR/tasks"/{active,completed,failed,output,streams}
  echo -e "  ${GREEN}Created${NC} task directories in $TARGET_DIR/tasks/"
}

prompt_secrets_setup() {
  local secrets_dir="$TARGET_DIR/secrets"

  if [[ -d "$secrets_dir" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo -e "  ${BLUE}[dry-run]${NC} Would prompt to create secrets directory: $secrets_dir/"
    return 0
  fi

  # Skip interactive prompt if not a terminal
  if [[ ! -t 0 ]]; then
    echo ""
    echo -e "${YELLOW}Note:${NC} Audio skills need API keys in $secrets_dir/"
    echo -e "  Run: mkdir -p $secrets_dir && echo 'your-key' > $secrets_dir/GEMINI_API_KEY"
    return 0
  fi

  echo ""
  echo -e "${YELLOW}Audio skills require API keys. Set them up now?${NC}"
  echo -e "  Keys will be stored in: ${BOLD}$secrets_dir/${NC}"
  echo -e "  Required: GEMINI_API_KEY (at minimum)"
  echo -e "  Optional: OPENAI_API_KEY, ELEVENLABS_API_KEY"
  echo ""
  read -rp "Create secrets directory? [Y/n] " response

  if [[ "${response,,}" != "n" ]]; then
    mkdir -p "$secrets_dir"
    echo -e "  ${GREEN}Created${NC} $secrets_dir/"
    echo -e "  Add your keys as files: e.g., echo 'your-key' > $secrets_dir/GEMINI_API_KEY"
  fi
}

uninstall_skill() {
  local name="$1"
  local dest="$TARGET_DIR/skills/$name"

  if [[ ! -d "$dest" ]]; then
    echo -e "  ${YELLOW}Not installed:${NC} $name"
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${BLUE}[dry-run]${NC} Would remove: $dest"
    return 0
  fi

  rm -rf "$dest"
  echo -e "  ${RED}Removed${NC} $dest"
}

# --- List mode ---
if [[ "$LIST_ONLY" == true ]]; then
  print_header
  echo -e "${BOLD}Available Skills:${NC}"
  echo ""

  local_cat=""
  for skill in "${SKILLS[@]}"; do
    cat="$(get_field "$skill" 3)"
    name="$(get_field "$skill" 2)"
    desc="$(get_field "$skill" 4)"
    id="$(get_field "$skill" 1)"

    if [[ "$cat" != "$local_cat" ]]; then
      echo ""
      echo -e "  ${BOLD}${cat}:${NC}"
      local_cat="$cat"
    fi
    printf "    ${CYAN}[%s]${NC} %-45s %s\n" "$id" "$name" "$desc"
  done

  echo ""
  echo -e "  ${BOLD}Extras:${NC}"
  for extra in "${EXTRAS[@]}"; do
    id="$(get_field "$extra" 1)"
    name="$(get_field "$extra" 2)"
    desc="$(get_field "$extra" 4)"
    printf "    ${CYAN}[%s]${NC} %-45s %s\n" "$id" "$name" "$desc"
  done

  echo ""
  exit 0
fi

# --- Main install/uninstall flow ---
print_header

if [[ "$UNINSTALL" == true ]]; then
  echo -e "Uninstalling from: ${BOLD}$TARGET_DIR${NC}"
  echo ""

  for skill in "${SKILLS[@]}"; do
    name="$(get_field "$skill" 2)"
    uninstall_skill "$name"
  done

  # Uninstall extras
  if [[ -f "$TARGET_DIR/hooks/session-context/handler.js" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo -e "  ${BLUE}[dry-run]${NC} Would remove: session-context hook"
    else
      rm -f "$TARGET_DIR/hooks/session-context/handler.js"
      echo -e "  ${RED}Removed${NC} session-context hook"
    fi
  fi

  if [[ -f "$TARGET_DIR/lib/resolve_github_account" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo -e "  ${BLUE}[dry-run]${NC} Would remove: lib/resolve_github_account"
    else
      rm -f "$TARGET_DIR/lib/resolve_github_account"
      echo -e "  ${RED}Removed${NC} lib/resolve_github_account"
    fi
  fi

  echo ""
  echo -e "${GREEN}Uninstall complete.${NC}"
  exit 0
fi

echo -e "Installing to: ${BOLD}$TARGET_DIR${NC}"

# --- Determine what to install ---
SELECTED_SKILLS=()
SELECTED_EXTRAS=()

if [[ "$INSTALL_ALL" == true ]]; then
  for skill in "${SKILLS[@]}"; do
    SELECTED_SKILLS+=("$skill")
  done
  for extra in "${EXTRAS[@]}"; do
    SELECTED_EXTRAS+=("$extra")
  done
else
  # Interactive selection
  echo ""
  echo -e "${BOLD}Available skill categories:${NC}"
  echo ""

  local_cat=""
  for skill in "${SKILLS[@]}"; do
    cat="$(get_field "$skill" 3)"
    name="$(get_field "$skill" 2)"
    desc="$(get_field "$skill" 4)"
    id="$(get_field "$skill" 1)"

    if [[ "$cat" != "$local_cat" ]]; then
      echo -e "  ${BOLD}${cat}:${NC}"
      local_cat="$cat"
    fi
    printf "    ${CYAN}[%s]${NC} %-40s %s\n" "$id" "$name" "$desc"
  done

  echo ""
  echo -e "  ${BOLD}Extras:${NC}"
  for extra in "${EXTRAS[@]}"; do
    id="$(get_field "$extra" 1)"
    name="$(get_field "$extra" 2)"
    desc="$(get_field "$extra" 4)"
    printf "    ${CYAN}[%s]${NC} %-40s %s\n" "$id" "$name" "$desc"
  done

  echo ""
  if [[ ! -t 0 ]]; then
    echo "Error: Interactive mode requires a terminal. Use --all or pipe input." >&2
    exit 1
  fi
  read -rp "Enter selections (e.g., 1,2,3 or 1-5 or all): " selection

  if [[ "$selection" == "all" ]]; then
    for skill in "${SKILLS[@]}"; do
      SELECTED_SKILLS+=("$skill")
    done
    for extra in "${EXTRAS[@]}"; do
      SELECTED_EXTRAS+=("$extra")
    done
  else
    # Parse selection — expand ranges like 1-5
    IFS=',' read -ra parts <<< "$selection"
    selected_ids=()
    for part in "${parts[@]}"; do
      part="$(echo "$part" | tr -d ' ')"
      if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        for ((i=${BASH_REMATCH[1]}; i<=${BASH_REMATCH[2]}; i++)); do
          selected_ids+=("$i")
        done
      else
        selected_ids+=("$part")
      fi
    done

    for id in "${selected_ids[@]}"; do
      for skill in "${SKILLS[@]}"; do
        if [[ "$(get_field "$skill" 1)" == "$id" ]]; then
          SELECTED_SKILLS+=("$skill")
        fi
      done
      for extra in "${EXTRAS[@]}"; do
        if [[ "$(get_field "$extra" 1)" == "$id" ]]; then
          SELECTED_EXTRAS+=("$extra")
        fi
      done
    done
  fi
fi

if [[ ${#SELECTED_SKILLS[@]} -eq 0 && ${#SELECTED_EXTRAS[@]} -eq 0 ]]; then
  echo "No skills selected. Exiting."
  exit 0
fi

# --- Check dependencies ---
echo ""
echo -e "${BOLD}Checking dependencies...${NC}"
all_deps_ok=true
for skill in "${SELECTED_SKILLS[@]}"; do
  name="$(get_field "$skill" 2)"
  deps="$(get_field "$skill" 8)"
  if [[ -n "$deps" ]]; then
    if ! check_deps "$deps"; then
      all_deps_ok=false
    fi
  fi
done

# --- Install shared library ---
echo ""
echo -e "${BOLD}Installing shared library...${NC}"
install_lib

# --- Install skills ---
echo ""
echo -e "${BOLD}Installing skills...${NC}"

needs_task_dirs=false
needs_audio_secrets=false

for skill in "${SELECTED_SKILLS[@]}"; do
  name="$(get_field "$skill" 2)"
  source_dir="$(get_field "$skill" 5)"
  has_bin="$(get_field "$skill" 6)"
  has_refs="$(get_field "$skill" 7)"

  install_skill "$name" "$source_dir" "$has_bin" "$has_refs"

  # Track what extra setup is needed
  case "$name" in
    long-running-task) needs_task_dirs=true ;;
    audio-summary|audio-transcription) needs_audio_secrets=true ;;
  esac
done

# --- Install extras ---
if [[ ${#SELECTED_EXTRAS[@]} -gt 0 ]]; then
  echo ""
  echo -e "${BOLD}Installing extras...${NC}"

  for extra in "${SELECTED_EXTRAS[@]}"; do
    extra_type="$(get_field "$extra" 6)"
    case "$extra_type" in
      hook)      install_hook ;;
      workspace) install_workspace ;;
    esac
  done
fi

# --- Post-install setup ---
if [[ "$needs_task_dirs" == true ]]; then
  echo ""
  echo -e "${BOLD}Setting up task management...${NC}"
  create_task_dirs
fi

if [[ "$needs_audio_secrets" == true ]]; then
  prompt_secrets_setup
fi

# --- Config file check ---
if [[ ! -f "$HOME/.openclaw/github-accounts.json" ]]; then
  echo ""
  echo -e "${YELLOW}Note:${NC} No github-accounts.json found."
  echo -e "  Copy the example: cp ${SCRIPT_DIR}/config/github-accounts.example.json ~/.openclaw/github-accounts.json"
  echo -e "  Then edit it with your account details."
fi

# --- Summary ---
echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo -e "Skills installed to: ${BOLD}$TARGET_DIR/skills/${NC}"
if [[ "$needs_task_dirs" == true ]]; then
  echo -e "Task data directory: ${BOLD}$TARGET_DIR/tasks/${NC}"
fi
echo ""
echo -e "To set up cron monitoring (optional):"
echo -e "  See: ${SCRIPT_DIR}/examples/monitor.crontab"
echo ""
