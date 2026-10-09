# Gives the GNUstep apps a test starts a home directory of their own, so they
# don't read the owner's GNUstep defaults (NSGlobalDomain's GSTheme, an app's
# saved window frames) or write into them. Dot-source it, then:
#
#   $testHome = Enter-GNUstepTestHome
#   try { Start-Process ... } finally { Exit-GNUstepTestHome $testHome }
#
# gnustep-base on Windows takes the home directory from HOMEDRIVE and
# HOMEPATH (USERPROFILE when HOMEPATH is "\"), and the user defaults from
# GNUstep\Defaults under it. GNUSTEP_CONFIG_FILE is ignored by MSYS2's
# build, so a private GNUstep.conf can't be used as on Linux. Processes
# started while the test home is entered inherit it.

# What the owner's NSGlobalDomain held when the checks were written, and
# what they assume: no app icon window, Windows-style menus and the
# backend's checks of window offsets.
$GNUstepTestGlobalDomain = @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GSBackChecksOffsetsOnScreen</key>
    <true/>
    <key>GSBackChecksOffsetsWithoutNetRequests</key>
    <true/>
    <key>GSSuppressAppIcon</key>
    <integer>1</integer>
    <key>GSWindowDecoration</key>
    <string>Default</string>
    <key>NSMenuInterfaceStyle</key>
    <string>NSWindows95InterfaceStyle</string>
</dict>
</plist>
'@

function Enter-GNUstepTestHome {
  $path = Join-Path ([System.IO.Path]::GetTempPath()) ("gnustep-test-home-" + [guid]::NewGuid())
  $defaults = Join-Path $path "GNUstep\Defaults"
  New-Item -ItemType Directory -Force -Path $defaults | Out-Null
  Set-Content -Encoding UTF8 -Path (Join-Path $defaults "NSGlobalDomain.plist") -Value $GNUstepTestGlobalDomain

  $saved = @{ Path = $path; HOMEDRIVE = $env:HOMEDRIVE; HOMEPATH = $env:HOMEPATH; USERPROFILE = $env:USERPROFILE }
  $env:HOMEDRIVE = $path.Substring(0, 2)
  $env:HOMEPATH = $path.Substring(2)
  $env:USERPROFILE = $path
  return $saved
}

function Exit-GNUstepTestHome($saved) {
  $env:HOMEDRIVE = $saved.HOMEDRIVE
  $env:HOMEPATH = $saved.HOMEPATH
  $env:USERPROFILE = $saved.USERPROFILE
  Remove-Item -Recurse -Force -Path $saved.Path -ErrorAction SilentlyContinue
}
