#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

fail() {
    echo "[!] $*" >&2
    exit 1
}

sha256() {
    shasum -a 256 < "$1" | awk '{print $1}'
}

stage_component() {
    local source=$1 name=$2 destination=$3
    local file relative output digest origin revision tree patch
    local records="$TEMP_DIR/$name-notices.json"

    origin=$(git -C "$source" remote get-url origin)
    revision=$(git -C "$source" rev-parse HEAD)
    tree=$(git -C "$source" rev-parse 'HEAD^{tree}')
    mkdir -p "$destination/$name"
    echo '[]' > "$records"
    for file in "$source"/LICENSE* "$source"/LICENCE* "$source"/COPYING* \
        "$source"/NOTICE* "$source"/AUTHORS* "$source"/VERSION.dat; do
        [ -e "$file" ] || [ -L "$file" ] || continue
        [[ -f "$file" && ! -L "$file" ]] || fail "not a regular notice: $file"
        relative=$(basename "$file")
        git -C "$source" ls-files --error-unmatch -- "$relative" >/dev/null
        output="$name/$relative"
        cp "$file" "$destination/$output"
        digest=$(sha256 "$destination/$output")
        jq --arg source "$relative" --arg path "$output" --arg sha "$digest" \
            '. + [{source_path:$source,path:$path,sha256:$sha}] | sort_by(.path)' \
            "$records" > "$records.next"
        mv "$records.next" "$records"
    done
    jq -e 'any(.[]; .source_path | test("^(LICENSE|LICENCE|COPYING)"))' "$records" >/dev/null ||
        fail "no tracked license found for $name"

    patch="$TEMP_DIR/$name.patch"
    git -C "$source" diff --no-ext-diff --binary HEAD -- > "$patch"
    jq -n --arg name "$name" --arg origin "$origin" --arg revision "$revision" \
        --arg tree "$tree" --slurpfile notices "$records" \
        '{name:$name,origin:$origin,revision:$revision,tree:$tree,notices:$notices[0]}' \
        > "$TEMP_DIR/$name.json"
    if [ -s "$patch" ]; then
        cp "$patch" "$destination/$name/source.patch"
        jq --arg path "$name/source.patch" --arg sha "$(sha256 "$patch")" \
            '. + {source_patch:{path:$path,sha256:$sha}}' "$TEMP_DIR/$name.json" \
            > "$TEMP_DIR/$name.next"
        mv "$TEMP_DIR/$name.next" "$TEMP_DIR/$name.json"
    fi
}

verify() {
    local directory=$1 path expected actual expected_files actual_files
    [[ -d "$directory" && ! -L "$directory" ]] || fail "missing notice directory: $directory"
    [ -z "$(find "$directory" ! -type f ! -type d -print -quit)" ] ||
        fail "nonregular notice payload: $directory"
    jq -e '
        def relative: type == "string" and length > 0 and
            (test("^/|(^|/)\\.\\.?(/|$)|[[:cntrl:]]") | not);
        def digest: type == "string" and test("^[0-9a-f]{64}$");
        def revision: type == "string" and test("^[0-9a-f]{40}([0-9a-f]{24})?$");
        (keys == ["components","schema_version"]) and .schema_version == 1 and
        (.components | type == "array" and length == 2) and
        ([.components[].name] | sort == ["OpenSSL","openssl-spm"]) and
        all(.components[]; . as $component |
            ((keys - ["source_patch"]) | sort == ["name","notices","origin","revision","tree"]) and
            (.origin | type == "string" and length > 0) and
            (.revision | revision) and (.tree | revision) and
            (.notices | type == "array" and length > 0) and
            all(.notices[]; keys == ["path","sha256","source_path"] and
                (.source_path | relative) and (.path | relative) and (.sha256 | digest) and
                .path == ($component.name + "/" + .source_path)) and
            any(.notices[]; .source_path | test("^(LICENSE|LICENCE|COPYING)")) and
            ((has("source_patch") | not) or
             (has("source_patch") and (.source_patch | keys == ["path","sha256"] and
                .path == ($component.name + "/source.patch") and (.sha256 | digest)))))
    ' "$directory/manifest.json" >/dev/null || fail "invalid notice manifest: $directory"
    while IFS=$'\t' read -r path expected; do
        [[ -f "$directory/$path" && ! -L "$directory/$path" ]] || fail "missing notice: $path"
        actual=$(sha256 "$directory/$path")
        [ "$actual" = "$expected" ] || fail "notice digest differs: $path"
    done < <(jq -r '.components[] | (.notices[] , .source_patch? // empty) | [.path,.sha256] | @tsv' \
        "$directory/manifest.json")
    expected_files=$(jq -r '["manifest.json"] + [.components[] | .notices[].path, .source_patch?.path // empty] | sort | .[]' \
        "$directory/manifest.json")
    actual_files=$(cd "$directory" && find . -type f | sed 's|^./||' | LC_ALL=C sort)
    [ "$expected_files" = "$actual_files" ] || fail "notice payload is not closed by its manifest"
}

command -v jq >/dev/null || fail "jq is required to package OpenSSL notices"
case "${1:-}" in
    stage)
        [ "$#" = 3 ] || fail "usage: $0 stage <compiled-source> <notice-directory>"
        [ ! -e "$3" ] || fail "notice destination already exists: $3"
        TEMP_DIR=$(mktemp -d)
        trap 'rm -rf "$TEMP_DIR"' EXIT
        mkdir -p "$3"
        stage_component "$2" OpenSSL "$3"
        stage_component "$ROOT_DIR" openssl-spm "$3"
        jq -n -S --slurpfile openssl "$TEMP_DIR/OpenSSL.json" \
            --slurpfile wrapper "$TEMP_DIR/openssl-spm.json" \
            '{schema_version:1,components:[$openssl[0],$wrapper[0]]}' > "$3/manifest.json"
        verify "$3"
        ;;
    verify)
        [ "$#" = 2 ] || fail "usage: $0 verify <notice-directory>"
        verify "$2"
        ;;
    compare)
        [ "$#" = 3 ] || fail "usage: $0 compare <notice-directory> <notice-directory>"
        verify "$2"
        verify "$3"
        diff -r "$2" "$3" || fail "slice source or notice context differs"
        ;;
    *) fail "usage: $0 {stage|verify|compare} ..." ;;
esac
