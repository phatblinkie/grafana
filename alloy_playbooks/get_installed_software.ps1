$metricsDir = "C:\metrics"
$outputFile = "$metricsDir\software_metrics.prom"

# Create directory if needed
if (-not (Test-Path -Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
}

# Write single HELP/TYPE header
@"
# HELP windows_software_info Installed software information
# TYPE windows_software_info gauge
"@ | Out-File -FilePath $outputFile -Encoding utf8 -Force

# Append metrics data
Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" |
Where-Object { $_.DisplayName -ne $null } |
ForEach-Object {
    $name = $_.DisplayName -replace '"','\"' -replace '\n',' ' -replace '\r',' '
    $version = if ($_.DisplayVersion) { $_.DisplayVersion -replace '"','\"' } else { "unknown" }
    $publisher = if ($_.Publisher) { $_.Publisher -replace '"','\"' } else { "unknown" }
    
    "windows_software_info{displayname=`"$name`",version=`"$version`",publisher=`"$publisher`"} 1"
} | Add-Content -Path $outputFile -Encoding utf8
