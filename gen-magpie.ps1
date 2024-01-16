param (
    [switch]$MPV,
    [switch]$ClangFormat
)

$DIR = $PSScriptRoot

$anti_ringing_strength = 0.8

$use_magpie = "--use-magpie"
$magpie_options = "--overwrite"
$float_format = "float16dx"

if ($MPV) {
    $use_magpie = $null
    $magpie_options = $null
    $float_format = "float16gl"
}

if ($ClangFormat) {
    if (!(Get-Command clang-format.exe -ea 0)) {
        Write-Warning "clang-format.exe not found; Formatting turned off."
        $ClangFormat = $false
    }
}

function gen_nnedi3 {
    if(!$MPV) {
        Copy-Item "$DIR\prescalers.hlsli" "prescalers.hlsli"
    }

    foreach($nns in @(16, 32, 64, 128, 256)) {
        foreach($win in @('8x4', '8x6')) {
            $file_name = "NNEDI3_nns${nns}_win${win}.hlsl"
            python.exe "$DIR\nnedi3.py" --nns "$nns" --win "$win" --use-compute-shader $use_magpie | Out-File -Encoding ASCII "$file_name"
            if ($ClangFormat) {
                clang-format.exe --style="file:$DIR\.clang-format" -i "$file_name"
            }
        }
    }
}

function gen_ravu {
    param (
        $float_format
    )

    if (!$MPV) {
        Copy-Item "$DIR\prescalers.hlsli" "prescalers.hlsli"
    }

    foreach($target in @('luma', 'rgb')) {
        $suffix = "_$target".ToUpper()
        if ($target -eq "luma") {
            $suffix = ""
        }
        foreach($radius in @(2, 3, 4)) {
            $file_name = "RAVU_R$radius$suffix.hlsl"
            $weights_file = "$DIR\weights\ravu_weights-r$radius.py"
            python.exe "$DIR\ravu.py" --target "$target" --weights-file "$weights_file" --float-format "$float_format" --use-compute-shader $use_magpie $magpie_options | Out-File -Encoding ASCII "$file_name"
            if ($ClangFormat) {
                clang-format.exe --style="file:$DIR\.clang-format" -i "$file_name"
            }
        }
    }

    foreach($radius in @(2, 3, 4)) {
        $file_name = "RAVU_Lite_R$radius.hlsl"
        $file_name_ar = "RAVU_Lite_AR_R$radius.hlsl"
        $weights_file = "$DIR\weights\ravu-lite_weights-r$radius.py"
        python.exe "$DIR\ravu-lite.py" --weights-file "$weights_file" --float-format "$float_format" --use-compute-shader  $use_magpie $magpie_options | Out-File -Encoding ASCII "$file_name"
        python.exe "$DIR\ravu-lite.py" --weights-file "$weights_file" --float-format "$float_format" --use-compute-shader --anti-ringing "$anti_ringing_strength" $use_magpie $magpie_options | Out-File -Encoding ASCII "$file_name_ar"
        if ($ClangFormat) {
            clang-format.exe --style="file:$DIR\.clang-format" -i "$file_name"
            clang-format.exe --style="file:$DIR\.clang-format" -i "$file_name_ar"
        }
    }

    foreach($target in @('luma', 'rgb')) {
        $suffix = "_$target".ToUpper()
        if ($target -eq "luma") {
            $suffix = ""
        }
        foreach($radius in @(2, 3, 4)) {
            $file_name = "RAVU_3x_R$radius$suffix.hlsl"
            $weights_file = "$DIR\weights\ravu-3x_weights-r$radius.py"
            python.exe "$DIR\ravu-3x.py" --target "$target" --weights-file "$weights_file" --float-format "$float_format" $use_magpie $magpie_options | Out-File -Encoding ASCII "$file_name"
            if ($ClangFormat) {
                clang-format.exe --style="file:$DIR\.clang-format" -i "$file_name"
            }
        }
    }

    foreach($target in @('luma', 'rgb')) {
        $suffix = "_$target".ToUpper()
        if ($target -eq "luma") {
            $suffix = ""
        }
        foreach($radius in @(2, 3)) {
            $file_name = "RAVU_Zoom_R$radius$suffix.hlsl"
            $file_name_ar = "RAVU_Zoom_AR_R$radius$suffix.hlsl"
            $weights_file = "$DIR\weights\ravu-zoom_weights-r$radius.py"
            python.exe "$DIR\ravu-zoom.py" --target "$target" --weights-file "$weights_file" --float-format "$float_format" --use-compute-shader $use_magpie $magpie_options | Out-File -Encoding ASCII "$file_name"
            python.exe "$DIR\ravu-zoom.py" --target "$target" --weights-file "$weights_file" --float-format "$float_format" --use-compute-shader --anti-ringing "$anti_ringing_strength" $use_magpie $magpie_options | Out-File -Encoding ASCII "$file_name_ar"
            if ($ClangFormat) {
                clang-format.exe --style="file:$DIR\.clang-format" -i "$file_name"
                clang-format.exe --style="file:$DIR\.clang-format" -i "$file_name_ar"
            }
        }
    }
}

New-Item NNEDI3 -ItemType Directory -ea 0 | Out-Null
Push-Location NNEDI3
gen_nnedi3
Pop-Location

New-Item RAVU -ItemType Directory -ea 0 | Out-Null
Push-Location RAVU
gen_ravu $float_format
Pop-Location
