#!/bin/bash
set -e

git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"

flutter doctor
flutter pub get
flutter build web --release
