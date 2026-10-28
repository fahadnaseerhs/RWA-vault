param([string]$Pptx, [string]$OutDir)
New-Item -ItemType Directory -Force $OutDir | Out-Null
Get-ChildItem $OutDir -Filter *.png | Remove-Item -Force
$pp = New-Object -ComObject PowerPoint.Application
$pres = $pp.Presentations.Open($Pptx, $true, $false, $false)
$i = 1
foreach ($s in $pres.Slides) {
  $s.Export((Join-Path $OutDir ("slide-{0:D2}.png" -f $i)), "PNG", 1600, 900)
  $i++
}
$pres.Close()
if ($pp.Presentations.Count -eq 0) { $pp.Quit() }
Get-ChildItem $OutDir -Filter *.png | ForEach-Object { $_.FullName }
