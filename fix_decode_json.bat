@echo off
setlocal EnableDelayedExpansion

REM Script to fix outlier bPSNR values in vhs-decode JSON files
REM Processes JSON files produced by vhs-decode (all tape formats)
REM Maximum bPSNR ceiling: 70dB

REM Check if jq is available
jq --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: jq is required but not installed
    echo Please install jq from https://stedolan.github.io/jq/download/
    exit /b 1
)

echo vhs-decode JSON Fixer
echo =====================
echo Max bPSNR ceiling: 70dB

REM Get directory argument or use current directory
if "%~1"=="" (
    set "search_dir=."
) else (
    set "search_dir=%~1"
)

if not exist "%search_dir%" (
    echo Error: Directory '%search_dir%' does not exist
    exit /b 1
)

echo Searching for JSON files in: %search_dir%
echo.

REM Process JSON files
for /r "%search_dir%" %%f in (*.json) do (
    call :process_json_file "%%f"
)

echo.
echo Processing complete!
goto :eof

:process_json_file
set "input_file=%~1"
set "basename=%~n1"
set "dirname=%~dp1"
set "output_file=%dirname%%basename%-fixed.json"

echo Processing: %input_file%

REM Check if it's a vhs-decode file
jq -r "has(\"videoParameters\")" "%input_file%" 2>nul > temp_has_params.txt
set /p has_video_params=<temp_has_params.txt
del temp_has_params.txt 2>nul

if not "%has_video_params%"=="true" (
    echo   Skipping: Not a vhs-decode JSON file
    goto :eof
)

jq -r ".videoParameters.system // \"unknown\"" "%input_file%" 2>nul > temp_system.txt
jq -r ".videoParameters.tapeFormat // \"unknown\"" "%input_file%" 2>nul > temp_format.txt

set /p format=<temp_system.txt
set /p tape_format=<temp_format.txt

del temp_system.txt temp_format.txt 2>nul

echo   vhs-decode file detected ^(system: %format%, format: %tape_format%^)

REM Check if we have fields array with vitsMetrics
jq -r "has(\"fields\") and (.fields | type == \"array\")" "%input_file%" 2>nul > temp_has_fields.txt
set /p has_fields=<temp_has_fields.txt
del temp_has_fields.txt 2>nul

if not "%has_fields%"=="true" (
    echo   Skipping: No fields array found
    goto :eof
)

REM Get bPSNR data
jq -r ".fields | to_entries | map(select(.value | type == \"object\" and has(\"vitsMetrics\") and (.vitsMetrics | type == \"object\" and has(\"bPSNR\") and (.bPSNR | type == \"number\")))) | map(\"\(.key),\(.value.vitsMetrics.bPSNR)\") | .[]" "%input_file%" 2>nul > temp_bpsnr.txt

REM Check if we have any bPSNR values
for %%A in (temp_bpsnr.txt) do if %%~zA==0 (
    echo   No bPSNR values found
    del temp_bpsnr.txt 2>nul
    goto :eof
)

REM Create temporary working file
copy "%input_file%" temp_working.json >nul

set "changes_made=false"
set "line_count=0"

REM Count lines for processing
for /f %%a in ('type temp_bpsnr.txt ^| find /c /v ""') do set line_count=%%a
echo   Found %line_count% bPSNR values

REM Read bPSNR values into arrays (simulated with numbered variables)
set "i=0"
for /f "usebackq tokens=1,2 delims=," %%a in ("temp_bpsnr.txt") do (
    set "index[!i!]=%%a"
    set "value[!i!]=%%b"
    set /a i+=1
)
set /a max_i=i-1

REM Process each value
for /l %%i in (0,1,%max_i%) do (
    set "current_value=!value[%%i]!"
    set "current_index=!index[%%i]!"
    
    REM Check if value exceeds 70dB ceiling
    powershell -command "if ([double]'!current_value!' -gt 70) { exit 0 } else { exit 1 }" >nul 2>&1
    if !errorlevel! equ 0 (
        echo     Value exceeds 70dB ceiling: !current_value! at index !current_index!
        
        REM Replace with previous value (enforce 70dB ceiling)
        if %%i gtr 0 (
            set /a prev_idx=%%i-1
            set "replacement_value=!value[!prev_idx!]!"
            echo       Replacing with previous value: !replacement_value!
            
            REM Update the JSON file
            jq ".fields[!current_index!].vitsMetrics.bPSNR = !replacement_value!" temp_working.json > temp_working2.json
            move temp_working2.json temp_working.json >nul
            
            set "changes_made=true"
        ) else (
            echo       First value, cannot replace
        )
    )
    
    REM Check if value is above 50 (simple comparison for batch)
    powershell -command "if ([double]'!current_value!' -gt 50) { exit 0 } else { exit 1 }" >nul 2>&1
    if !errorlevel! equ 0 (
        echo     Checking high bPSNR value: !current_value! at index !current_index!
        
        REM Calculate average of previous up to 10 values
        set /a start_idx=%%i-10
        if !start_idx! lss 0 set start_idx=0
        
        if %%i gtr 0 (
            set "sum=0"
            set "count=0"
            
            for /l %%j in (!start_idx!,1,%%i) do (
                if %%j lss %%i (
                    set "prev_val=!value[%%j]!"
                    powershell -command "[double]'!sum!' + [double]'!prev_val!'" > temp_sum.txt
                    set /p sum=<temp_sum.txt
                    del temp_sum.txt
                    set /a count+=1
                )
            )
            
            if !count! gtr 0 (
                powershell -command "[math]::Round([double]'!sum!' / [double]'!count!', 6)" > temp_avg.txt
                set /p avg=<temp_avg.txt
                del temp_avg.txt
                
                powershell -command "[math]::Abs([double]'!current_value!' - [double]'!avg!')" > temp_diff.txt
                set /p diff=<temp_diff.txt
                del temp_diff.txt
                
                REM Check if difference is more than 3
                powershell -command "if ([double]'!diff!' -gt 3) { exit 0 } else { exit 1 }" >nul 2>&1
                if !errorlevel! equ 0 (
                    echo       Outlier detected! Value: !current_value!, Average: !avg!, Diff: !diff!
                    
                    REM Get previous value for replacement
                    set /a prev_idx=%%i-1
                    set "replacement_value=!value[!prev_idx!]!"
                    echo       Replacing with previous value: !replacement_value!
                    
                    REM Update the JSON file
                    jq ".fields[!current_index!].vitsMetrics.bPSNR = !replacement_value!" temp_working.json > temp_working2.json
                    move temp_working2.json temp_working.json >nul
                    
                    set "changes_made=true"
                ) else (
                    echo       Value within acceptable range ^(diff: !diff!^)
                )
            )
        ) else (
            echo       First value, cannot compare to previous values
        )
    )
)

REM Clean up and finalize
if "%changes_made%"=="true" (
    move temp_working.json "%output_file%" >nul
    echo   Fixed file saved as: %output_file%
) else (
    del temp_working.json 2>nul
    echo   No changes needed
)

del temp_bpsnr.txt 2>nul
goto :eof