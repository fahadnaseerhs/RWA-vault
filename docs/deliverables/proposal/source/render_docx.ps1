param([string]$Docx, [string]$OutDir)
# Word -> PDF, then Windows.Data.Pdf -> PNG per page (no third-party tools).
New-Item -ItemType Directory -Force $OutDir | Out-Null
Get-ChildItem $OutDir -Filter page-*.png -ErrorAction SilentlyContinue | Remove-Item -Force
$pdf = Join-Path $OutDir "proposal.pdf"
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$word.Options.SaveNormalPrompt = $false
$doc = $word.Documents.Open($Docx, $false, $true, $false)
$doc.ExportAsFixedFormat($pdf, 17)
$pages = $doc.ComputeStatistics(2)
$doc.Close($false)
if ($word.Documents.Count -eq 0) { $word.Quit() }
"pages: $pages"

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]
function Await($op, [type]$t) { $task = $asTask.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(); $task.Result }
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($pdf)) ([Windows.Storage.StorageFile])
$pdfDoc = Await ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
for ($i = 0; $i -lt $pdfDoc.PageCount; $i++) {
  $page = $pdfDoc.GetPage($i)
  $stream = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
  $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
  $opts.DestinationWidth = 1275
  $t = $asTaskAction.Invoke($null, @($page.RenderToStreamAsync($stream, $opts))); $t.Wait()
  $net = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
  $out = [System.IO.File]::Create((Join-Path $OutDir ("page-{0:D2}.png" -f ($i + 1))))
  $net.Position = 0; $net.CopyTo($out); $out.Close(); $net.Close()
}
"rendered $($pdfDoc.PageCount) pages"
