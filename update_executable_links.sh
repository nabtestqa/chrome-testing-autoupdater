#!/bin/bash

PWD=$(pwd)
MTO="/usr/local/bin"

rm "$MTO/chrome"
ln -s "$PWD/chrome-testing/chrome-linux64/chrome" "$MTO/chrome"

rm "$MTO/chrome-headless-shell"
ln -s "$PWD/chrome-testing-headless-shell/chrome-headless-shell-linux64/chrome-headless-shell" "$MTO/chrome-headless-shell"

rm "$MTO/chromedriver"
ln -s "$PWD/chromedriver/chromedriver-linux64/chromedriver" "$MTO/chromedriver"
