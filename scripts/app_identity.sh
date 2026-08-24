#!/usr/bin/env bash

# Canonical macOS development identity. Keep every build/run script on the
# same bundle name, identifier and designated requirement so macOS TCC grants
# survive local ad-hoc rebuilds.
MAC_APP_PRODUCT_NAME="SideScreen Flow"
MAC_APP_BUNDLE_NAME="SideScreen Flow.app"
MAC_APP_BUNDLE_ID="com.mikolajwargowski.sidescreenflow"
MAC_APP_EXECUTABLE="SideScreen"
MAC_APP_REQUIREMENT="designated => identifier \"$MAC_APP_BUNDLE_ID\""
