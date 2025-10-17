#!/bin/zsh

#  build.zsh
#  AppPruner
#
#  Created by Tobias Almén on 2025-10-17.
#

check_exit_code() {
    if [ "$1" != "0" ]; then
        echo "$2: $1" 1>&2
        exit 1
    fi
}


create_pkg() {

    local identifier="$1"
    local version="$2"
    local input_path="$3"
    local output_path="$4"
    local install_location="$5"
    
    pkgbuild --root "${input_path}/payload" \
        --install-location "${install_location}" \
        --scripts "${input_path}/scripts" \
        --identifier "${identifier}" \
        --version "${version}" \
        --sign "${SIGNING_IDENTITY}" \
        "${output_path}" >/dev/null 2>&1
        
    check_exit_code "$?" "Error creating pkg"
}

generate_dist_file() {
    local bundle_identifier="$1"
    local build_version="$2"
    local output_file="$3"
    local pkg_type="$4"
    local pkg_ref_path="AppPruner${pkg_type}-${build_version}.pkg"

    cat <<EOF > "$output_file"
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>${APP_NAME}</title>
  <options customize="never" require-scripts="false" hostArchitectures="x86_64,arm64"/>
  <volume-check>
    <allowed-os-versions>
        <os-version min="14"/>
    </allowed-os-versions>
  </volume-check>
  <choices-outline>
    <line choice="${bundle_identifier}"/>
  </choices-outline>
  <choice id="${bundle_identifier}" title="${APP_NAME}">
    <pkg-ref id="${bundle_identifier}"/>
  </choice>
  <pkg-ref id="${bundle_identifier}" version="${build_version}" onConclusion="none">
    ${pkg_ref_path}
  </pkg-ref>
</installer-gui-script>
EOF
}

run_product_build_sign() {
    
    local package_path="$1"
    local package="$2"
    
    productbuild --distribution "$DIST_FILE" \
        --package-path "${package_path}" \
        "${package}_dist.pkg"
        
    check_exit_code "$?" "Error running productbuild"

    # Sign package
    productsign --sign "${SIGNING_IDENTITY}" \
        "${package}_dist.pkg" \
        "${package}.pkg"
        
    check_exit_code "$?" "Error running productsign"
}

notarize_and_staple() {
    local pkg_path="$1"
    $XCODE_NOTARY_PATH submit "$pkg_path" --keychain-profile "${KEYCHAIN_PROFILE}" --wait
    check_exit_code "$?" "Error notarizing pkg"
    $XCODE_STAPLER_PATH staple "$pkg_path"
    check_exit_code "$?" "Error stapling pkg"
}

# Exit on error
set -e

CONFIGURATION="$1"
APP_NAME="AppPruner"
BUNDLE_IDENTIFIER="com.github.almenscorner.AppPruner"
SIGNING_IDENTITY="Developer ID Installer: ANDERS TOBIAS ALMÉN (H92SB6Z7S4)"
SIGNING_IDENTITY_APP="Developer ID Application: ANDERS TOBIAS ALMÉN (H92SB6Z7S4)"
KEYCHAIN_PROFILE="AppPruner"
XCODE_PATH="/Applications/Xcode.app"
TEAM_ID="H92SB6Z7S4"

if [ -z "$CONFIGURATION" ]; then
    echo "Usage: $0 <Configuration>"
    echo "Example: $0 Release"
    exit 1
fi

XCODE_NOTARY_PATH="$XCODE_PATH/Contents/Developer/usr/bin/notarytool"
XCODE_STAPLER_PATH="$XCODE_PATH/Contents/Developer/usr/bin/stapler"
XCODE_BUILD_PATH="$XCODE_PATH/Contents/Developer/usr/bin/xcodebuild"
TOOLSDIR=$(dirname $0)
BUILDSDIR="$TOOLSDIR/build"
PKGBUILDDIR="$BUILDSDIR/pkgbuild"
OUTPUTSDIR="$TOOLSDIR/outputs"
RELEASEDIR="$TOOLSDIR/release"
PKG_PATH="$TOOLSDIR/AppPruner/pkgbuild"
DIST_FILE="$BUILDSDIR/Distribution.xml"
CURRENT_AP_MAIN_BUILD_VERSION=$(/usr/libexec/PlistBuddy -c Print:CFBundleVersion $TOOLSDIR/AppPruner/Info.plist)
NEWSUBBUILD=$((80620 + $(git rev-parse HEAD~0 | xargs -I{} git rev-list --count {})))

# automate the build version bump
AUTOMATED_AP_BUILD="$CURRENT_AP_MAIN_BUILD_VERSION.$NEWSUBBUILD"

# Ensure Xcode is set to run-time
sudo xcode-select -s "$XCODE_PATH"

# Resolve package dependencies
$XCODE_BUILD_PATH -resolvePackageDependencies

if [ "$CONFIGURATION" = "Release" ]; then
    # Setup notary item
    $XCODE_NOTARY_PATH store-credentials --apple-id "tobias.almennn@gmail.com" --team-id "H92SB6Z7S4" --password "$2" AppPruner
fi

# Create release folder
if [ -e $RELEASEDIR ]; then
/bin/rm -rf $RELEASEDIR
fi
/bin/mkdir -p "$RELEASEDIR"

# Create build folder
if [ -e $BUILDSDIR ]; then
/bin/rm -rf $BUILDSDIR
fi
/bin/mkdir -p "$BUILDSDIR"

# build Support Companion
echo "=========== Building AppPruner $CONFIGURATION ==========="

echo "$AUTOMATED_AP_BUILD" > "$BUILDSDIR/build_info.txt"
echo "$CURRENT_AP_MAIN_BUILD_VERSION" > "$BUILDSDIR/build_info_main.txt"

$XCODE_BUILD_PATH clean archive -scheme AppPruner -project "$TOOLSDIR/AppPruner.xcodeproj" \
-configuration $CONFIGURATION \
CODE_SIGN_IDENTITY="$SIGNING_IDENTITY_APP" \
OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime --deep" \
DEVELOPMENT_TEAM="$TEAM_ID" \
ARCHS="arm64 x86_64" \
ONLY_ACTIVE_ARCH=NO \
-archivePath "$BUILDSDIR/AppPruner" >/dev/null 2>&1

check_exit_code "$?" "Error running xcodebuild"

cp -r $PKG_PATH "$BUILDSDIR/pkgbuild"

# move the app to the payload folder
echo "Moving AppPruner.app to payload folder"
if [ -d "$PKGBUILDDIR/payload/Applications/AppPruner.app" ]; then
rm -r "$PKGBUILDDIR/payload/Applications/AppPruner.app"
fi

mkdir "$PKGBUILDDIR/payload/Applications"
cp -R "${BUILDSDIR}/AppPruner.xcarchive/Products/Applications/AppPruner.app" "$PKGBUILDDIR/payload/Applications/AppPruner.app"

# set the plist version to AUTOMATED_AP_BUILD
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $AUTOMATED_AP_BUILD" "$PKGBUILDDIR/payload/Applications/AppPruner.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $AUTOMATED_AP_BUILD" "$PKGBUILDDIR/payload/Applications/AppPruner.app/Contents/Info.plist"

codesign --force --options runtime --deep --timestamp --sign $SIGNING_IDENTITY_APP "$PKGBUILDDIR/payload/Applications/AppPruner.app"

# Build and export pkg
create_pkg $BUNDLE_IDENTIFIER $AUTOMATED_AP_BUILD $PKGBUILDDIR "${BUILDSDIR}/AppPruner-${AUTOMATED_AP_BUILD}.pkg" "/"
    
generate_dist_file $BUNDLE_IDENTIFIER $AUTOMATED_AP_BUILD $DIST_FILE

run_product_build_sign $BUILDSDIR "${BUILDSDIR}/${APP_NAME}-${AUTOMATED_AP_BUILD}"

notarize_and_staple "${BUILDSDIR}/${APP_NAME}-${AUTOMATED_AP_BUILD}.pkg"

cp "${BUILDSDIR}/${APP_NAME}-${AUTOMATED_AP_BUILD}.pkg" "${RELEASEDIR}/${APP_NAME}-${AUTOMATED_AP_BUILD}.pkg"

echo "Build complete: ${RELEASEDIR}/${APP_NAME}-${AUTOMATED_AP_BUILD}.pkg"

rm -f $DIST_FILE
rm -r $PKGBUILDDIR
