Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "docs\linkedin-assets"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$width = 1600
$height = 900

function New-BitmapCanvas {
    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $rect = New-Object System.Drawing.Rectangle 0, 0, $width, $height
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(9, 14, 18)), ([System.Drawing.Color]::FromArgb(24, 32, 36)), 25
    $graphics.FillRectangle($brush, $rect)
    $brush.Dispose()
    return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function New-Pen($r, $g, $b, $a, $size) {
    return New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($a, $r, $g, $b)), $size
}

function New-Brush($r, $g, $b, $a) {
    return New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($a, $r, $g, $b))
}

function Draw-Grid($g) {
    $pen = New-Pen 96 130 132 32 1
    for ($x = 0; $x -le $width; $x += 80) {
        $g.DrawLine($pen, $x, 0, $x, $height)
    }
    for ($y = 0; $y -le $height; $y += 80) {
        $g.DrawLine($pen, 0, $y, $width, $y)
    }
    $pen.Dispose()
}

function Draw-Header($g, $title, $subtitle) {
    $titleFont = New-Object System.Drawing.Font "Segoe UI Semibold", 42
    $subtitleFont = New-Object System.Drawing.Font "Segoe UI", 18
    $titleBrush = New-Brush 238 246 245 245
    $subBrush = New-Brush 158 183 180 220
    $g.DrawString($title, $titleFont, $titleBrush, 78, 58)
    $g.DrawString($subtitle, $subtitleFont, $subBrush, 82, 116)
    $titleFont.Dispose()
    $subtitleFont.Dispose()
    $titleBrush.Dispose()
    $subBrush.Dispose()
}

function Draw-Node($g, $label, $x, $y, $w, $h, $accent) {
    $shadow = New-Brush 0 0 0 75
    $g.FillRectangle($shadow, $x + 8, $y + 10, $w, $h)
    $shadow.Dispose()

    $rect = New-Object System.Drawing.Rectangle $x, $y, $w, $h
    $fill = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(44, 58, 60)), ([System.Drawing.Color]::FromArgb(17, 24, 28)), 90
    $g.FillRectangle($fill, $rect)
    $fill.Dispose()

    $border = New-Pen 94 142 139 180 2
    $g.DrawRectangle($border, $x, $y, $w, $h)
    $border.Dispose()

    $accentBrush = New-Brush $accent[0] $accent[1] $accent[2] 235
    $g.FillRectangle($accentBrush, $x, $y, 8, $h)
    $accentBrush.Dispose()

    $font = New-Object System.Drawing.Font "Segoe UI Semibold", 17
    $brush = New-Brush 235 244 242 238
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $textRect = New-Object System.Drawing.RectangleF ([float]$x), ([float]$y), ([float]$w), ([float]$h)
    $g.DrawString($label, $font, $brush, $textRect, $format)
    $font.Dispose()
    $brush.Dispose()
    $format.Dispose()
}

function Draw-Arrow($g, $x1, $y1, $x2, $y2, $r, $gr, $b) {
    $pen = New-Pen $r $gr $b 175 3
    $cap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap 5, 7
    $pen.CustomEndCap = $cap
    $g.DrawLine($pen, $x1, $y1, $x2, $y2)
    $pen.Dispose()
    $cap.Dispose()
}

function Draw-Architecture {
    $canvas = New-BitmapCanvas
    $g = $canvas.Graphics
    Draw-Grid $g
    Draw-Header $g "RWA-Vault Protocol Architecture" "Project-derived module map: apps, packages, services, contracts"

    $teal = @(64, 210, 196)
    $gold = @(226, 177, 89)
    $blue = @(118, 177, 214)

    Draw-Node $g "Investor PWA`napps/client" 88 245 250 92 $teal
    Draw-Node $g "Ops Console`napps/ops-console" 88 510 250 92 $teal
    Draw-Node $g "Envelope Codec`npackages/envelope-codec" 430 245 285 92 $blue
    Draw-Node $g "PQ Core`nFalcon-512 / WASM" 430 510 285 92 $gold
    Draw-Node $g "Smart Contracts`ncontracts/" 830 378 270 100 $gold
    Draw-Node $g "Oracle`nservices/oracle" 1205 220 260 80 $blue
    Draw-Node $g "Risk Engine`nservices/risk-engine" 1205 365 260 80 $blue
    Draw-Node $g "Settlement Rail`nservices/settlement-rail" 1205 510 260 80 $blue
    Draw-Node $g "Anchor Batcher + PQ Verifier`nservices/" 720 665 500 82 $teal

    Draw-Arrow $g 338 291 430 291 64 210 196
    Draw-Arrow $g 338 556 430 556 64 210 196
    Draw-Arrow $g 715 291 830 400 118 177 214
    Draw-Arrow $g 715 556 830 456 226 177 89
    Draw-Arrow $g 1100 428 1205 260 118 177 214
    Draw-Arrow $g 1100 428 1205 405 118 177 214
    Draw-Arrow $g 1100 428 1205 550 118 177 214
    Draw-Arrow $g 970 478 970 665 64 210 196

    $smallFont = New-Object System.Drawing.Font "Cascadia Mono", 15
    $brush = New-Brush 202 218 214 210
    $g.DrawString("Module 1 Stage 1: native Falcon signatures verify in browser WASM; WASM signatures verify natively", $smallFont, $brush, 85, 805)
    $smallFont.Dispose()
    $brush.Dispose()

    Save-Canvas $canvas "rwa-vault-architecture.png"
}

function Draw-FieldLines {
    $canvas = New-BitmapCanvas
    $g = $canvas.Graphics
    Draw-Grid $g
    Draw-Header $g "Post-Quantum Trust Field" "Cryptographic primitives and asset attestations represented as deterministic vector lines"

    $centerX = 800
    $centerY = 475
    for ($i = 0; $i -lt 34; $i++) {
        $phase = $i * 0.31
        $startY = 180 + ($i * 17)
        $x1 = 95
        $y1 = $startY
        $x2 = 360 + [Math]::Sin($phase) * 95
        $y2 = 260 + [Math]::Cos($phase) * 210
        $x3 = 1170 + [Math]::Cos($phase) * 95
        $y3 = 700 - [Math]::Sin($phase) * 210
        $x4 = 1505
        $y4 = 180 + (($i * 23) % 610)
        $alpha = 55 + (($i % 6) * 22)
        $pen = New-Pen 61 210 198 $alpha 2
        $g.DrawBezier($pen, $x1, $y1, $x2, $y2, $x3, $y3, $x4, $y4)
        $pen.Dispose()
    }

    $outerGlow = New-Brush 226 177 89 26
    $midGlow = New-Brush 226 177 89 54
    $innerGlow = New-Brush 222 179 96 95
    $g.FillEllipse($outerGlow, 565, 285, 470, 370)
    $g.FillEllipse($midGlow, 610, 320, 380, 300)
    $g.FillEllipse($innerGlow, 695, 395, 210, 150)
    $outerGlow.Dispose()
    $midGlow.Dispose()
    $innerGlow.Dispose()

    $ringPen = New-Pen 226 177 89 210 3
    $g.DrawEllipse($ringPen, 650, 360, 300, 220)
    $g.DrawEllipse($ringPen, 695, 395, 210, 150)
    $ringPen.Dispose()

    $labels = @(
        @{ T = "Falcon-512"; X = 230; Y = 255 },
        @{ T = "ML-KEM-768"; X = 1160; Y = 250 },
        @{ T = "ML-DSA-65"; X = 1185; Y = 635 },
        @{ T = "SHAKE entropy"; X = 220; Y = 650 },
        @{ T = "Attestation envelope"; X = 690; Y = 720 }
    )
    foreach ($item in $labels) {
        Draw-Node $g $item.T $item.X $item.Y 235 62 @(64, 210, 196)
    }

    $font = New-Object System.Drawing.Font "Segoe UI Semibold", 22
    $brush = New-Brush 246 240 214 245
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $coreTextRect = New-Object System.Drawing.RectangleF 700, 415, 200, 85
    $g.DrawString("PQ`nCORE", $font, $brush, $coreTextRect, $format)
    $font.Dispose()
    $brush.Dispose()
    $format.Dispose()

    Save-Canvas $canvas "rwa-vault-field-lines.png"
}

function Draw-Topology {
    $canvas = New-BitmapCanvas
    $g = $canvas.Graphics
    Draw-Grid $g
    Draw-Header $g "RWA-Vault Workspace Topology" "Real repository structure rendered as a 3D graph"

    $groups = @(
        @{ Name = "apps"; X = 210; Y = 315; C = @(64, 210, 196); Items = @("client", "ops-console") },
        @{ Name = "packages"; X = 620; Y = 250; C = @(226, 177, 89); Items = @("types", "config", "pq-core", "envelope-codec") },
        @{ Name = "services"; X = 1030; Y = 315; C = @(118, 177, 214); Items = @("oracle", "risk-engine", "pq-verifier", "anchor-batcher", "settlement-rail") },
        @{ Name = "contracts"; X = 620; Y = 610; C = @(184, 216, 188); Items = @("foundry", "solidity", "local deploy") }
    )

    foreach ($group in $groups) {
        $x = $group.X
        $y = $group.Y
        $c = $group.C
        $boxH = 185
        $shadow = New-Brush 0 0 0 80
        $g.FillPolygon($shadow, [System.Drawing.Point[]]@(
            [System.Drawing.Point]::new($x + 28, $y + 34),
            [System.Drawing.Point]::new($x + 308, $y + 34),
            [System.Drawing.Point]::new($x + 356, $y + 88),
            [System.Drawing.Point]::new($x + 76, $y + 88)
        ))
        $shadow.Dispose()

        $top = New-Brush $c[0] $c[1] $c[2] 160
        $side = New-Brush 22 33 37 230
        $edge = New-Pen $c[0] $c[1] $c[2] 220 2
        $g.FillPolygon($top, [System.Drawing.Point[]]@(
            [System.Drawing.Point]::new($x, $y),
            [System.Drawing.Point]::new($x + 280, $y),
            [System.Drawing.Point]::new($x + 330, $y + 54),
            [System.Drawing.Point]::new($x + 50, $y + 54)
        ))
        $g.FillPolygon($side, [System.Drawing.Point[]]@(
            [System.Drawing.Point]::new($x + 50, $y + 54),
            [System.Drawing.Point]::new($x + 330, $y + 54),
            [System.Drawing.Point]::new($x + 330, $y + $boxH),
            [System.Drawing.Point]::new($x + 50, $y + $boxH)
        ))
        $g.DrawPolygon($edge, [System.Drawing.Point[]]@(
            [System.Drawing.Point]::new($x, $y),
            [System.Drawing.Point]::new($x + 280, $y),
            [System.Drawing.Point]::new($x + 330, $y + 54),
            [System.Drawing.Point]::new($x + 330, $y + $boxH),
            [System.Drawing.Point]::new($x + 50, $y + $boxH),
            [System.Drawing.Point]::new($x + 50, $y + 54)
        ))
        $top.Dispose()
        $side.Dispose()
        $edge.Dispose()

        $nameFont = New-Object System.Drawing.Font "Segoe UI Semibold", 24
        $itemFont = New-Object System.Drawing.Font "Cascadia Mono", 12
        $white = New-Brush 245 250 248 245
        $muted = New-Brush 196 214 211 220
        $g.DrawString($group.Name, $nameFont, $white, $x + 70, $y + 12)
        $itemY = $y + 72
        foreach ($item in $group.Items) {
            $g.DrawString($item, $itemFont, $muted, $x + 78, $itemY)
            $itemY += 22
        }
        $nameFont.Dispose()
        $itemFont.Dispose()
        $white.Dispose()
        $muted.Dispose()
    }

    Draw-Arrow $g 540 390 620 335 226 177 89
    Draw-Arrow $g 950 335 1030 390 118 177 214
    Draw-Arrow $g 775 405 775 610 184 216 188
    Draw-Arrow $g 730 610 360 470 64 210 196
    Draw-Arrow $g 950 685 1150 470 118 177 214

    $font = New-Object System.Drawing.Font "Segoe UI", 17
    $brush = New-Brush 176 198 194 215
    $g.DrawString("Generated from repository package boundaries, not a UI mockup.", $font, $brush, 86, 810)
    $font.Dispose()
    $brush.Dispose()

    Save-Canvas $canvas "rwa-vault-workspace-topology.png"
}

function Save-Canvas($canvas, $name) {
    $path = Join-Path $outDir $name
    $canvas.Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Graphics.Dispose()
    $canvas.Bitmap.Dispose()
    Write-Host $path
}

Draw-Architecture
Draw-FieldLines
Draw-Topology
