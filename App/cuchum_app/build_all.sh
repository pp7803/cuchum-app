#!/bin/bash

# Build release artifacts for Android APK, iOS IPA (no-codesign), and macOS DMG.
# Usage: ./build_all.sh [android|ios|mac|all]
# Default: all

set -u
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET="${1:-all}"
FINAL_DIR="build/final"
APP_NAME="CucHum"

if ! command -v flutter >/dev/null 2>&1; then
  echo -e "${RED}Flutter is not installed or not in PATH.${NC}"
  exit 1
fi

if [[ "${TARGET}" != "android" && "${TARGET}" != "ios" && "${TARGET}" != "mac" && "${TARGET}" != "all" ]]; then
  echo -e "${RED}Invalid target: ${TARGET}${NC}"
  echo "Usage: ./build_all.sh [android|ios|mac|all]"
  exit 1
fi

VERSION_LINE=$(grep '^version:' pubspec.yaml | head -n 1 | awk '{print $2}')
if [[ -z "${VERSION_LINE}" ]]; then
  echo -e "${RED}Cannot read version from pubspec.yaml${NC}"
  exit 1
fi

if [[ "${VERSION_LINE}" == *"+"* ]]; then
  VERSION="${VERSION_LINE%%+*}"
  BUILD_NUM="${VERSION_LINE##*+}"
else
  VERSION="${VERSION_LINE}"
  BUILD_NUM="1"
fi

PREFIX="${APP_NAME}_${VERSION}_${BUILD_NUM}"
FAILED=()
GENERATED=()

print_header() {
  echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║      CucHum Build Script v${VERSION}+${BUILD_NUM}      ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
  echo
}

prepare() {
  echo -e "${YELLOW}Cleaning previous builds...${NC}"
  flutter clean || {
    echo -e "${RED}flutter clean failed${NC}"
    exit 1
  }

  echo -e "${YELLOW}Fetching dependencies...${NC}"
  flutter pub get || {
    echo -e "${RED}flutter pub get failed${NC}"
    exit 1
  }

  rm -rf "${FINAL_DIR}"
  mkdir -p "${FINAL_DIR}"
  echo
}

package_ipa_from_archive() {
  local archive_path="$1"
  local ipa_out="$2"

  if ! command -v zip >/dev/null 2>&1; then
    echo -e "${RED}zip command not found, cannot package IPA.${NC}"
    return 1
  fi

  local app_bundle
  app_bundle=$(find "${archive_path}/Products/Applications" -maxdepth 1 -type d -name "*.app" | head -n 1)

  if [[ -z "${app_bundle}" || ! -d "${app_bundle}" ]]; then
    echo -e "${RED}No .app found inside archive: ${archive_path}${NC}"
    return 1
  fi

  local temp_dir
  temp_dir=$(mktemp -d)
  mkdir -p "${temp_dir}/Payload"
  cp -R "${app_bundle}" "${temp_dir}/Payload/"

  (
    cd "${temp_dir}" || exit 1
    zip -qry "${ipa_out}" Payload
  )
  local zip_status=$?
  rm -rf "${temp_dir}"

  if [[ ${zip_status} -ne 0 ]]; then
    echo -e "${RED}Failed to package IPA from archive.${NC}"
    return 1
  fi

  return 0
}

build_macos_unsigned_fallback() {
  echo -e "${YELLOW}Retrying macOS build without code signing...${NC}"

  if ! flutter build macos --release --config-only; then
    return 1
  fi

  mkdir -p build/macos/Logs/Build build/macos/Logs/Localization build/macos/Logs/Launch build/macos/Logs/Package build/macos/Logs/Test

  xcodebuild \
    -workspace macos/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -derivedDataPath build/macos_unsigned \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM=""
}

build_android() {
  echo -e "${BLUE}Building Android APK (release)...${NC}"
  if flutter build apk --release; then
    local apk_src="build/app/outputs/flutter-apk/app-release.apk"
    local apk_dst="${FINAL_DIR}/${PREFIX}_android.apk"

    if [[ -f "${apk_src}" ]]; then
      cp "${apk_src}" "${apk_dst}"
      GENERATED+=("${apk_dst}")
      echo -e "${GREEN}APK created: ${apk_dst}${NC}"
    else
      FAILED+=("android (apk not found)")
      echo -e "${RED}APK file not found at ${apk_src}${NC}"
    fi
  else
    FAILED+=("android")
    echo -e "${RED}Android build failed${NC}"
  fi
  echo
}

build_ios() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    FAILED+=("ios (requires macOS)")
    echo -e "${RED}Skipping iOS build: requires macOS${NC}"
    echo
    return
  fi

  echo -e "${BLUE}Building iOS IPA (release, no-codesign)...${NC}"
  if flutter build ipa --release --no-codesign; then
    local ipa_src
    ipa_src=$(find build/ios/ipa -maxdepth 1 -type f -name "*.ipa" 2>/dev/null | head -n 1)
    local ipa_dst="${FINAL_DIR}/${PREFIX}_ios_nocodesign.ipa"
    local ipa_dst_abs="$(pwd)/${ipa_dst}"

    if [[ -n "${ipa_src}" && -f "${ipa_src}" ]]; then
      cp "${ipa_src}" "${ipa_dst}"
      GENERATED+=("${ipa_dst}")
      echo -e "${GREEN}IPA created: ${ipa_dst}${NC}"
    else
      local archive_path="build/ios/archive/Runner.xcarchive"
      if [[ -d "${archive_path}" ]] && package_ipa_from_archive "${archive_path}" "${ipa_dst_abs}"; then
        GENERATED+=("${ipa_dst}")
        echo -e "${GREEN}IPA packaged from archive: ${ipa_dst}${NC}"
      else
        FAILED+=("ios (ipa not found)")
        echo -e "${RED}IPA file not found and archive packaging failed.${NC}"
      fi
    fi
  else
    FAILED+=("ios")
    echo -e "${RED}iOS build failed${NC}"
  fi
  echo
}

build_mac() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    FAILED+=("mac (requires macOS)")
    echo -e "${RED}Skipping macOS build: requires macOS${NC}"
    echo
    return
  fi

  if ! command -v hdiutil >/dev/null 2>&1; then
    FAILED+=("mac (hdiutil missing)")
    echo -e "${RED}Skipping DMG build: hdiutil not found${NC}"
    echo
    return
  fi

  echo -e "${BLUE}Building macOS app (release)...${NC}"

  local app_path=""
  if flutter build macos --release; then
    app_path=$(find build/macos/Build/Products/Release -maxdepth 1 -type d -name "*.app" | head -n 1)
  else
    if build_macos_unsigned_fallback; then
      app_path=$(find build/macos_unsigned/Build/Products/Release -maxdepth 1 -type d -name "*.app" | head -n 1)
    else
      FAILED+=("mac")
      echo -e "${RED}macOS build failed (including unsigned fallback).${NC}"
      echo
      return
    fi
  fi

  if [[ -z "${app_path}" || ! -d "${app_path}" ]]; then
    FAILED+=("mac (app bundle not found)")
    echo -e "${RED}No .app bundle found after macOS build.${NC}"
    echo
    return
  fi

  local dmg_dst="${FINAL_DIR}/${PREFIX}_macos.dmg"
  local staging_dir
  staging_dir=$(mktemp -d)

  cp -R "${app_path}" "${staging_dir}/"
  ln -s /Applications "${staging_dir}/Applications"

  if hdiutil create -volname "${APP_NAME}" -srcfolder "${staging_dir}" -ov -format UDZO "${dmg_dst}" >/dev/null; then
    GENERATED+=("${dmg_dst}")
    echo -e "${GREEN}DMG created: ${dmg_dst}${NC}"
  else
    FAILED+=("mac")
    echo -e "${RED}DMG creation failed${NC}"
  fi

  rm -rf "${staging_dir}"
  echo
}

print_summary() {
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo -e "${GREEN}All selected builds completed successfully!${NC}"
  else
    echo -e "${YELLOW}Build finished with failures:${NC} ${FAILED[*]}"
  fi

  if [[ ${#GENERATED[@]} -gt 0 ]]; then
    echo -e "${GREEN}Generated artifacts:${NC}"
    for artifact in "${GENERATED[@]}"; do
      echo " - ${artifact}"
    done
  else
    echo -e "${YELLOW}No artifacts generated.${NC}"
  fi

  echo -e "${BLUE}Output folder:${NC} ${FINAL_DIR}"
}

print_header
prepare

case "${TARGET}" in
  android)
    build_android
    ;;
  ios)
    build_ios
    ;;
  mac)
    build_mac
    ;;
  all)
    build_android
    build_ios
    build_mac
    ;;
esac

print_summary
