#!/bin/bash

# Urls
readonly base_url="https://bimasislam.kemenag.go.id"
readonly api_url="${base_url}/ajax/getShalatbln"

# App Info
readonly app_version="0.1"
readonly app_title="Sholli v${app_version}"

# Malang Coordinates
readonly x_coord="c74d97b01eae257e44aa9d5bade97baf"
readonly y_coord="06138bc5af6023646ede0e1f7c1eac75"

root_folder="${HOME}/.local/share/$(basename "$0")"
audio_dir="${root_folder}/audio"
adzan_file="${audio_dir}/adzan.mp3"

notify() { notify-send "$@" "$app_title"; }
play_adzan() { [[ -f $adzan_file ]] && paplay "$adzan_file"; }
play_notification() {
    audio_file="${audio_dir}/${1}-${2}menit.mp3"
    [[ -f $audio_file ]] && paplay "$audio_file"
}

usage() {
    printf '%s\n' "Usage: $(basename "$0") <fetch|check>" \
        " " \
        "Commands:" \
        "  fetch    Fetches updated prayer times." \
        "  check    Checks for prayer time." >&2
    exit
}

time_delta() {
    local compare="$1"
    local current="${2:-$(date +%s)}"

    echo $(( compare - current ))
}

get_jadwal() {
    local bulan="${1:-$(date +%m)}"
    local tahun="${2:-$(date +%Y)}"
    local cookie output_file

    cookie=$(mktemp -u /tmp/XXXX)
    output_file="${bulan}-${tahun}.json"

    # Get PHP sesskey
    curl -Sso /dev/null -c "$cookie" "$base_url"

    # Fetch data
    printf '%s\n' "Getting prayer times data..."
    curl -Ss -b "$cookie" "$api_url" \
        --data "x=${x_coord}" \
        --data "y=${y_coord}" \
        --data "bln=${bulan}" \
        --data "thn=${tahun}" | jq > "${root_folder}/${output_file}"

    printf '%s\n' "Prayer time data has been saved as \"${output_file}\" in \"${root_folder}\""

    rm -f "$cookie"
}

check_time() {
    local bulan tahun data_file cur_date
    local next_event next_time reminders time_keeper

    cur_date=${1:-$(date +%Y-%m-%d)}
    time_keeper="/tmp/$(basename "$0")_next"
    reminders=(15 5)

    bulan=$(date -d "$cur_date" +%m)
    tahun=$(date -d "$cur_date" +%Y)

    data_file="${root_folder}/${bulan}-${tahun}.json"

    [[ ! -f $data_file ]] && get_jadwal "$bulan" "$tahun"

    time_keys="$(jq -r ".data.\"$cur_date\" | del(.tanggal, .imsak, .terbit, .dhuha) | to_entries[].key" "$data_file")"
    
    min_delta=9999999

    if [[ ! -f $time_keeper ]]; then
        for key in $time_keys; do
            cur_time=$(date +%s)
            target_time=$(date -d "$cur_date $(jq -r ".data.\"$cur_date\".$key" "$data_file")" +%s)

            delta=$(time_delta "$target_time" "$cur_time")
            #echo "$cur_date => $key | d: $delta | da: ${delta_abs:-null} | ne: ${next_event:-null} | md: ${min_delta:-null} | nt: ${next_time:-null}"
            [[ $delta -lt 0 ]] && continue

            # Find the smallest delta to get the next nearest prayer time
            if [[ $delta -lt $min_delta ]]; then
                next_event="$key"
                min_delta="$delta"
                next_epoch="$target_time"
                next_time="$(date -d "@$target_time" +%k:%M)"
            fi

            #echo "$cur_date => $key | d: $delta | da: ${delta_abs:-null} | ne: ${next_event:-null} | md: ${min_delta:-null} | nt: ${next_time:-null} | tt: $target_time" 
        done

        if [[ "$next_epoch" && "$next_event" ]]; then
            printf '%s\n' "$next_epoch" "$next_event" > "$time_keeper"
        fi
    else
        target_time="$(head -1 "$time_keeper")"
        next_event="$(tail -1 "$time_keeper")"
        next_time=$(date -d @"$target_time" +%k:%M)
    fi

    for m in "${reminders[@]}"; do
        secs=$((m*60))

        delta=$(time_delta "$target_time")
        [[ $delta -lt 0 ]] && continue

        if [[ $delta -le $secs ]]; then
            minutes_remaining=$(( delta / 60 ))
            notify "Memasuki waktu ${next_event} dalam ${minutes_remaining} menit. ${next_event}: ${next_time}"
            play_notification "$next_event" "$m"
        fi
    done

    # If it's the time, then play adzan
    if [[ $(date +%k:%M) == "$next_time" ]]; then
        notify "Waktunya sholat ${next_event}"
        play_adzan
        rm "$time_keeper"
    # Otherwise,
    # If next event is empty, means today's prayer has already been all passed
    elif [[ -z "$next_event" ]]; then
        check_time "$(date -d "$cur_date + 1 day" +%Y-%m-%d)"
    # Otherwise,
    # Prints the next prayer time
    else
        echo "Waktu sholat selanjutnya: ${next_event^^} @$next_time"
    fi
}

main() {
    cmd="$1"
    shift

    mkdir -p "$audio_dir" 2> /dev/null

    [[ -z "$cmd" ]] && usage

    case "$cmd" in
        check) check_time ;;
        fetch) get_jadwal "$@" ;;
        *) usage ;;
    esac
}

main "$@"
