#!/bin/bash

if [ -z $1 ]; then
    echo "No additional language packs requested."
else
    langs=$( echo $1 | tr "," "\n")
    install_string=""
    for lang in $langs
    do
        install_string+=" tesseract-ocr-${lang}"
    done
    echo "Installing additional language packs..."
    apt update && apt install $install_string -y
fi

/opt/jetty/bin/jetty.sh run