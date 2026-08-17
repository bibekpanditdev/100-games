# Generates the app's offline audio assets as 16-bit mono 22050 Hz WAV files.
# Synthesized programmatically so the repo ships real, license-free audio
# with zero binary blobs in source control. Swap these for compressed
# OGG/AAC masters later by dropping files with the same names (see README
# "Audio System"). Re-run: powershell -File tool/generate_audio.ps1

$sampleRate = 22050
$sfxDir = "assets/audio/sfx"
$bgmDir = "assets/audio/bgm"
New-Item -ItemType Directory -Force -Path $sfxDir | Out-Null
New-Item -ItemType Directory -Force -Path $bgmDir | Out-Null

function Write-Wav($path, [double[]]$samples) {
    $n = $samples.Length
    $dataLen = $n * 2
    $fs = [System.IO.File]::Create($path)
    $bw = New-Object System.IO.BinaryWriter($fs)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([Int32](36 + $dataLen))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([Int32]16); $bw.Write([Int16]1); $bw.Write([Int16]1)
    $bw.Write([Int32]$sampleRate); $bw.Write([Int32]($sampleRate * 2))
    $bw.Write([Int16]2); $bw.Write([Int16]16)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([Int32]$dataLen)
    for ($i = 0; $i -lt $n; $i++) {
        $v = [Math]::Max(-1.0, [Math]::Min(1.0, $samples[$i]))
        $bw.Write([Int16]($v * 32000))
    }
    $bw.Close(); $fs.Close()
}

function Tone([double]$freq, [double]$dur, [double]$amp = 0.55, [string]$wave = "sine", [double]$attack = 0.008, [double]$release = 0.06) {
    $n = [int]($dur * $sampleRate)
    $out = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $t = $i / $sampleRate
        $ph = 2 * [Math]::PI * $freq * $t
        $s = switch ($wave) {
            "sine"     { [Math]::Sin($ph) }
            "square"   { if ([Math]::Sin($ph) -ge 0) { 1.0 } else { -1.0 } }
            "triangle" { 2 / [Math]::PI * [Math]::Asin([Math]::Sin($ph)) }
            "saw"      { 2 * (($freq * $t) - [Math]::Floor(0.5 + $freq * $t)) }
        }
        $env = 1.0
        if ($t -lt $attack) { $env = $t / $attack }
        $rel = $dur - $t
        if ($rel -lt $release) { $env = [Math]::Min($env, $rel / $release) }
        $out[$i] = $amp * $s * $env
    }
    $out
}

function Sweep([double]$f0, [double]$f1, [double]$dur, [double]$amp = 0.5) {
    $n = [int]($dur * $sampleRate)
    $out = New-Object double[] $n
    $phase = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $t = $i / $sampleRate
        $f = $f0 + ($f1 - $f0) * ($t / $dur)
        $phase += 2 * [Math]::PI * $f / $sampleRate
        $env = [Math]::Min(1.0, $t / 0.01)
        $rel = $dur - $t
        if ($rel -lt 0.08) { $env = [Math]::Min($env, $rel / 0.08) }
        $out[$i] = $amp * [Math]::Sin($phase) * $env
    }
    $out
}

function Concat([double[][]]$parts, [double]$gapSec = 0.02) {
    $gap = [int]($gapSec * $sampleRate)
    $list = New-Object System.Collections.Generic.List[double]
    foreach ($p in $parts) { $list.AddRange($p); for ($g = 0; $g -lt $gap; $g++) { $list.Add(0.0) } }
    $list.ToArray()
}

# ---------------- UI ----------------
Write-Wav "$sfxDir/ui_tap.wav"        (Tone 660 0.05 0.4)
Write-Wav "$sfxDir/ui_toggle.wav"     (Concat @((Tone 520 0.04 0.35), (Tone 780 0.05 0.35)))
Write-Wav "$sfxDir/ui_error.wav"      (Concat @((Tone 190 0.09 0.5 "square"), (Tone 150 0.11 0.5 "square")))
Write-Wav "$sfxDir/ui_transition.wav" (Sweep 420 900 0.14 0.3)
Write-Wav "$sfxDir/unlock.wav"        (Concat @((Tone 523 0.09 0.4), (Tone 659 0.09 0.4), (Tone 784 0.16 0.45)))
Write-Wav "$sfxDir/coin.wav"          (Concat @((Tone 988 0.05 0.4), (Tone 1319 0.12 0.42)))
Write-Wav "$sfxDir/levelup.wav"       (Concat @((Tone 392 0.08 0.4), (Tone 523 0.08 0.4), (Tone 659 0.08 0.4), (Tone 784 0.2 0.45)))
Write-Wav "$sfxDir/streak.wav"        (Concat @((Tone 587 0.07 0.4), (Tone 880 0.07 0.4), (Tone 1175 0.16 0.42)))
Write-Wav "$sfxDir/challenge.wav"     (Concat @((Tone 440 0.1 0.42), (Tone 554 0.1 0.42), (Tone 659 0.1 0.42), (Tone 880 0.22 0.45)))

# ---------------- Generic game events ----------------
Write-Wav "$sfxDir/correct.wav"       (Concat @((Tone 660 0.07 0.45), (Tone 880 0.12 0.45)))
Write-Wav "$sfxDir/wrong.wav"         (Concat @((Tone 220 0.09 0.5 "square"), (Tone 175 0.13 0.5 "square")))
Write-Wav "$sfxDir/place.wav"         (Tone 300 0.045 0.4 "triangle")
Write-Wav "$sfxDir/flip.wav"          (Sweep 300 600 0.08 0.35)
Write-Wav "$sfxDir/match_found.wav"   (Concat @((Tone 587 0.06 0.45), (Tone 880 0.1 0.45)))
Write-Wav "$sfxDir/mismatch.wav"      (Tone 200 0.1 0.45 "square")
Write-Wav "$sfxDir/win.wav"           (Concat @((Tone 523 0.09 0.45), (Tone 659 0.09 0.45), (Tone 784 0.09 0.45), (Tone 1047 0.24 0.5)))
Write-Wav "$sfxDir/lose.wav"          (Sweep 440 110 0.5 0.45)
Write-Wav "$sfxDir/hint.wav"          (Sweep 700 1400 0.16 0.35)

# ---------------- Sequence tones (Simon / pattern) ----------------
Write-Wav "$sfxDir/tone1.wav" (Tone 392 0.22 0.5)
Write-Wav "$sfxDir/tone2.wav" (Tone 523 0.22 0.5)
Write-Wav "$sfxDir/tone3.wav" (Tone 659 0.22 0.5)
Write-Wav "$sfxDir/tone4.wav" (Tone 784 0.22 0.5)

# ---------------- Word ----------------
Write-Wav "$sfxDir/letter.wav"    (Tone 740 0.05 0.35)
Write-Wav "$sfxDir/word_found.wav" (Concat @((Tone 660 0.07 0.42), (Tone 990 0.14 0.42)))

# ---------------- Cards ----------------
Write-Wav "$sfxDir/deal.wav"    (Sweep 900 300 0.09 0.3)
Write-Wav "$sfxDir/shuffle.wav" (Concat @((Tone 500 0.03 0.3 "triangle"), (Tone 400 0.03 0.3 "triangle"), (Tone 600 0.03 0.3 "triangle"), (Tone 450 0.03 0.3 "triangle")))

# ---------------- Arcade ----------------
Write-Wav "$sfxDir/hit.wav"     (Tone 180 0.06 0.55 "square")
Write-Wav "$sfxDir/jump.wav"    (Sweep 300 720 0.12 0.4)
Write-Wav "$sfxDir/die.wav"     (Sweep 500 80 0.4 0.5)
Write-Wav "$sfxDir/powerup.wav" (Sweep 400 1600 0.25 0.4)
Write-Wav "$sfxDir/tick.wav"    (Tone 1000 0.03 0.3)

# ---------------- Spatial ----------------
Write-Wav "$sfxDir/pickup.wav"  (Tone 500 0.05 0.35 "triangle")
Write-Wav "$sfxDir/snap.wav"    (Concat @((Tone 700 0.04 0.45), (Tone 1050 0.07 0.45)))
Write-Wav "$sfxDir/rotate.wav"  (Sweep 500 700 0.07 0.3)
Write-Wav "$sfxDir/solved.wav"  (Concat @((Tone 523 0.08 0.45), (Tone 784 0.08 0.45), (Tone 1047 0.2 0.48)))

# ---------------- BGM loops ----------------
# Gentle synthesized loops. Notes are chosen so each pattern ends near zero
# amplitude, making the loop seamless. Keep volumes low (BGM layer).
function NoteLen([double]$freq, [double]$beats) { Tone $freq ($beats * 0.45) 0.16 "sine" 0.02 0.3 }
function Bass([double]$freq, [double]$beats) { Tone $freq ($beats * 0.45) 0.1 "triangle" 0.02 0.35 }

# Menu: calm ascending pattern in C
$menu = New-Object System.Collections.Generic.List[double[]]
$menuPattern = @(523.25, 659.26, 783.99, 659.26, 587.33, 783.99, 659.26, 523.25)
foreach ($f in $menuPattern) { $menu.Add((NoteLen $f 1)); $menu.Add((Bass ($f / 2) 1)) }
Write-Wav "$bgmDir/menu_loop.wav" (Concat $menu.ToArray() 0.02)

# Mind: slower, airy pattern in A minor
$mind = New-Object System.Collections.Generic.List[double[]]
$mindPattern = @(440.0, 523.25, 659.26, 587.33, 523.25, 440.0, 392.0, 440.0)
foreach ($f in $mindPattern) { $mind.Add((NoteLen $f 1.5)); $mind.Add((Bass ($f / 2) 1.5)) }
Write-Wav "$bgmDir/mind_loop.wav" (Concat $mind.ToArray() 0.05)

# Arcade: brighter, quicker pattern in G
$arcade = New-Object System.Collections.Generic.List[double[]]
$arcadePattern = @(392.0, 493.88, 587.33, 783.99, 587.33, 493.88, 440.0, 493.88)
foreach ($f in $arcadePattern) { $arcade.Add((NoteLen $f 0.8)); $arcade.Add((Bass ($f / 2) 0.8)) }
Write-Wav "$bgmDir/arcade_loop.wav" (Concat $arcade.ToArray() 0.01)

# Generic in-game: neutral pattern in D
$game = New-Object System.Collections.Generic.List[double[]]
$gamePattern = @(587.33, 659.26, 739.99, 659.26, 587.33, 493.88, 587.33, 659.26)
foreach ($f in $gamePattern) { $game.Add((NoteLen $f 1)); $game.Add((Bass ($f / 2) 1)) }
Write-Wav "$bgmDir/game_loop.wav" (Concat $game.ToArray() 0.03)

Write-Host "Audio assets generated:"
Get-ChildItem -Recurse $sfxDir, $bgmDir | ForEach-Object { Write-Host ($_.FullName.Replace((Get-Location).Path + '\', '') + ' (' + [Math]::Round($_.Length / 1KB, 1) + ' KB)') }
