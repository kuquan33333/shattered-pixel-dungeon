param(
	[string]$Locale = "vi"
)

$ErrorActionPreference = "Stop"
$messagesRoot = Join-Path $PSScriptRoot "..\core\src\main\assets\messages"

function Read-Properties([string]$Path) {
	$values = @{}
	$continuation = ""

	foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
		if ($continuation) {
			$line = $continuation + $line
			$continuation = ""
		}

		if ($line -match "(?<!\\)(?:\\\\)*\\$") {
			$continuation = $line.Substring(0, $line.Length - 1)
			continue
		}

		$trimmed = $line.Trim()
		if (!$trimmed -or $trimmed.StartsWith("#") -or $trimmed.StartsWith("!")) {
			continue
		}

		$match = [regex]::Match($line, "^(?<key>(?:\\.|[^\\=:\s])+?)\s*(?:=|:|\s)\s*(?<value>.*)$")
		if ($match.Success) {
			$values[$match.Groups["key"].Value.Trim()] = $match.Groups["value"].Value
		}
	}

	return $values
}

$failures = 0
$checked = 0

$baseFiles = @(Get-ChildItem -LiteralPath $messagesRoot -Recurse -Filter "*.properties" |
	Where-Object { $_.Name -notmatch "_[a-z]{2}(?:-[a-z]+)?\.properties$" }
)

foreach ($baseFile in $baseFiles) {
	$localeFile = Join-Path $baseFile.DirectoryName ($baseFile.BaseName + "_${Locale}.properties")
	if (!(Test-Path -LiteralPath $localeFile)) {
		Write-Error "Missing locale file: $localeFile"
		$failures++
		continue
	}

	$base = Read-Properties $baseFile.FullName
	$localized = Read-Properties $localeFile
	$missing = @()
	$extra = @()
	foreach ($key in $base.Keys) {
		if (!$localized.ContainsKey($key)) {
			$missing += $key
		}
	}
	foreach ($key in $localized.Keys) {
		if (!$base.ContainsKey($key)) {
			$extra += $key
		}
	}

	$checked += $base.Count
	if ($missing.Count -or $extra.Count) {
		Write-Output "FAIL $($baseFile.Name): missing=$($missing.Count) extra=$($extra.Count)"
		$missing | ForEach-Object { Write-Output "  missing: $_" }
		$extra | ForEach-Object { Write-Output "  extra: $_" }
		$failures++
	} else {
		Write-Output "PASS $($baseFile.Name): $($base.Count) keys"
	}
}

if ($failures) {
	Write-Error "Vietnamese localization verification failed in $failures file(s)."
	exit 1
}

Write-Output "Vietnamese localization verification passed: $checked keys checked."
