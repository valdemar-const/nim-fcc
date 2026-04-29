#!/usr/bin/env bash

mkdir -p ./resources

wget https://flatassembler.net/fasm2.zip      -O ./resources/fasm2.zip
wget https://flatassembler.net/fasmg.l5p0.zip -O ./resources/fasmg.l5p0.zip

(cd ./resources && mkdir -p fasm2      && cd ./fasm2      && unzip ../fasm2.zip)
(cd ./resources && mkdir -p fasmg.l5p0 && cd ./fasmg.l5p0 && unzip ../fasmg.l5p0.zip)

rm ./resources/*.zip
