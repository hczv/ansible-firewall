#!/usr/bin/env bash
# Bash strict mode: https://github.com/guettli/bash-strict-mode
set -eo pipefail
trap 'echo -e "\n Error: A command has failed. Exiting the script. Last command was: $BASH_COMMAND"; exit 1' ERR

config_path=/etc/nftables_urls.conf
nftables_dir_path="/etc/nftables.d"
download_path=/tmp/nftables_url
reload_nftables=false

function log() {
    local LOG_TIMESTAMP
    LOG_TIMESTAMP=$(date --iso-8601=seconds)
    echo -e "${LOG_TIMESTAMP}: ${1}" >&2
}

# Compares hashes of two files and returns true if they are the same, false otherwise.
# Usage: cmp <current_hash> <previous_file>
cmp() {
    file1=$(sha256sum "$1" | awk '{print $1}')
    file2=$(sha256sum "$2" | awk '{print $1}')
    if [ "$file1" == "$file2" ]; then
        return 0
    else
        return 1
    fi
}

generate_nftables_file() {
    local name="$1" set_download_path="$2"
    local nftables_set_location="$nftables_dir_path/$name.conf"

    {
        printf "add element ip filter %s { " "$name"
        awk '
          BEGIN {
            octet="(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])"
            cidr="(/([0-9]|[1-2][0-9]|3[0-2]))?"
            ip4cidr="^" octet "\\." octet "\\." octet "\\." octet cidr "$"
          }
          $0 ~ ip4cidr { ips[NR]=$0 }
          END {
            for (i=1; i<=NR; i++) {
              if (ips[i] != "") {
                printf "%s%s", (count++ ? "," : ""), ips[i]
              }
            }
            print ""
          }
        ' "$set_download_path"/*
        echo " }"
    } > "$nftables_set_location"
    log "Saved nftables set to $nftables_set_location"
}

mkdir -p "$download_path"

# Read config file with error checking
if ! jq -c '.[]' "$config_path" > /dev/null; then
    log "Error: Failed to parse config file at $config_path"
    exit 1
fi

jq -c '.[]' "$config_path" | while read -r line; do
    log "Processing: $line"

    name=$(jq -r '.name' <<<"$line")
    mapfile -t urls < <(jq -r '.urls[]' <<<"$line")

    set_download_path="$download_path/$name"
    mkdir -p "$set_download_path"

    # Remove previous old files
    rm -f "$set_download_path"/*.old

    # Move old files
    for f in "$set_download_path"/*; do
        [[ -f "$f" ]] && mv -- "$f" "${f%.*}.old"
    done

    generate_nftables_file=false
    for url in "${urls[@]}"; do
        output_file_name=$(basename "${url}")
        download_file_location="$set_download_path/$output_file_name.list"
        old_file_location="$set_download_path/$output_file_name.old"

        log "Downloading list: $url to $download_file_location"
        if ! curl -f --silent --show-error -o "$download_file_location" -L "$url"; then
            log "Error: Failed to download $url - skipping"
            continue
        fi

        if [[ -f "$old_file_location" ]]; then
            # Compare new file with existing one
            log "Comparing downloaded file: $download_file_location with $old_file_location"
            if ! cmp "$old_file_location" "$download_file_location"; then
                log "Downloaded file has changes"
                generate_nftables_file=true
                reload_nftables=true
            else
                log "Files are identical, skipping update."
            fi
        else
            generate_nftables_file=true
            reload_nftables=true
        fi
    done

    if [[ "$generate_nftables_file" == "true" || ! -f "$nftables_dir_path/$name.conf" ]]; then
        log "Generating nftables file \"$nftables_dir_path/$name.conf\""
        generate_nftables_file $name $set_download_path
    else
        log "Skipping generating nftables file \"$nftables_dir_path/$name.conf\""
    fi

done

if [[ "$reload_nftables" == "true" && "$1" != "no_reload" ]]; then
    log "Reloading nftables"
    systemctl restart nftables
fi
