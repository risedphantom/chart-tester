#!/bin/bash
set -euo pipefail

### Colors
RED='\033[41m'
GREEN='\033[42m'
BLUE=$(tput setaf 6)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0)

### Constants
S='[[:space:]]*'
W='[a-zA-Z0-9_]*'
FS=$(echo @ | tr @ '\034')
SETTINGS_FILE=".chart-tester"
CHART_TESTER_VERSION="0.9.0"

### Settings
CHART_PATTERN="##-> Chart:"
TYPE_PATTERN="##-> Type:"
PATH_PATTERN="##-> Path:"
SRC_PATTERN="##-> Source:"
V_PATTERN="##-> Version:"
NC_PATTERN="##-> Namespace:"
RL_PATTERN="##-> Release:"
BASE_VALUES_PATTERN="##-> BaseValues:"

YAML_ROOT_KEY="chartInstallOptions"
YAML_CHART_KEY="chart"
YAML_TYPE_KEY="type"
YAML_PATH_KEY="path"
YAML_SRC_KEY="source"
YAML_V_KEY="version"
YAML_NS_KEY="namespace"
YAML_RL_KEY="releaseName"
YAML_BASE_VALUES_KEY="baseValues"

CHARTS_DIR=".charts"
DEBUG_SUFFIX="-debug.yaml"

### Locate settings file
ROOT_DIR=$(find . -name "$SETTINGS_FILE" -exec dirname {} \;)

## Library functions
log() {
  echo -e "$1" >&2
}

panic() {
  log "${RED}$1${NC}"
  exit 1
}

parse_yaml() {
  local indent key val
  declare -a vname

  while IFS= read -r line || [ -n "$line" ]; do
    # Remove leading spaces
    local s="${line#"${line%%[![:space:]]*}"}"
    indent=$(( (${#line} - ${#s}) / 2 ))

    # Key-value pair
    if [[ "$s" =~ ^([a-zA-Z0-9_]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      val="${val%\"}"
      val="${val#\"}"
      val="${val%\'}"
      val="${val#\'}"
      vname[indent]="$key"
      unset 'vname[@]'[$((indent + 1))]

      full_key=""
      for ((i = 0; i <= indent; i++)); do
        [[ ${vname[i]} ]] && full_key+="${vname[i]}_"
      done
      full_key="${full_key%_}"

      [[ -n $val ]] && printf "%s~%s\n" "$full_key" "$val"

    # Array item
    elif [[ "$s" =~ ^-+[[:space:]]*(.*)$ ]]; then
      val="${BASH_REMATCH[1]}"
      val="${val%\"}"
      val="${val#\"}"
      val="${val%\'}"
      val="${val#\'}"

      full_key=""
      for ((i = 0; i < indent; i++)); do
        [[ ${vname[i]} ]] && full_key+="${vname[i]}_"
      done
      full_key="${full_key%_}"
      printf "%s~%s\n" "$full_key" "$val"
    fi
  done < "$1"
}

## Main functions
validate() {
  [[ -z $ROOT_DIR ]] && panic "It's not a chart-tester project. \"$SETTINGS_FILE\" file not found"
  command -v helm >/dev/null || panic "helm is required but not installed"
  command -v git >/dev/null || panic "git is required but not installed"


  while IFS='=' read -r key value; do
    case "$key" in
      "CHART_PATTERN") CHART_PATTERN="$value" ;;
      "TYPE_PATTERN") TYPE_PATTERN="$value" ;;
      "PATH_PATTERN") PATH_PATTERN="$value" ;;
      "SRC_PATTERN") SRC_PATTERN="$value" ;;
      "V_PATTERN") V_PATTERN="$value" ;;
      "NC_PATTERN") NC_PATTERN="$value" ;;
      "RL_PATTERN") RL_PATTERN="$value" ;;
      "BASE_VALUES_PATTERN") BASE_VALUES_PATTERN="$value" ;;
      "CHARTS_DIR") CHARTS_DIR="$value" ;;
      "DEBUG_SUFFIX") DEBUG_SUFFIX="$value" ;;
      "COLOR_RED") RED="$value" ;;
      "COLOR_GREEN") GREEN="$value" ;;
      "COLOR_BLUE") BLUE="$value" ;;
      "COLOR_YELLOW") YELLOW="$value" ;;
      "YAML_ROOT_KEY") YAML_ROOT_KEY="$value" ;;
      "YAML_CHART_KEY") YAML_CHART_KEY="$value" ;;
      "YAML_TYPE_KEY") YAML_TYPE_KEY="$value" ;;
      "YAML_PATH_KEY") YAML_PATH_KEY="$value" ;;
      "YAML_SRC_KEY") YAML_SRC_KEY="$value" ;;
      "YAML_V_KEY") YAML_V_KEY="$value" ;;
      "YAML_NS_KEY") YAML_NS_KEY="$value" ;;
      "YAML_RL_KEY") YAML_RL_KEY="$value" ;;
      "YAML_BASE_VALUES_KEY") YAML_BASE_VALUES_KEY="$value" ;;
      "VERSION") VERSION="$value" ;;
    esac
  done < "$ROOT_DIR/$SETTINGS_FILE"

  SMALLER_VERSION=$(printf '%s\n%s\n' "$CHART_TESTER_VERSION" "$VERSION" | sort -V | head -n1)
  [[ "$SMALLER_VERSION" != "$VERSION"  ]] && panic "Chart-tester version mismatch! Expected $CHART_TESTER_VERSION to be equal or greater than $VERSION"

  YAML_BODY_PATTERN="${YAML_ROOT_KEY}:"
  YAML_CHART_VAR="${YAML_ROOT_KEY}_$YAML_CHART_KEY"
  YAML_TYPE_VAR="${YAML_ROOT_KEY}_$YAML_TYPE_KEY"
  YAML_PATH_VAR="${YAML_ROOT_KEY}_$YAML_PATH_KEY"
  YAML_SRC_VAR="${YAML_ROOT_KEY}_$YAML_SRC_KEY"
  YAML_V_VAR="${YAML_ROOT_KEY}_$YAML_V_KEY"
  YAML_NS_VAR="${YAML_ROOT_KEY}_$YAML_NS_KEY"
  YAML_RL_VAR="${YAML_ROOT_KEY}_$YAML_RL_KEY"
  YAML_BASE_VALUES_VAR="${YAML_ROOT_KEY}_$YAML_BASE_VALUES_KEY"

  log "Running chart-tester ${BLUE}$CHART_TESTER_VERSION${NC}"
}

parse_meta() {
  local file="$@"

  declare -A vals
  while IFS='~' read -r k v; do
    if [[ -n ${vals[$k]+x} ]]; then
      vals[$k]="${vals[$k]},$v"
    else
      vals[$k]=$v
    fi
  done < <(parse_yaml $file)

  local chart_comment=$(grep "^$CHART_PATTERN" $file | awk '{print $3}')
  local source_comment=$(grep "^$SRC_PATTERN" $file | awk '{print $3}')
  local type_comment=$(grep "^$TYPE_PATTERN" $file | awk '{print $3}')
  local version_comment=$(grep "^$V_PATTERN" $file | awk '{print $3}')
  local path_comment=$(grep "^$PATH_PATTERN" $file | awk '{print $3}')
  local ns_comment=$(grep "^$NC_PATTERN" $file | awk '{print $3}')
  local release_comment=$(grep "^$RL_PATTERN" $file | awk '{print $3}')
  local baseValues_comment=$(grep "^$BASE_VALUES_PATTERN" $file | awk '{print $3}')

  local chart=${vals[$YAML_CHART_VAR]:=$chart_comment}
  local source=${vals[$YAML_SRC_VAR]:=$source_comment}
  local type=${vals[$YAML_TYPE_VAR]:=$type_comment}
  local version=${vals[$YAML_V_VAR]:=$version_comment}
  local path=${vals[$YAML_PATH_VAR]:=$path_comment}
  local release=${vals[$YAML_RL_VAR]:=$release_comment}
  local ns=${vals[$YAML_NS_VAR]:=$ns_comment}
  local baseValues=${vals[$YAML_BASE_VALUES_VAR]:=$baseValues_comment}
  type=${type:-helm}
  release=${release:=$chart}
  ns=${ns:=$release}

  [[ -z $chart ]] && echo "no_chart_metadata"
  [[ -z $source ]] && echo "no_source_metadata"
  [[ -z $type ]] && echo "no_type_metadata"
  [[ -z $version ]] && echo "no_version_metadata"

  echo "nil|$chart|$source|$type|$version|$path|$ns|$release|$baseValues"
}

download_helm() {
  local chart="$1"
  local source="$2"
  local version="$3"

  log "Downloading ${BLUE}$chart${NC} version ${BLUE}$version${NC}..."
  rm -rf "$CHARTS_DIR/$chart*"
  if [[ $source == oci:* ]]; then
    helm pull --untar -d $CHARTS_DIR $source/$chart --version $version
  else
    helm pull --untar -d $CHARTS_DIR $chart --repo $source --version $version
  fi
  # This hack needs to be fixed
  rm -rf $CHARTS_DIR/$chart*tgz
}

download_git() {
  local chart="$1"
  local source="$2"
  local version="$3"
  local path="$4"

  log "Downloading ${BLUE}$chart${NC} version ${BLUE}$version${NC}..."
  rm -rf "$CHARTS_DIR/$chart"
  git clone -n --depth=1 --filter=tree:0 --single-branch -b "$version" "$source" "$CHARTS_DIR/$chart"
  pushd "$CHARTS_DIR/$chart" > /dev/null

  if [[ -n $path ]]; then
    git sparse-checkout set --no-cone "$path"
    git checkout
    mv "$path"/* .
    rm -rf "${path%%/*}"
  fi

  rm -rf .git
  helm dep up

  popd > /dev/null
}

print_info() {
  local chart="$1"
  local source="$2"
  local type="$3"
  local version="$4"
  local path="$5"
  local ns="$6"
  local release="$7"
  local baseValues="${8:-}"

  log "  ${GREEN}Chart:${NC} $chart"
  log "  ${GREEN}Version:${NC} $version"
  log "  ${GREEN}Source:${NC} $source"
  log "  ${GREEN}Type:${NC} $type"
  [[ -n $path ]] && log "  ${GREEN}Path:${NC} $path"
  [[ -n $ns ]] && log "  ${GREEN}Namespace:${NC} $ns"
  [[ -n $release ]] && log "  ${GREEN}Release:${NC} $release"
  [[ -n $baseValues ]] && log "  ${GREEN}Base Values:${NC} $baseValues"
}

discover_files() {
  grep -rl --include="*.yaml" --include="*.yml" "^$CHART_PATTERN" $ROOT_DIR
  grep -rl --include="*.yaml" --include="*.yml" "^$YAML_BODY_PATTERN" $ROOT_DIR
}

dep_update() {
  [[ $# -eq 0 ]] && file=$(select_chart) || file="$@"

  log "Parsing ${BLUE}$file${NC}..."

  IFS="|" read err chart source type version path ns release baseValues <<<$(parse_meta "$file")
  [[ $err != "nil" ]] && panic "Malformed metadata in file $file: $err"

  print_info "$chart" "$source" "$type" "$version" "$path" "$ns" "$release" "$baseValues"

  if [[ $type == "helm" ]]; then
    download_helm "$chart" "$source" "$version"
  elif [[ $type == "git" ]]; then
    download_git "$chart" "$source" "$version" "$path"
  else
    panic "Unsupported type '$type' in file $file"
  fi
}

deps_update() {
  log "Updating dependencies..."

  values=$(discover_files)

  for file in $values; do
    dep_update "$file"
  done
}

get_base_value_args() {
  local base_values="$1"
  local values_dir="$2"
  local args=""
  if [[ -n $base_values ]]; then
    IFS=',' read -ra base_values_array <<<"$base_values"
    for base_value in "${base_values_array[@]}"; do
      local base_value_file="$values_dir/$base_value"
      if [[ -f $base_value_file ]]; then
        args+=" -f $base_value_file"
      else
        panic "Base value file $base_value_file not found!"
      fi
    done
  fi
  echo "$args"
}

debug_chart() {
  [[ $# -eq 0 ]] && file=$(select_chart) || file="$@"
  local values_dir=$(dirname $file)

  log "Debugging ${GREEN}$file${NC}..."

  IFS="|" read err chart source type version path ns release baseValues <<<$(parse_meta "$file")
  [[ $err != "nil" ]] && panic "Malformed metadata in file $file"

  local base_args=$(get_base_value_args "$baseValues" "$values_dir")

  log "Command: ${BLUE}helm lint $CHARTS_DIR/$chart $base_args -f $file -n ${ns:-default}${NC}"
  helm lint "$CHARTS_DIR/$chart" $base_args -f $file -n ${ns:-default}

  log "Command: ${BLUE}helm template ${release:-$chart} $CHARTS_DIR/$chart $base_args -f $file -n ${ns:-default} --debug >$values_dir/$chart$DEBUG_SUFFIX${NC}"
  helm template ${release:-$chart} "$CHARTS_DIR/$chart" $base_args -f $file -n ${ns:-default} --debug >$values_dir/$chart$DEBUG_SUFFIX

  log "Debug file: ${BLUE}$values_dir/$chart$DEBUG_SUFFIX${NC}"
}

list_testable() {
  log "Listing testable charts..."
  values=$(discover_files)

  for file in $values; do
    log "Found ${BLUE}$file${NC}..."
    IFS="|" read err chart source type version path ns release baseValues <<<$(parse_meta "$file")
    [[ $err != "nil" ]] && panic "Malformed metadata in file $file: $err"

    print_info "$chart" "$source" "$type" "$version" "$path" "$ns" "$release" "$baseValues"
  done
}

select_chart() {
  log "${GREEN}Available charts:${NC}"
  for file in $(discover_files); do
    log "${BLUE}$file${NC}"
  done
  log ""

  read -p "Please input chart file: " file
  [[ -z $file ]] && panic "Invalid selection"

  log ""
  log "$file"
}

select_deployment() {
  log "${GREEN}Available releases to install from $ROOT_DIR:${NC}"
  for file in $(ls -d $ROOT_DIR/* | sort); do
    if [[ -d $file ]]; then
      log "${YELLOW}$file${NC}"
    else
      log "${BLUE}$file${NC}"
    fi
  done
  log ""

  read -p "Please input chart file or directory: " item
  [[ -z $item ]] && panic "Invalid selection"

  log ""
  log "$item"
}

select_k8s_ctx() {
  log "${GREEN}Available k8s contexts:${NC}"
  log "${BLUE}$(kubectl config get-contexts -oname)${NC}"
  log ""

  read -p "Please input context name: " ctx
  [[ -z $ctx ]] && panic "Invalid selection"

  printf "Selected context ${GREEN}$ctx${NC}\n\n" >&2
  log "$ctx"
}

install_chart() {
  [[ $# -eq 0 ]] && item=$(select_deployment) || item="$@"

  if [[ -d $item ]]; then
    files=$(find $item -type f -name "*.yaml" ! -name "*$DEBUG_SUFFIX" | sort)
  else
    files=$item
  fi

  for file in $files; do
    IFS="|" read err chart source type version path ns release baseValues <<<$(parse_meta "$file")
    [[ $err != "nil" ]] && panic "Malformed metadata in file $file"
    [[ $release == "" ]] && panic "No release name provided in file $file"
    [[ $ns == "" ]] && panic "No namespace provided in file $file"
  done

  ctx=$(select_k8s_ctx)

  for file in $files; do
    local values_dir=$(dirname $file)

    log "Parsing ${BLUE}$file${NC}..."
    IFS="|" read err chart source type version path ns release baseValues <<<$(parse_meta "$file")
    local base_args=$(get_base_value_args "$baseValues" "$values_dir")

    log "Installing..."
    print_info "$chart" "$source" "$type" "$version" "$path" "$ns" "$release" "$baseValues"

    log "Command: ${BLUE}helm upgrade --install --create-namespace $release $CHARTS_DIR/$chart $base_args -f $file -n $ns --kube-context $ctx${NC}"
    helm upgrade --install --create-namespace "$release" "$CHARTS_DIR/$chart" $base_args -f "$file" -n "$ns" --kube-context "$ctx"
  done
}

help() {
  log "Usage: chart-tester.sh [OPTION]"
  log "  -u, --update           Update dependencies based on metadata in values files"
  log "  -r, --upgrade [PATH]   Update a specific chart based on metadata in values file"
  log "  -i, --install [PATH]   Install a specific chart based on metadata in values file"
  log "  -h, --help             Display this help"
  log "  -l, --list             List testable charts"
  log "  -d, --debug [PATH]     Debug chart"
  log "  -g, --generate [PATH]  Generate metadata for values file"
}

valid_args=$(getopt -o urihld --long update,upgrade,install,help,list,debug -- "$@")
[[ $? -ne 0 ]] && exit 1

eval set -- "$valid_args"
case "$1" in
-u | --update)
  validate
  deps_update
  ;;
-r | --upgrade)
  validate
  shift 2
  dep_update "$@"
  ;;
-i | --install)
  validate
  shift 2
  install_chart "$@"
  ;;
-l | --list)
  validate
  list_testable
  ;;
-d | --debug)
  validate
  shift 2
  debug_chart "$@"
  ;;
-h | --help)
  help
  ;;
--)
  help
  ;;
esac
