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
    file2=$(sha256sum "$1" | awk '{print $1}')
    if [ "$file1" == "$file2" ]; then
        return 0
    else
        return 1
    fi
}

generate_nftables_file() {
    name=$1
    set_download_path=$2

    nftables_set_location="$nftables_dir_path/$name.conf"
    echo -n "add element ip filter ${name} { " > "$nftables_set_location"
    awk '
      BEGIN {
        octet="(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])"
        cidr="(/([0-9]|[1-2][0-9]|3[0-2]))?"
        ip4cidr="^" octet "\\." octet "\\." octet "\\." octet cidr "$"
      }
      $0 ~ ip4cidr {
        if (count++ > 0) printf ","
        printf "%s", $0
      }
      END { print "" }
    ' $set_download_path/* >> "$nftables_set_location"
    echo " } " >> "$nftables_set_location"
    log "Saved ${#valid_ips[@]} valid IPs to $nftables_set_location"

}

mkdir -p "$download_path"

# Read config file with error checking
if ! jq -c '.[]' "$config_path" > /dev/null; then
    log "Error: Failed to parse config file at $config_path"
    exit 1
fi

jq -c '.[]' "$config_path" | while read -r line;
do
    log "Processing: $line"

    # Parse JSON with error checking
    name=$(echo "$line" | jq -r '.name')
    urls=$(echo "$line" | jq -r '.urls')

    set_download_path="$download_path/$name"
    mkdir -p "$set_download_path"

    # Remove previous old files
    rm -f "$set_download_path/*.old"

    # Move old files
    find "$set_download_path" -type f ! -name '*.old' -exec sh -c 'mv "$0" "${0%.*}".old' {} \;

    generate_nftables_file=false
    while read -r url;
    do
        formatted_url=$(echo $url | tr -d '"' )
        output_file_name=$(basename "${formatted_url}")
        download_file_location="$set_download_path/$output_file_name.list"
        old_file_location="$set_download_path/$output_file_name.old"

        log "Downloading list: $formatted_url to $download_file_location"
        curl -f --silent --show-error -o "$download_file_location" -O -L "$formatted_url"
        if [[ $? != 0 ]]; then
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
    done < <(echo "$urls" | jq -c '.[]')

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
