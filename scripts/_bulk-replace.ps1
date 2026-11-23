param(
  [Parameter(Mandatory=$true)][string]$Pattern,
  [Parameter(Mandatory=$true)][string]$Replacement,
  [Parameter(Mandatory=$true)][string[]]$Paths,
  [switch]$Literal
)
# Bulk in-place regex (or literal) replace over .ch files under $Paths.
# Uses .NET IO so nothing depends on cmdlet parameter quirks.
$enc = New-Object System.Text.UTF8Encoding($false)
$total = 0
foreach($p in $Paths) {
    $files = @()
    if (Test-Path -PathType Container $p) {
        $files = Get-ChildItem -Path $p -Recurse -Filter *.ch -File
    } else {
        $files = Get-Item $p
    }
    foreach($f in $files) {
        $text = [System.IO.File]::ReadAllText($f.FullName)
        $new = if ($Literal) { $text.Replace($Pattern, $Replacement) } else { [regex]::Replace($text, $Pattern, $Replacement) }
        if ($new -ne $text) {
            [System.IO.File]::WriteAllText($f.FullName, $new, $enc)
            $total++
        }
    }
}
Write-Output "files changed: $total"
