#!/bin/zsh
# App Store用スクリーンショットを docs/screenshots/v2 に保存する（先に Debug ビルドしておく）
D=${SIM:-167E293A-36EA-4A57-926D-0CFBC22AA0D9}
APP=build/Build/Products/Debug-iphonesimulator/HojoWatch.app
OUT=docs/screenshots/v2
mkdir -p $OUT
xcrun simctl boot $D 2>/dev/null
xcrun simctl status_bar $D override --time 9:41 --batteryState charged --batteryLevel 100
xcrun simctl uninstall $D com.sidebiz.hojowatch 2>/dev/null
xcrun simctl install $D $APP
shot() {
  local name=$1 wait=$2; shift 2
  xcrun simctl launch --terminate-running-process $D com.sidebiz.hojowatch ${=@} >/dev/null
  sleep $wait
  xcrun simctl io $D screenshot $OUT/$name.png >/dev/null 2>&1
}
shot 1_foryou 12 "-demoProfile"
shot 2_watch 5 "-demoWatch"
shot 3_detail 6 "-demoWatch -openDetail"
shot 4_search 10 "-autoSearch"
shot 5_documents 6 "-demoWatch -openDetail -scrollBottom"
