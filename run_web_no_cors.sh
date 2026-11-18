#!/bin/bash
echo "Starting Flutter Web with CORS / Web Security disabled..."
flutter run -d chrome --web-browser-flag "--disable-web-security"
