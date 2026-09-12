#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob nocaseglob

# GORL ROM preparation tool - Bash version.
# - Renames supported ROMs to safe DOS 8.3 filenames.
# - Keeps titles already present in gametitles.txt.
# - Asks only for new ROMs.
# - Rebuilds gametitles.txt and removes entries for deleted ROMs.

OUTPUT_NAME="gametitles.txt"
SUPPORTED_EXTS=" ROM SCC A8 A16 D2R "

declare -A OLD_TITLES=()
declare -A CARRIED_TITLES=()
declare -A CARRIED_SOURCE=()
declare -A SURVIVED=()
declare -A OCCUPIED=()

upper() {
    printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

is_supported_ext() {
    local e
    e="$(upper "$1")"
    [[ "$SUPPORTED_EXTS" == *" $e "* ]]
}

make_stem() {
    local s reserved
    s="$(upper "$1" | LC_ALL=C sed -E 's/[^A-Z0-9_-]/_/g')"
    [[ -n "$s" ]] || s="GAME"
    s="${s:0:8}"

    case "$s" in
        CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]) reserved=1 ;;
        *) reserved=0 ;;
    esac
    if (( reserved )); then
        s="_${s}"
        s="${s:0:8}"
    fi
    printf '%s' "$s"
}

sanitize_title() {
    local s="$1"
    s="$(printf '%s' "$s" | awk '{$1=$1; print}')"
    printf '%s' "$s" | LC_ALL=C sed 's/[^ -~]/?/g'
}

load_titles() {
    [[ -f "$OUTPUT_NAME" ]] || return 0
    local line filename title key
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "${line//[[:space:]]/}" ]] || continue
        filename="${line%%[[:space:]]*}"
        [[ "$filename" != "$line" ]] || continue
        title="${line#"$filename"}"
        title="${title#${title%%[![:space:]]*}}"
        [[ -n "$title" ]] || continue
        key="$(upper "$filename")"
        OLD_TITLES["$key"]="$title"
    done < "$OUTPUT_NAME"
}

choose_unique() {
    local stem="$1" ext="$2" candidate key n suffix keep
    candidate="${stem}.${ext}"
    key="$(upper "$candidate")"
    if (( ${OCCUPIED[$key]-0} == 0 )); then
        printf '%s' "$candidate"
        return 0
    fi

    for ((n=1; n<=999; n++)); do
        suffix="_${n}"
        keep=$((8 - ${#suffix}))
        (( keep < 1 )) && keep=1
        candidate="${stem:0:keep}${suffix}.${ext}"
        key="$(upper "$candidate")"
        if (( ${OCCUPIED[$key]-0} == 0 )); then
            printf '%s' "$candidate"
            return 0
        fi
    done

    echo "ERROR: cannot create a unique DOS filename for ${stem}.${ext}" >&2
    return 1
}

load_titles

files=(*)
rom_count=0
for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    key="$(upper "$f")"
    OCCUPIED["$key"]=$(( ${OCCUPIED[$key]-0} + 1 ))
    [[ "$f" == *.* ]] || continue
    ext="${f##*.}"
    if is_supported_ext "$ext"; then
        rom_count=$((rom_count + 1))
    fi
done

# If all ROMs were deleted, clear the title file too.
if (( rom_count == 0 )); then
    : > "$OUTPUT_NAME"
    echo "No ROM files found."
    echo "Updated: $(pwd)/$OUTPUT_NAME"
    echo "Removed stale title entries: ${#OLD_TITLES[@]}"
    exit 0
fi

echo "=== 1/3 - DOS 8.3 rename ==="
renamed=0
for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    [[ "$f" == *.* ]] || continue
    ext="${f##*.}"
    is_supported_ext "$ext" || continue

    old_key="$(upper "$f")"
    OCCUPIED["$old_key"]=$(( ${OCCUPIED[$old_key]-0} - 1 ))

    stem="${f%.*}"
    new_stem="$(make_stem "$stem")"
    new_ext="$(upper "$ext")"
    target="$(choose_unique "$new_stem" "$new_ext")"
    new_key="$(upper "$target")"

    if [[ -n "${OLD_TITLES[$old_key]-}" ]]; then
        CARRIED_TITLES["$new_key"]="${OLD_TITLES[$old_key]}"
        CARRIED_SOURCE["$new_key"]="$old_key"
    elif [[ -n "${OLD_TITLES[$new_key]-}" ]]; then
        CARRIED_TITLES["$new_key"]="${OLD_TITLES[$new_key]}"
        CARRIED_SOURCE["$new_key"]="$new_key"
    fi

    if [[ "$target" == "$f" ]]; then
        echo "[OK]     $f"
    else
        echo "[RENAME] $f -> $target"
        mv -- "$f" "$target"
        renamed=$((renamed + 1))
    fi

    OCCUPIED["$new_key"]=$(( ${OCCUPIED[$new_key]-0} + 1 ))
done

echo
echo "Renamed files: $renamed"
echo
echo "=== 2/3 - Game titles ==="

tmp=".${OUTPUT_NAME}.tmp.$$"
trap 'rm -f -- "$tmp"' EXIT
: > "$tmp"
kept=0
added=0

current=(*)
for rom in "${current[@]}"; do
    [[ -f "$rom" ]] || continue
    [[ "$rom" == *.* ]] || continue
    ext="${rom##*.}"
    is_supported_ext "$ext" || continue

    key="$(upper "$rom")"
    title="${CARRIED_TITLES[$key]-}"

    if [[ -n "$title" ]]; then
        source_key="${CARRIED_SOURCE[$key]-}"
        [[ -n "$source_key" ]] && SURVIVED["$source_key"]=1
    elif [[ -n "${OLD_TITLES[$key]-}" ]]; then
        title="${OLD_TITLES[$key]}"
        SURVIVED["$key"]=1
    fi

    if [[ -n "$title" ]]; then
        kept=$((kept + 1))
        echo "[KEEP]   $rom -> $title"
    else
        echo
        echo "ROM: $rom"
        default="${rom%.*}"
        printf 'Full game title [Enter = %s]: ' "$default"
        if ! IFS= read -r title; then
            title=""
        fi
        [[ -n "${title//[[:space:]]/}" ]] || title="$default"
        added=$((added + 1))
    fi

    title="$(sanitize_title "$title")"
    [[ -n "$title" ]] || title="${rom%.*}"
    printf '%s %s\n' "$rom" "$title" >> "$tmp"
done

echo
echo "=== 3/3 - gametitles.txt ==="
mv -- "$tmp" "$OUTPUT_NAME"
trap - EXIT

removed=$(( ${#OLD_TITLES[@]} - ${#SURVIVED[@]} ))
(( removed < 0 )) && removed=0

echo "Updated: $(pwd)/$OUTPUT_NAME"
echo "Existing titles kept: $kept"
echo "New titles requested: $added"
echo "Removed stale title entries: $removed"
