#
#  Copyright (c) Microsoft. All rights reserved.  
#  Licensed under the MIT license. See LICENSE file in the project root for full license information.
#
# ******************
#  **Pre-requistes**
# ******************
#
# Set the following environment variables which will be used for caching Cordova components.
# 	CORDOVA_CACHE
# 	GRADLE_USER_HOME
#
# For consistancy sake, it makes sense to also set the following environment variables for use with the base Cordova CLI as well:
#   CORDOVA_HOME=%CORDOVA_CACHE%\_cordova
#   PLUGMAN_HOME=%CORDOVA_CACHE%\_plugman
#
# Then set the following to get the script to run:
# 	ANT_HOME
#	JAVA_HOME
#	ANDROID_HOME
#	%ANT_HOME%\bin, nodejs, Git command line tools, and npm need to be in PATH

$versions = "4.3.0", "5.0.0", "5.1.0";
$platforms = "android", "windows", "wp8";
$plugins = @{	
			"com.microsoft.visualstudio.taco" = "https://github.com/Chuxel/taco-cordova-support-plugin.git"; 
			"cordova-plugin-whitelist" = "cordova-plugin-whitelist", "cordova-plugin-whitelist@1.0.0";
};
$plugnFetchCordovaVersion = "5.0.0";
$oneOffPlatforms = @{
	"android" = "android@3.7.2", "android@4.0.2"; 
};
$platformFetchCordovaVersion = "5.0.0";

$pwd = $(get-location)
Write-Host "Current location: $pwd"

if((!$env:ANT_HOME) -or (!$env:JAVA_HOME) -or (!$env:ANDROID_HOME))	 {
	Write-Host "ERROR: ANT_HOME, JAVA_HOME, and ANDROID_HOME environment variables must be set."
	exit 1;
}
if(!$env:CORDOVA_CACHE) {
	$env:CORDOVA_CACHE=$env:APPDATA + "\cordova-cache"
	Write-Host "WARNING: CORDOVA_CACHE not set - Setting to $env:CORDOVA_CACHE."
}

if(!$env:GRADLE_USER_HOME) {
	Write-Host "WARNING: GRADLE_USER_HOME not set - Will be in a user specific location."
}

Write-Host "Cordova CLI versions to cache: $versions"
Write-Host "Cordova pinned platforms to cache: $platforms"
Write-Host "Cordova un-pinned platforms to cache:"
foreach($key in $oneOffPlatforms.Keys) {
	$value = $oneOffPlatforms.Item($key)
	Write-Host "   $key - $value"
}
Write-Host "Cordova plugins to cache:"
foreach($key in $plugins.Keys) {
	$value = $plugins.Item($key)
	Write-Host "   $key - $value"
}
Write-Host "CORDOVA_CACHE: $env:CORDOVA_CACHE"
Write-Host "GRADLE_USER_HOME: $env:GRADLE_USER_HOME"

$origCH=$env:CORDOVA_HOME
Write-Host "Original CORDOVA_HOME: $origCH"
$env:CORDOVA_HOME=$env:CORDOVA_CACHE + "\_cordova";
Write-Host "Target CORDOVA_HOME: $env:CORDOVA_HOME"

$origPH=$env:PLUGMAN_HOME
Write-Host "Original PLUGMAN_HOME: $origPH"
$env:PLUGMAN_HOME=$env:CORDOVA_CACHE + "\_plugman";
Write-Host "Target PLUGMAN_HOME: $env:PLUGMAN_HOME"

if(Test-Path -Path $env:CORDOVA_CACHE) {
	Write-Host "WARNING: Cache folder already exists."
} else {
	mkdir $env:CORDOVA_CACHE
}

cd $env:CORDOVA_CACHE

echo "" > $pwd\stdout.txt

# Use rmdir since this does not hit "path too long" errors common when deleting node_module folders by full path. (Old tech FTW)
if(Test-Path -Path "tempProj") {
	cmd /c "rmdir /S /Q tempProj"
}

foreach($version in $versions) {
	Write-Host "Prepping Cordova $version"
	if(!(Test-Path -Path $version)) {
		mkdir $version;
	}
	$fullpath = (gi $version).fullname
	Write-Host "Path to install cordova-lib / Cordova CLI: $fullpath"
	cd $version
	# Grabbing both cordova-lib and cordova so developers can use Cordova either as a node module or a CLI
	npm install cordova-lib@$version 1>> $pwd\stdout.txt
	npm install cordova@$version 1>> $pwd\stdout.txt
	cd ..

	# Cache pinned platform version as approprate for this CLI version	
	Write-Host "Prepping project to cache pinned platform versions for Cordova $version"
	cmd /c "$fullpath\node_modules\.bin\cordova" create tempProj 1>> $pwd\stdout.txt
	cd tempProj
	foreach($platform in $platforms) {
		Write-Host "Caching pinned version of platform $platform in Cordova $version"
		cmd /c "$fullpath\node_modules\.bin\cordova" platform add $platform 1>> $pwd\stdout.txt
		if($platform -eq "android") {
				# We also need to build to ensure GRADLE_USER_HOME are prepped for Android
				Write-Host "Building to force depenedency acquistion for $platform in Cordova $version"
				cmd /c "$fullpath\node_modules\.bin\cordova" build $platform 1>> $pwd\stdout.txt
		}
		cmd /c "$fullpath\node_modules\.bin\cordova" platform remove $platform 1>> $pwd\stdout.txt
	}
	cd ..
	# Use rmdir since this does not hit "path too long" errors common when deleting node_module folders by full path. (Old tech FTW)
	cmd /c "rmdir /S /Q tempProj"
}

# Cache plugins
Write-Host "Prepping project to cache dynamically acquired plugins"
cmd /c "$env:CORDOVA_CACHE\$plugnFetchCordovaVersion\node_modules\.bin\cordova" create tempProj 1>> $pwd\stdout.txt
cd tempProj
# Remove the whitelist plugin so it doesn't conflict if we're installing multiple versions of it to cache
cmd /c "$env:CORDOVA_CACHE\$platformFetchCordovaVersion\node_modules\.bin\cordova" platform add android 1>> $pwd\stdout.txt
cmd /c "$env:CORDOVA_CACHE\$platformFetchCordovaVersion\node_modules\.bin\cordova" plugin remove cordova-plugin-whitelist --save 1>> $pwd\stdout.txt
cmd /c "$env:CORDOVA_CACHE\$platformFetchCordovaVersion\node_modules\.bin\cordova" platform remove android 1>> $pwd\stdout.txt
# Now cache plugins
foreach($plugin in $plugins.Keys) {
	foreach($pluginVer in $plugins.Item($plugin)) {
		Write-Host "Caching plugin $plugin version $pluginVer"
		cmd /c "$env:CORDOVA_CACHE\$plugnFetchCordovaVersion\node_modules\.bin\cordova" plugin add $pluginVer 1>> $pwd\stdout.txt
		cmd /c "$env:CORDOVA_CACHE\$plugnFetchCordovaVersion\node_modules\.bin\cordova" plugin remove $plugin 1>> $pwd\stdout.txt
	}
}
cd ..
cmd /c "rmdir /S /Q tempProj" 

# Cache one-off (non-pinned) platforms
Write-Host "Prepping project to cache specific platform versions"
cmd /c "$env:CORDOVA_CACHE\$platformFetchCordovaVersion\node_modules\.bin\cordova" create tempProj 1>> $pwd\stdout.txt
cd tempProj
# Remove the whitelist plugin since it doesn't work with older versions of platforms and is in the default template for 5.0.0+
cmd /c "$env:CORDOVA_CACHE\$platformFetchCordovaVersion\node_modules\.bin\cordova" platform add android 1>> $pwd\stdout.txt
cmd /c "$env:CORDOVA_CACHE\$platformFetchCordovaVersion\node_modules\.bin\cordova" plugin remove cordova-plugin-whitelist --save 1>> $pwd\stdout.txt
cmd /c "$env:CORDOVA_CACHE\$platformFetchCordovaVersion\node_modules\.bin\cordova" platform remove android 1>> $pwd\stdout.txt
# Now cache other platform versions
foreach($platform in $oneOffPlatforms.Keys) {
	foreach($platVer in $oneOffPlatforms.Item($platform)) {
		Write-Host "Caching platform $platform version $platVer"
		cmd /c "$env:CORDOVA_CACHE\$platformFetchCordovaVersion\node_modules\.bin\cordova" platform add $platVer 1>> $pwd\stdout.txt
		cmd /c "$env:CORDOVA_CACHE\$platformFetchCordovaVersion\node_modules\.bin\cordova" platform remove $platform 1>> $pwd\stdout.txt
	}
}
cd ..
# Use rmdir since this does not hit "path too long" errors common when deleting node_module folders by full path. (Old tech FTW)
cmd /c "rmdir /S /Q tempProj"

$env:CORDOVA_HOME=$origCH
$env:PLUGMAN_HOME=$origPH
cd $pwd
