#!/bin/bash

echo "Mengunduh file adzan..."
mkdir -p ~/.local/share/sholli
git clone -b setup https://github.com/annahri/sholli.git ~/.local/share/sholli

for path in ~/.bin ~/.local/bin; do
    grep -q "$path" <<< "$PATH" || continue
    test -d "$path" || mkdir "$path"

    echo "Menginstal sholli.sh pada $path"
    curl -Sso "${path}/sholli" "https://raw.githubusercontent.com/annahri/sholli/main/sholli"
    chmod +x "${path}/sholli"

    echo "Selesai"
    exit
done

echo "Silakan unduh sholli.sh secara manual:"
echo "  curl -Ss https://raw.githubusercontent.com/annahri/sholli/main/setup.sh"
echo "dan letakkan pada \$PATH."
