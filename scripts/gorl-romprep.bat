@echo off
setlocal EnableExtensions

rem GORL ROM preparation tool - Windows BAT version.
rem Self-contained; uses Windows PowerShell included with Windows 10/11.
rem It renames ROMs to DOS 8.3, asks only for new titles,
rem and rebuilds gametitles.txt without entries for deleted ROMs.

set "_GORL_PS=%TEMP%\gorl_romprep_%RANDOM%_%RANDOM%.ps1"
for /f "tokens=1 delims=:" %%N in ('findstr /n /b /c:"#GORL_POWERSHELL" "%~f0"') do set "_GORL_LINE=%%N"
if not defined _GORL_LINE (
    echo ERROR: internal PowerShell block not found.
    exit /b 2
)

more +%_GORL_LINE% "%~f0" > "%_GORL_PS%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%_GORL_PS%"
set "_GORL_RC=%ERRORLEVEL%"
del /q "%_GORL_PS%" >nul 2>&1
exit /b %_GORL_RC%

#GORL_POWERSHELL
$ErrorActionPreference = 'Stop'

$OutputName = 'gametitles.txt'
$Extensions = @('.rom', '.scc', '.a8', '.a16', '.d2r')
$Reserved = @('CON','PRN','AUX','NUL','COM1','COM2','COM3','COM4','COM5','COM6','COM7','COM8','COM9','LPT1','LPT2','LPT3','LPT4','LPT5','LPT6','LPT7','LPT8','LPT9')
$Comparer = [System.StringComparer]::OrdinalIgnoreCase

function Test-Rom([System.IO.FileInfo]$File) {
    return $Extensions -contains $File.Extension.ToLowerInvariant()
}

function Get-DosStem([string]$Name) {
    $s = $Name.ToUpperInvariant() -replace '[^A-Z0-9_-]', '_'
    if ([string]::IsNullOrEmpty($s)) { $s = 'GAME' }
    if ($s.Length -gt 8) { $s = $s.Substring(0, 8) }
    if ($Reserved -contains $s) {
        $s = '_' + $s
        if ($s.Length -gt 8) { $s = $s.Substring(0, 8) }
    }
    return $s
}

function Convert-AsciiTitle([string]$Text) {
    $Text = (($Text.Trim() -split '\s+') -join ' ')
    return [Text.Encoding]::ASCII.GetString([Text.Encoding]::ASCII.GetBytes($Text))
}

function Read-TitleMap([string]$Path) {
    $map = [System.Collections.Generic.Dictionary[string,string]]::new($Comparer)
    if (Test-Path -LiteralPath $Path) {
        foreach ($raw in [IO.File]::ReadAllLines($Path, [Text.Encoding]::ASCII)) {
            $line = $raw.Trim()
            if (-not $line) { continue }
            $m = [regex]::Match($line, '^(\S+)\s+(.+)$')
            if ($m.Success) {
                $title = $m.Groups[2].Value.Trim()
                if ($title) { $map[$m.Groups[1].Value] = $title }
            }
        }
    }
    return $map
}

function Add-Count($Dictionary, [string]$Key, [int]$Delta) {
    if ($Dictionary.ContainsKey($Key)) { $Dictionary[$Key] += $Delta }
    else { $Dictionary[$Key] = $Delta }
}

function Get-UniqueName([string]$Stem, [string]$Ext, $Occupied) {
    $candidate = "$Stem.$Ext"
    if (-not $Occupied.ContainsKey($candidate) -or $Occupied[$candidate] -le 0) { return $candidate }

    for ($n = 1; $n -le 999; $n++) {
        $suffix = "_$n"
        $keep = [Math]::Max(1, 8 - $suffix.Length)
        $prefix = $Stem.Substring(0, [Math]::Min($Stem.Length, $keep))
        $candidate = "$prefix$suffix.$Ext"
        if (-not $Occupied.ContainsKey($candidate) -or $Occupied[$candidate] -le 0) { return $candidate }
    }
    throw "Cannot create a unique DOS filename for $Stem.$Ext"
}

try {
    $Folder = (Get-Location).Path
    $Output = Join-Path $Folder $OutputName
    $OldTitles = Read-TitleMap $Output
    $Carried = [System.Collections.Generic.Dictionary[string,string]]::new($Comparer)
    $CarriedSource = [System.Collections.Generic.Dictionary[string,string]]::new($Comparer)
    $Survived = [System.Collections.Generic.HashSet[string]]::new($Comparer)
    $Occupied = [System.Collections.Generic.Dictionary[string,int]]::new($Comparer)

    $Snapshot = @(Get-ChildItem -LiteralPath $Folder -File | Sort-Object Name)
    $Roms = @($Snapshot | Where-Object { Test-Rom $_ })

    if ($Roms.Count -eq 0) {
        [IO.File]::WriteAllText($Output, '', [Text.Encoding]::ASCII)
        Write-Host 'No ROM files found.'
        Write-Host "Updated: $Output"
        Write-Host "Removed stale title entries: $($OldTitles.Count)"
        exit 0
    }

    foreach ($file in $Snapshot) { Add-Count $Occupied $file.Name 1 }

    Write-Host '=== 1/3 - DOS 8.3 rename ==='
    $Renamed = 0

    foreach ($file in $Roms) {
        Add-Count $Occupied $file.Name -1
        $stem = Get-DosStem $file.BaseName
        $ext = $file.Extension.TrimStart('.').ToUpperInvariant()
        $targetName = Get-UniqueName $stem $ext $Occupied

        if ($OldTitles.ContainsKey($file.Name)) {
            $Carried[$targetName] = $OldTitles[$file.Name]
            $CarriedSource[$targetName] = $file.Name
        }
        elseif ($OldTitles.ContainsKey($targetName)) {
            $Carried[$targetName] = $OldTitles[$targetName]
            $CarriedSource[$targetName] = $targetName
        }

        if ($file.Name -ceq $targetName) {
            Write-Host "[OK]     $($file.Name)"
        }
        else {
            Write-Host "[RENAME] $($file.Name) -> $targetName"
            if (($file.Name -ieq $targetName) -and ($file.Name -cne $targetName)) {
                $tmpName = ".__GORLTMP_$PID`_$Renamed__"
                Rename-Item -LiteralPath $file.FullName -NewName $tmpName
                Rename-Item -LiteralPath (Join-Path $Folder $tmpName) -NewName $targetName
            }
            else {
                Rename-Item -LiteralPath $file.FullName -NewName $targetName
            }
            $Renamed++
        }
        Add-Count $Occupied $targetName 1
    }

    Write-Host "`nRenamed files: $Renamed`n"
    Write-Host '=== 2/3 - Game titles ==='

    $CurrentRoms = @(Get-ChildItem -LiteralPath $Folder -File | Where-Object { Test-Rom $_ } | Sort-Object Name)
    $Lines = New-Object 'System.Collections.Generic.List[string]'
    $Kept = 0
    $Added = 0

    foreach ($rom in $CurrentRoms) {
        $title = $null
        if ($Carried.ContainsKey($rom.Name)) {
            $title = $Carried[$rom.Name]
            if ($CarriedSource.ContainsKey($rom.Name)) { [void]$Survived.Add($CarriedSource[$rom.Name]) }
        }
        elseif ($OldTitles.ContainsKey($rom.Name)) {
            $title = $OldTitles[$rom.Name]
            [void]$Survived.Add($rom.Name)
        }

        if ($title) {
            $Kept++
            Write-Host "[KEEP]   $($rom.Name) -> $title"
        }
        else {
            Write-Host "`nROM: $($rom.Name)"
            $title = Read-Host "Full game title [Enter = $($rom.BaseName)]"
            if ([string]::IsNullOrWhiteSpace($title)) { $title = $rom.BaseName }
            $Added++
        }

        $title = Convert-AsciiTitle $title
        if (-not $title) { $title = $rom.BaseName }
        $Lines.Add("$($rom.Name) $title")
    }

    Write-Host "`n=== 3/3 - gametitles.txt ==="
    [IO.File]::WriteAllLines($Output, $Lines.ToArray(), [Text.Encoding]::ASCII)

    $Removed = [Math]::Max($OldTitles.Count - $Survived.Count, 0)
    Write-Host "Updated: $Output"
    Write-Host "Existing titles kept: $Kept"
    Write-Host "New titles requested: $Added"
    Write-Host "Removed stale title entries: $Removed"
    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}
