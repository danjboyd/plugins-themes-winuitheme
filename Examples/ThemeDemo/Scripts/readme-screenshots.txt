# The README's screenshots: ThemeDemo's controls, text input and data
# views pages, an open pop-up list and an alert. Run it once per mode
# (light, dark, and light with "--contrast-theme dusk"), on the carried
# libs-back so the theme draws the title bar:
#   Tests/Scripts/Invoke-ThemeDemoScript.ps1 -Script Examples/ThemeDemo/Scripts/readme-screenshots.txt -Backend <bundle> -Mode dark -OutputDirectory <dir>
# Docs/Images/controls-light-dark.png is the light and dark controls.png
# side by side, 24px apart.

page controls
wait 1
screenshot-window {out}\controls.png

page text-input
wait 1
screenshot-window {out}\text-input.png
capture-dropdown popup-button {out}\popup-open.png

page data-views
wait 1
screenshot-window {out}\data-views.png

page controls
wait 0.5
capture-alert {out}\alert.png
wait 1.5
quit
