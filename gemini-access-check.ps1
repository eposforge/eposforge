$ErrorActionPreference = "Stop"
$out = 'D:\src\git\gh\eposforge\eposforge\gemini-access-check.out'

function Test-Read([string]$Path,[string]$Label){
  try { Get-ChildItem -Path $Path | Out-Null; "$Label:READ_OK" }
  catch { "$Label:DENY" }
}

$results = @(
  (Test-Read 'D:\src\git\gh\eposforge\eposforge' 'WORKSPACE'),
  (Test-Read 'C:\Users\ChristopherGrace' 'OP_PROFILE'),
  (Test-Read 'C:\Windows' 'WINDOWS'),
  (Test-Read 'C:\Users\Public' 'PUBLIC')
)

$results | Set-Content -Path $out -Encoding ascii
