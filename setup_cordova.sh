#!/bin/bash
rm -r cordova
cordova create cordova co.mwater.clientapp mWater
cp app/cordova/config.xml cordova
cp app/img/icon.png cordova
cd cordova
cordova platform add android
cordova plugin add org.apache.cordova.device
cordova plugin add https://git-wip-us.apache.org/repos/asf/cordova-plugin-file.git
cordova plugin add https://git-wip-us.apache.org/repos/asf/cordova-plugin-file-transfer.git
cordova plugin add org.apache.cordova.device-orientation
cordova plugin add org.apache.cordova.network-information
cordova plugin add https://github.com/mWater/cordova-plugin-wezka-nativecamera.git
cordova plugin add https://github.com/mWater/OpenCVActivityPlugin.git
cordova plugin add https://github.com/mWater/cordova-plugin-acra.git

# Bluetooth plugin
cordova plugin add https://github.com/tanelih/phonegap-bluetooth-plugin

rm platforms/android/res/drawable-hdpi/icon.png
rm platforms/android/res/drawable-ldpi/icon.png
rm platforms/android/res/drawable-mdpi/icon.png
rm platforms/android/res/drawable-xhdpi/icon.png
rm -r platforms/android/assets/www/*
rm -r www/*

echo "key.store=/home/clayton/.ssh/mwater.keystore" >> ./platforms/android/ant.properties
echo "key.alias=mwater" >> ./platforms/android/ant.properties
echo 'TODO: Add android:name="co.mwater.acraplugin.MyApplication" to application element of AndroidManifest.xml'
echo 'TODO: Add <uses-feature android:name="android.hardware.camera" android:required="false" /> to AndroidManifest.xml'
echo 'TODO: Add <uses-feature android:name="android.hardware.bluetooth" android:required="false" /> to AndroidManifest.xml'
cd ..