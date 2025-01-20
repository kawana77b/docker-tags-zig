#!/bin/bash

APP_NAME="docker-tags"

rm -rf zig-out

zig build -Dtarget=x86_64-windows --release=small --prefix-exe-dir dist/windows
zig build -Dtarget=x86_64-linux --release=small --prefix-exe-dir dist/linux
zig build -Dtarget=aarch64-macos --release=small --prefix-exe-dir dist/macos

CWD=$(pwd)

echo "Building distributable packages"

echo "Linux x86_64"
cd $CWD
DIST="./zig-out/dist/linux"
cp README.md $DIST
cp LICENSE $DIST
cd $DIST && zip -r "${APP_NAME}_linux_x86_64.zip" ./*

echo "Windows x86_64"
cd $CWD
DIST="./zig-out/dist/windows"
cp README.md $DIST
cp LICENSE $DIST
cd $DIST && zip -r "${APP_NAME}_windows_x86_64.zip" ./*

echo "MacOS aarch64"
cd $CWD
DIST="./zig-out/dist/macos"
cp README.md $DIST
cp LICENSE $DIST
cd $DIST && zip -r "${APP_NAME}_macos_aarch64.zip" ./*

echo "...zip created"