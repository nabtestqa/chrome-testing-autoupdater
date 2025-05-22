#!/bin/bash

PWD=$(pwd)
MTO="/usr/local/bin"

rm "$MTO/chrome-testing"
ln -s "$PWD/chrome-testing/chrome-linux64/chrome" "$MTO/chrome-testing"

rm "$MTO/chrome-testing-headless"
ln -s "$PWD/chrome-testing-headless-shell/chrome-headless-shell-linux64/chrome-headless-shell" "$MTO/chrome-testing-headless"

rm "$MTO/chromedriver-testing"
ln -s "$PWD/chromedriver/chromedriver-linux64/chromedriver" "$MTO/chromedriver-testing"
