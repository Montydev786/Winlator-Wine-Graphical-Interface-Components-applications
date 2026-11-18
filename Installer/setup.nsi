; Taskbar & Desktop by Monty - installer (NSIS, Modern UI 2)
; Build:  makensis -DARCH=x86_64 installer/setup.nsi   (needs build/MontyShell.exe first)
Unicode true
!ifndef ARCH
  !define ARCH "x86_64"
!endif
!define APPNAME   "Taskbar & Desktop by Monty"
!define APPNAME_UI "Taskbar && Desktop by Monty"   ; && = literal & in NSIS UI text
!define APPEXE    "MontyShell.exe"
!define VERSION   "1.0.0"
!define GITHUB    "https://github.com/monty786-dev/Winlator-Wine-Look-changer"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\MontyShell"

Name "${APPNAME_UI}"
OutFile "..\build\MontyShell-Setup-${ARCH}.exe"
InstallDir "$PROGRAMFILES\MontyShell"
InstallDirRegKey HKCU "Software\MontyShell" "InstallDir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
BrandingText "${APPNAME_UI} ${VERSION}  -  star it on GitHub"

!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

; ---- look: dark header / log with an accent colour ----
!define MUI_BGCOLOR 1B1D2A
!define MUI_INSTFILESPAGE_COLORFOREGROUND 8AB4F8
!define MUI_INSTFILESPAGE_COLORBACKGROUND 11121A
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Welcome to ${APPNAME_UI}"
!define MUI_WELCOMEPAGE_TEXT "A custom taskbar, start panel, window title bars and desktop for Winlator's Wine.$\r$\n$\r$\n22 OS looks (Windows 98 to 11, macOS, Ubuntu, KDE, XFCE ...), each in a modern and a classic original style.$\r$\n$\r$\nIf you like it, please give it a star on GitHub."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APPEXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Start now"
!define MUI_FINISHPAGE_LINK "Star the project on GitHub"
!define MUI_FINISHPAGE_LINK_LOCATION "${GITHUB}"

Var chkRun
Var chkWfm
Var chkTweaks
Var chkDesk
Var doRun
Var doWfm
Var doTweaks
Var doDesk

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
Page custom OptionsPage OptionsLeave
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function OptionsPage
  !insertmacro MUI_HEADER_TEXT "Winlator integration" "Choose how the shell is wired into this container."
  nsDialogs::Create 1018
  Pop $0
  ${NSD_CreateCheckbox} 0 0 100% 14u "Start automatically with the container (adds a Run entry)"
  Pop $chkRun
  ${NSD_Check} $chkRun
  ${NSD_CreateCheckbox} 0 18u 100% 24u "Make it the default shell: replace Winlator's wfm.exe (a backup wfm.exe.orig is kept and restored on uninstall)"
  Pop $chkWfm
  ${NSD_Check} $chkWfm
  ${NSD_CreateCheckbox} 0 46u 100% 14u "Apply Wine stability / performance / power-saving registry tweaks"
  Pop $chkTweaks
  ${NSD_Check} $chkTweaks
  ${NSD_CreateCheckbox} 0 64u 100% 14u "Create a desktop shortcut"
  Pop $chkDesk
  ${NSD_CreateLabel} 0 88u 100% 36u "Tip: pick the 32-bit installer for 32-bit containers. Everything can be changed later in Settings > System."
  Pop $0
  nsDialogs::Show
FunctionEnd

Function OptionsLeave
  ${NSD_GetState} $chkRun $doRun
  ${NSD_GetState} $chkWfm $doWfm
  ${NSD_GetState} $chkTweaks $doTweaks
  ${NSD_GetState} $chkDesk $doDesk
FunctionEnd

Section "Install" SecMain
  SetOutPath "$INSTDIR"
  File "..\build\MontyShell.exe"
  File "..\README.md"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\MontyShell" "InstallDir" "$INSTDIR"

  ; Start menu entries (also feed the shell's own app list)
  CreateDirectory "$SMPROGRAMS\Taskbar & Desktop by Monty"
  CreateShortCut "$SMPROGRAMS\Taskbar & Desktop by Monty\Taskbar & Desktop.lnk" "$INSTDIR\${APPEXE}"
  CreateShortCut "$SMPROGRAMS\Taskbar & Desktop by Monty\Settings.lnk" "$INSTDIR\${APPEXE}" "--settings"
  CreateShortCut "$SMPROGRAMS\Taskbar & Desktop by Monty\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  ${If} $doDesk == ${BST_CHECKED}
    CreateShortCut "$DESKTOP\Taskbar & Desktop.lnk" "$INSTDIR\${APPEXE}"
  ${EndIf}

  ; ---- run at container start ----
  ${If} $doRun == ${BST_CHECKED}
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "MontyShell" '"$INSTDIR\${APPEXE}" --boot'
    DetailPrint "Autostart entry added."
  ${EndIf}

  ; ---- become Winlator's default shell (wfm.exe) ----
  ${If} $doWfm == ${BST_CHECKED}
    StrCpy $1 ""
    IfFileExists "$WINDIR\wfm.exe" 0 +2
      StrCpy $1 "$WINDIR\wfm.exe"
    ${If} $1 == ""
      IfFileExists "$SYSDIR\wfm.exe" 0 +2
        StrCpy $1 "$SYSDIR\wfm.exe"
    ${EndIf}
    ${If} $1 == ""
      DetailPrint "wfm.exe not found in this container - skipped (autostart entry is used instead)."
    ${Else}
      IfFileExists "$1.orig" +2 0
        CopyFiles /SILENT "$1" "$1.orig"
      CopyFiles /SILENT "$INSTDIR\${APPEXE}" "$1"
      WriteRegStr HKCU "Software\MontyShell" "WfmPath" "$1"
      DetailPrint "Replaced $1 (backup: $1.orig)."
    ${EndIf}
  ${EndIf}

  ; ---- Wine stability / performance / power tweaks (HKCU of this container) ----
  ${If} $doTweaks == ${BST_CHECKED}
    WriteRegStr HKCU "Software\Wine\X11 Driver" "Decorated" "N"
    WriteRegStr HKCU "Software\Wine\X11 Driver" "UseTakeFocus" "N"
    WriteRegDWORD HKCU "Software\Wine\WineDbg" "ShowCrashDialog" 0
    WriteRegStr HKCU "Control Panel\Desktop" "MenuShowDelay" "0"
    WriteRegStr HKCU "Control Panel\Desktop" "FontSmoothing" "2"
    WriteRegStr HKCU "Control Panel\Desktop" "FontSmoothingType" "2"
    WriteRegStr HKCU "Control Panel\Desktop" "DragFullWindows" "1"
    WriteRegStr HKCU "Control Panel\Desktop" "AutoEndTasks" "1"
    WriteRegStr HKCU "Control Panel\Desktop" "HungAppTimeout" "3000"
    WriteRegStr HKCU "Control Panel\Desktop" "WaitToKillAppTimeout" "3000"
    DetailPrint "Wine tweaks applied."
  ${EndIf}

  WriteRegStr HKLM "${UNINSTKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINSTKEY}" "Publisher" "Monty"
  WriteRegStr HKLM "${UNINSTKEY}" "URLInfoAbout" "${GITHUB}"
  WriteRegStr HKLM "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
SectionEnd

Section "Uninstall"
  ; put Winlator's original shell back
  ReadRegStr $1 HKCU "Software\MontyShell" "WfmPath"
  ${If} $1 != ""
    IfFileExists "$1.orig" 0 +3
      CopyFiles /SILENT "$1.orig" "$1"
      Delete "$1.orig"
  ${EndIf}
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "MontyShell"
  DeleteRegKey HKCU "Software\MontyShell"
  DeleteRegKey HKLM "${UNINSTKEY}"
  Delete "$DESKTOP\Taskbar & Desktop.lnk"
  RMDir /r "$SMPROGRAMS\Taskbar & Desktop by Monty"
  Delete "$INSTDIR\${APPEXE}"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  ; user settings in %APPDATA%\MontyShell are kept on purpose
SectionEnd
