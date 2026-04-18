#!/bin/bash
# Script to manually download ktlint jar to the expected directory
KT_VERSION="0.48.2"
KT_DIR="build/ktlint"
KT_JAR="ktlint-$KT_VERSION.jar"
KT_URL="https://github.com/pinterest/ktlint/releases/download/$KT_VERSION/ktlint.jar"

mkdir -p $KT_DIR
curl -L $KT_URL -o $KT_DIR/$KT_JAR

echo "ktlint jar downloaded to $KT_DIR/$KT_JAR"
