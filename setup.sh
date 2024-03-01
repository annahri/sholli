#!/bin/bash

echo "Mengunduh file adzan..."
mkdir -p ~/.local/share/sholli
git clone -b setup https://github.com/annahri/sholli.git ~/.local/share/sholli

echo "Menginstal sholli.sh..."
for path in ~/.bin ~/.local/bin; do
    test -d "$path" || continue

    curl -Sso "${path}/sholli" "https://raw.githubusercontent.com/annahri/sholli/main/sholli"
    chmod +x "${path}/sholli"
    break
done

echo "Selesai"
