# Podglad postepu testu JMeter - wypisuje wynik po kazdym ukonczonym poziomie userow.
param(
    [string]$JtlFile,
    [int[]]$ExpectedLevels,
    [int]$PollSec = 5
)

$ErrorActionPreference = "SilentlyContinue"
$printed = @{}

function Test-LabelInJtl {
    param([string]$Path, [string]$Label)
    $pattern = "^[^,]+,[^,]+,$Label,"
    return [bool](Select-String -Path $Path -Pattern $pattern -Quiet -ErrorAction SilentlyContinue)
}

function Write-LevelLine {
    param([string]$Label, [string]$Path)

    $okMs = New-Object System.Collections.Generic.List[double]
    $ok = 0; $fail = 0
    $pattern = "^[^,]+,([^,]+),$Label,"

    Select-String -Path $Path -Pattern $pattern -ErrorAction SilentlyContinue | ForEach-Object {
        $parts = $_.Line.Split(',')
        if ($parts.Count -lt 8) { return }
        if ($parts[7] -eq "true") {
            $ok++
            [void]$okMs.Add([double]$parts[1])
        } else {
            $fail++
        }
    }

    if (($ok + $fail) -lt 30) { return }

    $total = $ok + $fail
    $avg = if ($okMs.Count -gt 0) { [math]::Round(($okMs.ToArray() | Measure-Object -Average).Average, 0) } else { 0 }
    $rate = if ($total -gt 0) { [math]::Round(100.0 * $ok / $total, 1) } else { 0 }

    Write-Output ("  [poziom {0}] Avg={1}ms | zapytan={2} | OK={3}%" -f $Label, $avg, $total, $rate)
}

$sortedLevels = @($ExpectedLevels | Sort-Object)

while ($true) {
    if (-not (Test-Path $JtlFile)) {
        Start-Sleep -Seconds $PollSec
        continue
    }

    for ($i = 0; $i -lt ($sortedLevels.Count - 1); $i++) {
        $level = $sortedLevels[$i]
        $next = $sortedLevels[$i + 1]
        if ($printed[$level]) { continue }
        if (Test-LabelInJtl -Path $JtlFile -Label "$next") {
            Write-LevelLine -Label "$level" -Path $JtlFile
            $printed[$level] = $true
        }
    }

    Start-Sleep -Seconds $PollSec
}
