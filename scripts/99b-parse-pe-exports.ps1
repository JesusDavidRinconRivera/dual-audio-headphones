# 99b - parse-pe-exports.ps1
# ---------------------------------------------------------------
# Parses the PE export table of a DLL directly and prints every
# exported function name. Independent of any toolchain (no dumpbin
# needed). Used to discover the real export set of
# VoicemeeterRemote64.dll.
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\99b-parse-pe-exports.ps1
# ---------------------------------------------------------------

$path = "C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll"
$bytes = [System.IO.File]::ReadAllBytes($path)

function RVA-to-offset($rva, $sections) {
    foreach ($s in $sections) {
        if ($rva -ge $s.VA -and $rva -lt ($s.VA + $s.SizeOfRawData)) {
            return $s.PointerToRawData + ($rva - $s.VA)
        }
    }
    return -1
}

$pe = [BitConverter]::ToInt32($bytes, 0x3C)
$sig = [BitConverter]::ToInt32($bytes, $pe)
if ($sig -ne 0x00004550) { Write-Output "Not a PE file"; exit 1 }
$numSections = [BitConverter]::ToUInt16($bytes, $pe + 6)
$optSize = [BitConverter]::ToUInt16($bytes, $pe + 20)
$opt = $pe + 24
$magic = [BitConverter]::ToUInt16($bytes, $opt)
$ddOffset = if ($magic -eq 0x20B) { $opt + 112 } else { $opt + 96 }

# Build section table from IMAGE_SECTION_HEADER entries.
$sectionTable = $opt + $optSize
$sections = @()
for ($i = 0; $i -lt $numSections; $i++) {
    $p = $sectionTable + $i * 40
    $sections += [pscustomobject]@{
        VA = [BitConverter]::ToUInt32($bytes, $p + 12)
        SizeOfRawData = [BitConverter]::ToUInt32($bytes, $p + 16)
        PointerToRawData = [BitConverter]::ToUInt32($bytes, $p + 20)
    }
}

# Export directory = data directory index 0 in the optional header.
$exportRVA = [BitConverter]::ToUInt32($bytes, $ddOffset)
$expOff = RVA-to-offset $exportRVA $sections
if ($expOff -lt 0) { Write-Output "No export directory"; exit 1 }

$numNames = [BitConverter]::ToUInt32($bytes, $expOff + 24)
$addrOfNames = [BitConverter]::ToUInt32($bytes, $expOff + 32)
$namesOffset = RVA-to-offset $addrOfNames $sections

Write-Output ("=== Exported functions: {0} ===" -f $numNames)
for ($i = 0; $i -lt $numNames; $i++) {
    $nameRVA = [BitConverter]::ToUInt32($bytes, $namesOffset + $i * 4)
    $no = RVA-to-offset $nameRVA $sections
    $sb = New-Object System.Text.StringBuilder
    $j = $no
    while ($bytes[$j] -ne 0) { [void]$sb.Append([char]$bytes[$j]); $j++ }
    Write-Output $sb.ToString()
}