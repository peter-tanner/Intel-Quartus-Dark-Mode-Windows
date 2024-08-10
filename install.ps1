
Write-Output "Start installing Quartus dark mode..."

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script must be run as an administrator to modify registry and copy resources to the Quartus directory. Exiting..."
    exit
}

Write-Output "Create darkmode launch script"

$installPath = $(Get-ItemProperty -Path "HKLM:\SOFTWARE\Altera Corporation\Quartus" -Name "Quartus Install Directory")."Quartus Install Directory"

# VBS script is used since I need to pass the platform argument (windows:darkmode=1) 
# as an env variable, since while this succeeds as an argument, quartus tries to 
# interpret it as a file due to bad argument handling, resuling in an annoying
# dialog of it trying to open the file "windows:darkmode=1".
# Need to use VBS script to not spawn a console window.
$vbsFilePath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Quartus.vbs"
$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Environment("Process")("QT_QPA_PLATFORM") = "windows:darkmode=1"

Dim args
Set args = WScript.Arguments
Dim argStr
argStr = ""

If args.Count > 0 Then
    Dim i
    For i = 0 To args.Count - 1
        argStr = argStr & " " & args(i)
    Next
End If

Dim fso
Set fso = CreateObject("Scripting.FileSystemObject")
WshShell.CurrentDirectory = "$installPath"

Dim command
command = """$installPath\bin64\quartus.exe""" & " -stylesheet=darkstyle.qss " & argStr

WshShell.Run command, 0
"@
[System.IO.File]::WriteAllText("$vbsFilePath", $vbsContent)

$WScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $WScriptShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Quartus.lnk")
$shortcut.TargetPath = "wscript.exe"
$shortcut.Arguments = "`"$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Quartus.vbs`""
$shortcut.WorkingDirectory = $(Split-Path $installPath)
$shortcut.IconLocation = "$installPath\bin64\quartus.exe,0"
$shortcut.Save()

Write-Output "Copy stylesheet and resources"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$content = Get-Content "$scriptDir\darkstyle.qss"
$styleWithPath = $content -replace 'url\(":/dark_icons', "url(`"$($installPath -replace '\\', '/')/ZZZ_dark_icons"
Set-Content -Path "$installPath\darkstyle.qss" -Value $styleWithPath
New-Item -Force -Type Directory "$installPath\ZZZ_dark_icons"
Copy-Item -Path "$scriptDir\dark_icons\*" -Destination "$installPath\ZZZ_dark_icons" -Recurse -Force

Write-Output "Rewrite registry entries for file association open commands"

# Modify the registry entries to point to the VBS script
$registryPaths = @(
    "HKLM:\Software\Classes\Quartus.StateMachineEditor\shell\open\command",
    "HKLM:\Software\Classes\Quartus.SignalTap\shell\open\command",
    "HKLM:\Software\Classes\Quartus.ProjectFile\shell\open\command",
    "HKLM:\Software\Classes\Quartus.Project\shell\open\command",
    "HKLM:\Software\Classes\Quartus.DesignTemplate\shell\open\command",
    "HKLM:\Software\Classes\Quartus.BlockSymbol\shell\open\command",
    "HKLM:\Software\Classes\Quartus.BlockSchematic\shell\open\command",
    "HKLM:\Software\Classes\Quartus.Archive\shell\open\command"
)

foreach ($regPath in $registryPaths) {
    Set-ItemProperty -Path $regPath -Name "(default)" -Value "wscript.exe `"$vbsFilePath`" %1"
}

Write-Output "Rewrite quartus settings to make text editor dark"

# Modify colors for text editor with dark colors
# Create a backup of the existing settings file
$quartusSettingsPath = "$HOME\quartus2.qreg"
if (Test-Path $quartusSettingsPath) {
    $suffix = 1
    do {
        $quartusBakPath = [System.IO.Path]::ChangeExtension($quartusSettingsPath, "$suffix" + "_backup" + [System.IO.Path]::GetExtension($quartusSettingsPath))
        $suffix++
    } while (Test-Path $quartusBakPath)
}

Copy-Item -Path $quartusSettingsPath -Destination $quartusBakPath
$replacements = @{
    # Scintilla based text editor
    "Altera_Foundation_Class\\AFCQ_TED_KEYWORD_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_KEYWORD_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\xff\xff\xff\xff\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_NORMAL_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_NORMAL_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\xdf\xdf\xe1\xe1\xe2\xe2\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_BACKGROUND_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_BACKGROUND_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x19\x19##--\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_LINE_NUMBER_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_LINE_NUMBER_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\xdf\xdf\xe1\xe1\xe2\xe2\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_LINE_BACKGROUND_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_LINE_BACKGROUND_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x19\x19##--\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_SELECTION_FG_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_SELECTION_FG_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\xdf\xdf\xe1\xe1\xe2\xe2\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_VHDL_KEYWORDS_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_VHDL_KEYWORDS_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x7f\x7f\xaa\xaa\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_VERILOG_KEYWORDS_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_VERILOG_KEYWORDS_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x7f\x7f\xaa\xaa\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_TCL_KEYWORDS_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_TCL_KEYWORDS_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x7f\x7f\xaa\xaa\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_SYS_VERILOG_KEYWORDS_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_SYS_VERILOG_KEYWORDS_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x7f\x7f\xaa\xaa\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_MSW_WARNING_COLOR.+" = "Altera_Foundation_Class\AFCQ_MSW_WARNING_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x7f\x7f\xaa\xaa\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_MSW_CRITICAL_WARNING_COLOR.+" = "Altera_Foundation_Class\AFCQ_MSW_CRITICAL_WARNING_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x7f\x7f\xaa\xaa\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_MULTI_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_MULTI_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\0\0\xc0\xc0\0\0\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_SINGLE_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_SINGLE_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\0\0\xc0\xc0\0\0\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_STRING_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_STRING_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\xe8\xe8\0\0\xe8\xe8\0\0)"
    "Altera_Foundation_Class\\AFCQ_TED_IDENTIFIER_COLOR.+" = "Altera_Foundation_Class\AFCQ_TED_IDENTIFIER_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\xe8\xe8\0\0\xe8\xe8\0\0)"
    "Altera_Foundation_Class\\AFCQ_MSW_INFO_COLOR.+=" = "Altera_Foundation_Class\AFCQ_MSW_INFO_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\0\0\xc0\xc0\0\0\0\0)"

    # RTL viewer
    "Altera_Foundation_Class\\AFCQ_NUI_BACKGROUND_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_BACKGROUND_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x19\x19##--\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_INSTANE_FONT_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_INSTANE_FONT_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\xff\xff\0\0\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_RIPPER_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_RIPPER_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\0\0\xff\xff\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_NET_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_NET_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\xff\xff\xff\xff\0\0\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_PIN_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_PIN_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\0\0\xff\xff\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_PORT_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_PORT_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\0\0\xff\xff\xff\xff\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_PRIMITIVE_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_PRIMITIVE_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x1a\x1arr\xbb\xbb\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_SELECTION_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_SELECTION_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\xff\xff\0\0\0\0\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_INSTANCE_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_INSTANCE_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\0\0\x80\x80\0\0\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_INSTANCE_REGION_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_INSTANCE_REGION_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x37\x37\x41\x41OO\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_INSTANCE_ATOM_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_INSTANCE_ATOM_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x1a\x1arr\xbb\xbb\0\0)"
    "Altera_Foundation_Class\\AFCQ_NUI_ENCRYPTED_INSTANCE_COLOR.+" = "Altera_Foundation_Class\AFCQ_NUI_ENCRYPTED_INSTANCE_COLOR=@Variant(\0\0\0\x43\x1\xff\xff\x45\x45SSdd\0\0)"
}
$quartusSettings = Get-Content -Path $quartusSettingsPath -Raw
foreach ($key in $replacements.Keys) {
    if ($quartusSettings -match $key) {
        $quartusSettings = $quartusSettings -replace $key, $replacements[$key]
    } else {
        $quartusSettings += "`r`n" + $replacements[$key]
    }
}
Set-Content -Path $quartusSettingsPath -Value $quartusSettings

Write-Output "Dark mode installed"