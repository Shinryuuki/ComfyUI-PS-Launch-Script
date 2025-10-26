<#
.SYNOPSIS
Automates the launch of a manual ComfyUI installation with configurable CLI arguments and environment variables.

.DESCRIPTION
1. Defines paths and configuration settings.
2. Performs critical path and file existence checks, including configuration validation.
3. Checks for and activates the Python virtual environment (venv).
4. Sets environment variables.
5. Dynamically builds the argument list based on configuration toggles.
6. Executes main.py from the ComfyUI root directory and handles cleanup.
#>



# ==============================================================================
# 1. CONFIGURATION SETTINGS
#    Modify these variables to suit your desired ComfyUI launch profile.
# ==============================================================================

# ══════════════════
# Path Configuration
# ══════════════════
# Must use absolute path to the main ComfyUI installation directory.
$ComfyUIRoot = "H:\LocalAI\ComfyUI"

# ═══════════════════════════
# CLI Arguments Configuration
# ═══════════════════════════
# --- VRAM Configuration ---
# "gpu-only"   --> Store and run everything (text encoders/CLIP models, etc... on the GPU).
# "highvram"   --> By default models will be unloaded to CPU memory after being used. This option keeps them in GPU memory.
# "normalvram" --> Used to force normal vram use if lowvram gets automatically enabled.
# "lowvram"    --> Split the unet in parts to use less vram.
# "novram"     --> When lowvram isn't enough.
# "cpu"        --> To use the CPU for everything (slow).
# $null or ""  --> Defers to the default VRAM mode (normal).
$VRAMMode = "normalvram"
$VRAMReserve = 1  # Value for --reserve-vram  ➜ Set the amount of vram in GB you want to reserve for use by your OS/other software. By default some amount is reserved depending on your OS.

# --- Preview Configuration ---
# "none"       --> Disables previews.
# "auto"       --> Selects the most appropriate preview method.
# "latent2rgb" --> Enables fast, albeit low-quality previews.
# "taesd"      --> Enables slower, albeit high-quality previews.
# $null or ""  --> Defers to the default preview method (none).
$PreviewMethod = "auto"  # Value for --preview-method  ➜ Set preview method for sampler nodes. 
$PreviewSize = 1024      # Value for --preview-size    ➜ Default: 512, Max: 1024

# --- Attention Configuration ---
# "split"   --> Enables --use-split-cross-attention
# "quad"    --> Enables --use-quad-cross-attention
# "pytorch" --> Enables --use-pytorch-cross-attention
# "flash"   --> Enables --use-flash-attention
# "sage"    --> Enables --use-sage-attention
# $null or "" : Defers to the default attention mode (quad).
$AttentionMode = "pytorch"

# --- Optional FP8 Precision Configuration ---
$SupportFP8 = $true  # Toggles --supports-fp8-compute  ➜ ComfyUI will act like if the device supports fp8 compute.

# --- Optional Force FP Precision Configuration ---
# "fp32"    --> Enables --force-fp32  ➜ Force fp32 (If this makes your GPU work better please report it).
# "fp16"    --> Enables --force-fp16  ➜ Force fp16
# $null or "" : Defers to default precision mode.
$ForceFP = $null

# --- Optional VAE Precision Configuration ---
# "fp32"    --> Enables --fp32-vae  ➜ Run the VAE in full precision fp32.
# "fp16"    --> Enables --fp16-vae  ➜ Run the VAE in fp16, might cause black images.
# "bf16"    --> Enables --bf16-vae  ➜ Run the VAE in bf16.
# $null or "" : Defers to default VAE precision mode.
$VAEPrecision = $null

# --- Optional UNET Precision Configuration ---
# "fp64"    --> Enables --fp64-unet  ➜ Run the diffusion model in fp64.
# "fp32"    --> Enables --fp32-unet  ➜ Run the diffusion model in fp32.
# "fp16"    --> Enables --fp16-unet  ➜ Run the diffusion model in fp16
# "bf16"    --> Enables --bf16-unet  ➜ Run the diffusion model in bf16.
# "fp8-e4m3fn"  --> Enables --fp8_e4m3fn-unet   ➜ Store unet weights in fp8 (e4m3fn variant).
# "fp8-e5m2"    --> Enables --fp8_e5m2-unet     ➜ Store unet weights in fp8 (e5m2 variant).
# "fp8-e8m0fnu" --> Enables --fp8_e8m0fnu-unet  ➜ Store unet weights in fp8 (e8m0fnu variant).
# $null or ""   --> Defers to default UNET precision mode.
$UNETPrecision = $null

# --- Optional Text Encoder Precision Configuration ---
# "fp32"    --> Enables --fp32-text-enc  ➜ Store text encoder weights in fp32.
# "fp16"    --> Enables --fp16-text-enc  ➜ Store text encoder weights in fp16.
# "bf16"    --> Enables --bf16-text-enc  ➜ Store text encoder weights in bf16.
# "fp8-e4m3fn" --> Enables --fp8_e4m3fn-text-enc  ➜ Store text encoder weights in fp8 (e4m3fn variant).
# "fp8-e5m2"   --> Enables --fp8_e5m2-text-enc    ➜ Store text encoder weights in fp8 (e5m2 variant).
# $null or ""  --> Defers to default text encoder precision mode.
$TextEncPrecision = $null

# --- Optional Feature Toggles ---
$SetExclusiveGPU = 1                  # Value for --cuda-device           ➜ Set the id of the cuda device this instance will use. All other devices will not be visible.
$SetDefaultGPU = $null                # Value for --default-device        ➜ Set the id of the default device, all other devices will stay visible.
$EnableFastPerfOps = $false           # Toggles --fast                    ➜ Enable some untested and potentially quality deteriorating optimizations. --fast with no arguments enables everything. Individual options: fp16_accumulation, fp8_matrix_mult, cublas_ops, autotune
$EnableForceUpcastAttention = $false  # Toggles --force-upcast-attention  ➜ Force enable attention upcasting, please report if it fixes black images.
$EnableForceLastFormat = $false       # Toggles --force-channels-last     ➜ Force channels last format when inferencing the models.
$EnableCacheNone = $false             # Toggles --cache-none              ➜ Reduced RAM/VRAM usage at the expense of executing every node for each run.
$DisableSmartMemory = $false          # Toggles --disable-smart-memory    ➜ Forces ComfyUI to agressively offload to regular ram instead of keeping models in VRAM when it can.
$EnableAsyncOffload = $false          # Toggles --async-offload           ➜ Use async weight offloading.
$EnableForceNonBlocking = $false      # Toggles --force-non-blocking      ➜ Force ComfyUI to use non-blocking operations for all applicable tensors. This may improve performance on some non-Nvidia systems but can cause issues with some workflows.
$OverrideOutputDirectory = $null      # Value for --output-directory      ➜ Set the ComfyUI output directory. Overrides --base-directory.

# --- Optional Network Access ---
# <<<!!!WARNING!!!>>> Enabling external access is dangerous, proceed at your own risk! <<<!!!WARNING!!!>>>
# IP address for ComfyUI to listen on. Use "127.0.0.1" for local-only, "0.0.0.0" for external access.
# If $true, enables remote access via --listen & --port flags.
$EnableRemoteAccess = $false
$ListenIPAddress = "127.0.0.1"
$ListenPort = "8188"

# --- Optional Debugging Toggles ---
$EnableCLIQuickTest = $false     # Toggles --quick-test-for-ci         ➜ Quick test for CI.
$DisableCustomNodes = $false     # Toggles --disable-all-custom-nodes  ➜ Disable loading all custom nodes.
$DisableAPINodes = $false        # Toggles --disable-api-nodes         ➜ Disable loading all api nodes.
$ConfirmBeforeLaunching = $false  # Prompts user for confirmation before launching ComfyUI. 

# ═══════════════════════════════════
# Environment Variables Configuration
# ═══════════════════════════════════
# --- PyTorch  ---
$EnableAOTriton = $true    # TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL (enabled by default on ComfyUI v0.3.63 https://github.com/comfyanonymous/ComfyUI/pull/10168)
$EnableTunableOP = $false  # PYTORCH_TUNABLEOP_ENABLED

# --- GPU Targeting ---
$HCCAMDGPUTarget = $null     # Change to match your GPU
$PytorchROCmArch = $null     # Valid GFX targets: gfx942, gfx950, gfx1100, gfx1101, gfx1102, gfx1151, gfx1200, gfx1201
$TritonOverrideArch = $null  # MI300A/MI300X, MI350X/MI355X, RX 7900 XTX, RX 7800 XT, RX 7700S, Strix Halo iGPU, RX 9060(XT), RX 9070(XT)

# --- Memory Allocation Tuning ---
$PytorchHIPAllocConf = @()  # PYTORCH_HIP_ALLOC_CONF @(garbage_collection_threshold, max_split_size_mb)

# --- Precision and Performance ---
# <<<!NOT IMPLEMENTED!>>>
#$TorchBlasPreferHIPBlaslt = # TORCH_BLAS_PREFER_HIPBLASLT=0
#$TorchInductorMaxAutotuneGemmBackends = # TORCHINDUCTOR_MAX_AUTOTUNE_GEMM_BACKENDS="CK,TRITON,ROCBLAS"
#$TorchInductorMaxAutotuneGemmSearchSpace = # TORCHINDUCTOR_MAX_AUTOTUNE_GEMM_SEARCH_SPACE="BEST"
#$TorchInductorForceFallback = # TORCHINDUCTOR_FORCE_FALLBACK=0

# --- Flash Attention ---
$EnableTritonUseROCm = $true                 # TRITON_USE_ROCM
$FlashAttnBackend = "flash_attn_triton_amd"  # FLASH_ATTENTION_BACKEND "flash_attn_triton_amd"
$EnableUseCK = $false                        # USE_CK
$EnableFlashAttnTritonAMD = $false           # FLASH_ATTENTION_TRITON_AMD_ENABLE
$EnableFlashAttnTritonAMDAutotune = $false   # FLASH_ATTENTION_TRITON_AMD_AUTOTUNE
$EnableXFMRsUseFlashAttn = $false            # TRANSFORMERS_USE_FLASH_ATTENTION
$FlashAttnTritonAMDSeqLen = $null            # FLASH_ATTENTION_TRITON_AMD_SEQ_LEN
$VLLMUseTritonFlashAttn = $null              # VLLM_USE_TRITON_FLASH_ATTN

# --- CPU Threading ---
# <<<!!!NOT IMPLEMENTED!!!>>>
#$OmpNumThreads = # OMP_NUM_THREADS=8
#$MklNumThreads = # MKL_NUM_THREADS=8
#$NumExprNumThreads = # NUMEXPR_NUM_THREADS=8

# --- Experimental ROCm Flags ---
$MiOpenFindMode = 2           # MIOPEN_FIND_MODE
$MiOpenEnableCache = $false   # MIOPEN_ENABLE_CACHE
$HSAEnableAsyncCopy = $false  # HSA_ENABLE_ASYNC_COPY
$HSAEnableSDMA = $false       # HSA_ENABLE_SDMA

# --- MIGraphX Flags ---
# https://github.com/pnikolic-amd/ComfyUI_MIGraphX/
$PythonPath = $null   # PYTHONPATH "/opt/rocm/lib;$env:PYTHONPATH"
$MiGraphXOps = $null  # MIGRAPHX_MLIR_USE_SPECIFIC_OPS "attention"


# ==============================================================================
# 1.α VALIDATION AND ERROR HANDLING FUNCTIONS
# ==============================================================================

# Default error handling function
function Exit-ScriptWithError {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage
    )
    
    # Output the error message
    Write-Host "🛑 Script encountered an error." -ForegroundColor Yellow
    Write-Error "$ErrorMessage"
    
    # Pause and wait for user input
    Read-Host -Prompt "`nHit enter to exit"
    
    # Exit the script with a non-zero exit code (1)
    exit 1
}

# Function to validate user inputed GFX target
function Test-ValidGFXTarget {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GFXTarget
    )

    # Define the array of valid string values
    $validTargets = @(
        "gfx942", "gfx950", "gfx1100", "gfx1101",
        "gfx1102", "gfx1151", "gfx1200", "gfx1201"
    )

    # Check if the input string is in the array of valid targets
    if ($validTargets -contains $GFXTarget) {
        return $true
    } else {
        # If not valid, write a non-terminating error to the error stream
        Write-Error "❌ Invalid value provided for GFXTarget: '${GFXTarget}'. Must be one of: $($validTargets -join ', ')."
        return $false
    }
}

# Function to validate user inputs for various powers of two integer related values 
function Test-PositiveBinaryIntInRange {
    param (
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [int]$Min,

        [Parameter(Mandatory)]
        [int]$Max
    )

    [int]$v = 0 # Mandatory variable initialization to adhere to Set-StrictMode
    # Check if value is an integer
    if (-not [int]::TryParse($Value, [ref]$v)) {
        return $false
    }
    # Check if value is within range
    if ($v -lt $Min -or $v -gt $Max) {
        return $false
    }
    # Check if value is a power-of-two
    if (($v -band ($v - 1)) -eq 0) {
        return $true
    }
    # Make an exception for 3/2 * power-of-two (median of 2 powers-of-two)
    if (($v % 3) -eq 0) {
        [int]$h = $v / 3
        if (($h -band ($h - 1)) -eq 0) {
            return $true
        }
    }
    return $false
}



# ==============================================================================
# 2. SCRIPT INITIALIZATION, ENVIRONMENT SETUP AND CONFIG VALIDATION
# ==============================================================================

# Enforce Strict Mode for Reliability
# Catches common errors like using uninitialized variables.
Set-StrictMode -Version Latest 

# Define internal script paths
$VenvActivateScript = Join-Path $ComfyUIRoot "venv\Scripts\Activate.ps1"
$MainScript = Join-Path $ComfyUIRoot "main.py"
# The path that the VIRTUAL_ENV variable should be set to (ComfyUI\venv)
$ExpectedVenvPath = Join-Path $ComfyUIRoot "venv"

Write-Host "🎇 Starting ComfyUI Launch Automation..."
Write-Host "`nAssigned ComfyUI Path: " -NoNewline
Write-Host "${ComfyUIRoot}" -ForegroundColor DarkYellow -BackgroundColor DarkBlue

# --- PATH CHECK 1: Root Directory Existence ---
Write-Host "`n🔎 1. " -NoNewline
Write-Host "Validating ComfyUI installation path..." -ForegroundColor DarkMagenta
if (-not (Test-Path $ComfyUIRoot -PathType Container)) {
    Exit-ScriptWithError "❌ ComfyUI Root directory not found at: ${ComfyUIRoot}. Please verify the \$ComfyUIRoot variable."
} else {
    Write-Host "   ✔️ ComfyUI root directory located." -ForegroundColor DarkGreen
}

# --- PATH CHECK 2: Main Script Existence ---
Write-Host "`n🔎 2. "  -NoNewline
Write-Host "Validating ComfyUI main.py existence..." -ForegroundColor DarkMagenta
if (-not (Test-Path $MainScript -PathType Leaf)) {
    Exit-ScriptWithError "❌ ComfyUI main script not found at: ${MainScript}. Installation may be incomplete."
} else {
    Write-Host "   ✔️ ComfyUI main.py script located." -ForegroundColor DarkGreen
}

# --- Validate Configuration Settings ---
Write-Host "`n⚙️ 3. " -NoNewline
Write-Host "Validating configuration settings..." -ForegroundColor DarkMagenta

# Validate VRAM mode
$ValidVRAMModes = @("gpu-only", "highvram", "normalvram", "lowvram", "novram", "cpu")
if ((-not [string]::IsNullOrWhiteSpace($VRAMMode)) -and ($VRAMMode -notin $ValidVRAMModes)) {
    Exit-ScriptWithError "❌ Invalid value provided for VRAM mode: '${VRAMMode}'. Must be one of: $($ValidVRAMModes -join ', ')."
}

# Validate VRAM reserve 
if (-not [string]::IsNullOrWhiteSpace($VRAMReserve)) {
    [double]$parsedVramRsrv = 0 # Mandatory variable initialization to adhere to Set-StrictMode
    if ((-not [double]::TryParse($VRAMReserve, [ref]$parsedVramRsrv)) -or ($parsedVramRsrv -le 0)) {
        Exit-ScriptWithError "❌ Invalid value provided for VRAM reserve: '${VRAMReserve}'. Must be a positive integer or double."
    }
}

# Validate preview method
$ValidPreviewMethods = @("none", "auto", "latent2rgb", "taesd") 
if ((-not [string]::IsNullOrWhiteSpace($PreviewMethod)) -and ($PreviewMethod -notin $ValidPreviewMethods)) {
    Exit-ScriptWithError "❌ Invalid value provided for preview method: '${PreviewMethod}'. Must be one of: $($ValidPreviewMethods -join ', ')."
}

# Validate preview size
if ((-not [string]::IsNullOrWhiteSpace($PreviewSize)) -and (-not (Test-PositiveBinaryIntInRange $PreviewSize 128 1024))) { 
    Exit-ScriptWithError "❌ Invalid value provided for preview size: '${PreviewSize}'. Must be a positive power-of-2 integer between 128 and 1024." 
}

# Validate attention mode
$ValidAttentionModes = @("split", "quad", "pytorch", "flash", "sage")
if ((-not [string]::IsNullOrWhiteSpace($AttentionMode)) -and ($AttentionMode -notin $ValidAttentionModes)) {
    Exit-ScriptWithError "❌ Invalid value provided for attention mode: '${AttentionMode}'. Must be one of: $($ValidAttentionModes -join ', ')."
}

# Validate Force FP Precision
$ValidForceFP = @("fp32", "fp16")
if ((-not [string]::IsNullOrWhiteSpace($ForceFP)) -and ($ForceFP -notin $ValidForceFP)) {
    Exit-ScriptWithError "❌ Invalid value provided for force fp: '${ForceFP}'. Must be one of: $($ValidForceFP -join ', ')."
}

# Validate VAE Precision
$ValidVAE = @("fp32", "fp16", "bf16")
if ((-not [string]::IsNullOrWhiteSpace($VAEPrecision)) -and ($VAEPrecision -notin $ValidVAE)) {
    Exit-ScriptWithError "❌ Invalid value provided for VAE precision: '${VAEPrecision}'. Must be one of: $($ValidVAE -join ', ')."
}

# Validate UNET Precision
$ValidUNET = @("fp64", "fp32", "fp16", "bf16", "fp8-e4m3fn", "fp8-e5m2", "fp8-e8m0fnu")
if ((-not [string]::IsNullOrWhiteSpace($UNETPrecision)) -and ($UNETPrecision -notin $ValidUNET)) {
    Exit-ScriptWithError "❌ Invalid value provided for UNET precision: '${UNETPrecision}'. Must be one of: $($ValidUNET -join ', ')."
}

# Validate Text Encoder Precision
$ValidTextEnc = @("fp32", "fp16", "bf16", "fp8-e4m3fn", "fp8-e5m2")
if ((-not [string]::IsNullOrWhiteSpace($TextEncPrecision)) -and ($TextEncPrecision -notin $ValidTextEnc)) {
    Exit-ScriptWithError "❌ Invalid value provided for text encoder precision: '${TextEncPrecision}'. Must be one of: $($ValidTextEnc -join ', ')."
}

# Validate exlusive GPU device id
if (-not [string]::IsNullOrWhiteSpace($SetExclusiveGPU)) {
    [int]$parsedGpuId = 0 # Mandatory variable initialization to adhere to Set-StrictMode
    if ((-not [int]::TryParse($SetExclusiveGPU, [ref]$parsedGpuId)) -or ($parsedGpuId -lt 0)) {
        Exit-ScriptWithError "❌ Invalid value provided for cuda device id: '${SetExclusiveGPU}'. Must be a positive integer matching the device id. Please verify the \$SetExclusiveGPU variable."
    }
}

# Validate default GPU device id
if (-not [string]::IsNullOrWhiteSpace($SetDefaultGPU)) {
    [int]$parsedGpuId = 0 # Mandatory variable initialization to adhere to Set-StrictMode
    if ((-not [int]::TryParse($SetDefaultGPU, [ref]$parsedGpuId)) -or ($parsedGpuId -lt 0)) {
        Exit-ScriptWithError "❌ Invalid value provided for default device id: '${SetDefaultGPU}'. Must be a positive integer matching the device id. Please verify the \$SetDefaultGPU variable."
    }
}

# Validate output directory override path
if (-not [string]::IsNullOrWhiteSpace($OverrideOutputDirectory)) {
    try {
        # This will throw an exception if the path format is invalid.
        $null = [System.IO.Path]::GetFullPath($OverrideOutputDirectory)
    }
    catch {
        Exit-ScriptWithError "❌ Invalid path specified for output directory override: '${OverrideOutputDirectory}'. Please verify the \$OverrideOutputDirectory variable."
    }
}

# Validate remote access
if ($EnableRemoteAccess) {
    # Validate remote access IP address
    if (-not [string]::IsNullOrWhiteSpace($ListenIPAddress)) {
        try {
            # Attempt to cast the string to an IP address object.
            # This will fail and trigger the catch block if the format or octet values are invalid.
            $null = [ipaddress]$ListenIPAddress
        }
        catch {
            Exit-ScriptWithError "❌ Invalid value provided for listen IP address: '${ListenIPAddress}' . Please verify the \$ListenIPAddress variable."
        }
    } else {
        Exit-ScriptWithError "❌ Remote access was enabled but no value was provided for listen IP address. Please verify the \$ListenIPAddress variable."
    }

    # Validate remote access port 
    if (-not [string]::IsNullOrWhiteSpace($ListenPort)) {
        [int]$parsedPort = 0 # Mandatory variable initialization to adhere to Set-StrictMode
        if ((-not [int]::TryParse($ListenPort, [ref]$parsedPort)) -or ($parsedPort -lt 1024 -or $parsedPort -gt 65535)) {
            Exit-ScriptWithError "❌ Invalid value provided for listen port: '${ListenPort}'. Please verify the \$ListenPort variable."
        }
    } else {
        Exit-ScriptWithError "❌ Remote access was enabled but no value was provided for listen port. Please verify the \$ListenPort variable."
    }
}

Write-Host "   ✔️ Configuration validated." -ForegroundColor DarkGreen

# --- Virtual Environment Activation ---
Write-Host "`n🔎 4. " -NoNewline
Write-Host "Checking for Python virtual environment..." -ForegroundColor DarkMagenta
if (-not (Test-Path $VenvActivateScript)) {
    Exit-ScriptWithError "❌ Virtual environment activation script not found at: ${VenvActivateScript}.
    Ensure the venv exists and was created with support for PowerShell activation (Activate.ps1).
    Aborting script."
}

# Check if a venv is already active
if ($env:VIRTUAL_ENV -ne $null) {
    if ($env:VIRTUAL_ENV -eq $ExpectedVenvPath) {
        Write-Host "   ✔️ Correct Python virtual environment is already active: $($env:VIRTUAL_ENV). Skipping activation." -ForegroundColor DarkYellow
    } else {
        Write-Warning "   ⚠️ A DIFFERENT Python virtual environment is active: $($env:VIRTUAL_ENV). Attempting to activate the ComfyUI venv, which should deactivate the existing one."
        # The dot-sourcing operator (.) executes the script in the current scope
        . $VenvActivateScript
    }
} else {
    # No venv is active, proceed with normal activation
    Write-Host "   ✔️ No virtual environment conflicts detected." -ForegroundColor DarkGreen
    Write-Host "`n🐍 5. Activating Python virtual environment..."
    . $VenvActivateScript
}

# Final check to ensure the desired environment is active after running the activation script
if (-not $env:VIRTUAL_ENV) {
    Exit-ScriptWithError "❌ Failed to activate virtual environment. The '${VenvActivateScript}' script did not set \$env:VIRTUAL_ENV. Aborting."
}

# --- CRITICAL PATH CHECK 3: Python Executable Check ---
# Ensure 'python' is now accessible via the PATH provided by the venv
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Exit-ScriptWithError "❌ The 'python' executable could not be found after virtual environment activation. Please check your venv integrity."
}

Write-Host "   ✔️ Python virtual environment activated successfully." -ForegroundColor DarkGreen
Write-Host "   Python Path: " -NoNewline
Write-Host "$( (Get-Command python).Path )" -ForegroundColor DarkYellow -BackgroundColor DarkBlue

# --- Set Environment Variables ---
Write-Host "`n🔣 6. Setting environment variables..."
if ($EnableAOTriton) {
    $env:TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL = "1"
    Write-Host "   TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL = " -NoNewline
    Write-Host "'$($env:TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL)'" -ForegroundColor Blue
}

if ($EnableTunableOP) {
    $env:PYTORCH_TUNABLEOP_ENABLED = "1"
    Write-Host "   PYTORCH_TUNABLEOP_ENABLED = " -NoNewline
    Write-Host "'$($env:PYTORCH_TUNABLEOP_ENABLED)'" -ForegroundColor Blue
}

if ((-not [string]::IsNullOrWhiteSpace($HCCAMDGPUTarget)) -and (Test-ValidGFXTarget -GFXTarget $HCCAMDGPUTarget)) {
    $env:HCC_AMDGPU_TARGET = $HCCAMDGPUTarget
    Write-Host "   HCC_AMDGPU_TARGET = " -NoNewline
    Write-Host "'$($env:HCC_AMDGPU_TARGET)'" -ForegroundColor Blue
}

if ((-not [string]::IsNullOrWhiteSpace($PytorchROCmArch)) -and (Test-ValidGFXTarget -GFXTarget $PytorchROCmArch)) {
    $env:PYTORCH_ROCM_ARCH = $PytorchROCmArch
    Write-Host "   PYTORCH_ROCM_ARCH = " -NoNewline
    Write-Host "'$($env:PYTORCH_ROCM_ARCH)'" -ForegroundColor Blue
}

if ($PytorchHIPAllocConf -and ($PytorchHIPAllocConf.Count -ge 2)) {
    [double]$gcThreshold = 0.0 # Mandatory variable initialization to adhere to Set-StrictMode
    [int]$maxSplit = 0 # Mandatory variable initialization to adhere to Set-StrictMode
    if (([double]::TryParse($PytorchHIPAllocConf[0], [ref]$gcThreshold)) -and ($gcThreshold -gt 0.0) -and ($gcThreshold -lt 1.0) -and
        ([int]::TryParse($PytorchHIPAllocConf[1], [ref]$maxSplit)) -and (Test-PositiveBinaryIntInRange $maxSplit 128 4096)) {
            $env:PYTORCH_HIP_ALLOC_CONF = "garbage_collection_threshold:$($PytorchHIPAllocConf[0]),max_split_size_mb:$($PytorchHIPAllocConf[1])"
            Write-Host "   PYTORCH_HIP_ALLOC_CONF = " -NoNewline
            Write-Host "'$($env:PYTORCH_HIP_ALLOC_CONF)'" -ForegroundColor Blue
    }
}

if ((-not [string]::IsNullOrWhiteSpace($TritonOverrideArch)) -and (Test-ValidGFXTarget -GFXTarget $TritonOverrideArch)) {
    $env:TRITON_OVERRIDE_ARCH = $TritonOverrideArch
    Write-Host "   TRITON_OVERRIDE_ARCH = " -NoNewline
    Write-Host "'$($env:TRITON_OVERRIDE_ARCH)'" -ForegroundColor Blue
}

if ($EnableTritonUseROCm) {
    $env:TRITON_USE_ROCM = "ON"
    Write-Host "   TRITON_USE_ROCM = " -NoNewline
    Write-Host "'$($env:TRITON_USE_ROCM)'" -ForegroundColor Blue
}

if (-not [string]::IsNullOrWhiteSpace($FlashAttnBackend)) {
    $env:FLASH_ATTENTION_BACKEND = $FlashAttnBackend
    Write-Host "   FLASH_ATTENTION_BACKEND = " -NoNewline
    Write-Host "'$($env:FLASH_ATTENTION_BACKEND)'" -ForegroundColor Blue
}

if ($EnableUseCK) {
    $env:USE_CK = "ON"
    Write-Host "   USE_CK = " -NoNewline
    Write-Host "'$($env:USE_CK)'" -ForegroundColor Blue
}

if ($EnableFlashAttnTritonAMD) {
    $env:FLASH_ATTENTION_TRITON_AMD_ENABLE = "TRUE"
    Write-Host "   FLASH_ATTENTION_TRITON_AMD_ENABLE = " -NoNewline
    Write-Host "'$($env:FLASH_ATTENTION_TRITON_AMD_ENABLE)'" -ForegroundColor Blue
}

if ($EnableFlashAttnTritonAMDAutotune) {
    $env:FLASH_ATTENTION_TRITON_AMD_AUTOTUNE = "TRUE"
    Write-Host "   FLASH_ATTENTION_TRITON_AMD_AUTOTUNE = " -NoNewline
    Write-Host "'$($env:FLASH_ATTENTION_TRITON_AMD_AUTOTUNE)'" -ForegroundColor Blue
}

if ($EnableXFMRsUseFlashAttn) {
    $env:TRANSFORMERS_USE_FLASH_ATTENTION = "1"
    Write-Host "   TRANSFORMERS_USE_FLASH_ATTENTION = " -NoNewline
    Write-Host "'$($env:TRANSFORMERS_USE_FLASH_ATTENTION)'" -ForegroundColor Blue
}

if ((-not [string]::IsNullOrWhiteSpace($FlashAttnTritonAMDSeqLen)) -and (Test-PositiveBinaryIntInRange $FlashAttnTritonAMDSeqLen 128 4096)) {
    $env:FLASH_ATTENTION_TRITON_AMD_SEQ_LEN = $FlashAttnTritonAMDSeqLen
    Write-Host "   FLASH_ATTENTION_TRITON_AMD_SEQ_LEN = " -NoNewline
    Write-Host "'$($env:FLASH_ATTENTION_TRITON_AMD_SEQ_LEN)'" -ForegroundColor Blue
}

if ($VLLMUseTritonFlashAttn) {
    $env:VLLM_USE_TRITON_FLASH_ATTN = "0"
    Write-Host "   VLLM_USE_TRITON_FLASH_ATTN = " -NoNewline
    Write-Host "'$($env:VLLM_USE_TRITON_FLASH_ATTN)'" -ForegroundColor Blue
}

if (-not [string]::IsNullOrWhiteSpace($MiOpenFindMode)) { 
    [int]$parsedMOFindMode = 0 # Mandatory variable initialization to adhere to Set-StrictMode
    if (([int]::TryParse($MiOpenFindMode, [ref]$parsedMOFindMode)) -and ($parsedMOFindMode -ge 1) -and ($parsedMOFindMode -le 5)) {
        $env:MIOPEN_FIND_MODE = $MiOpenFindMode
        Write-Host "   MIOPEN_FIND_MODE = " -NoNewline
        Write-Host "'$($env:MIOPEN_FIND_MODE)'" -ForegroundColor Blue
    }
}

if ($MiOpenEnableCache) {
    $env:MIOPEN_ENABLE_CACHE = "1"
    Write-Host "   MIOPEN_ENABLE_CACHE = " -NoNewline
    Write-Host "'$($env:MIOPEN_ENABLE_CACHE)'" -ForegroundColor Blue
}

if ($HSAEnableAsyncCopy) {
    $env:HSA_ENABLE_ASYNC_COPY = "1"
    Write-Host "   HSA_ENABLE_ASYNC_COPY = " -NoNewline
    Write-Host "'$($env:HSA_ENABLE_ASYNC_COPY)'" -ForegroundColor Blue
}

if ($HSAEnableSDMA) {
    $env:HSA_ENABLE_SDMA = "1"
    Write-Host "   HSA_ENABLE_SDMA = " -NoNewline
    Write-Host "'$($env:HSA_ENABLE_SDMA)'" -ForegroundColor Blue
}

if (-not [string]::IsNullOrWhiteSpace($PythonPath)) {
    $env:PYTHONPATH = $PythonPath
    Write-Host "   PYTHONPATH = " -NoNewline
    Write-Host "'$($env:PYTHONPATH)'" -ForegroundColor Blue
}

if (-not [string]::IsNullOrWhiteSpace($MiGraphXOps)) {
    $env:MIGRAPHX_MLIR_USE_SPECIFIC_OPS = $MiGraphXOps
    Write-Host "   MIGRAPHX_MLIR_USE_SPECIFIC_OPS = " -NoNewline
    Write-Host "'$($env:MIGRAPHX_MLIR_USE_SPECIFIC_OPS)'" -ForegroundColor Blue
}



# ==============================================================================
# 3. CLI ARGUMENT CONSTRUCTION
# ==============================================================================

Write-Host "`n🛠️ 7. Building ComfyUI launch arguments..."

# Mandatory Base Arguments
$Arguments = @("--auto-launch")

# Add VRAM mode argument
if (-not [string]::IsNullOrWhiteSpace($VRAMMode)) {
    Write-Host "   -> Adding VRAM flag " -NoNewline
    Write-Host "[--${VRAMMode}]" -ForegroundColor Blue
    $Arguments += "--${VRAMMode}"
}

# Add --reserve-vram argument
if (-not [string]::IsNullOrWhiteSpace($VRAMReserve)) {
    Write-Host "   -> Adding reserve VRAM flag " -NoNewline
    Write-Host "[--reserve-vram ${VRAMReserve}]" -ForegroundColor Blue
    $Arguments += "--reserve-vram", $VRAMReserve
}

# Add --preview-method argument
if (-not [string]::IsNullOrWhiteSpace($PreviewMethod)) {
    Write-Host "   -> Adding preview method flag " -NoNewline
    Write-Host "[--preview-method ${PreviewMethod}]" -ForegroundColor Blue
    $Arguments += "--preview-method", $PreviewMethod
}

# Add --preview-size argument
if (-not [string]::IsNullOrWhiteSpace($PreviewSize)) {
    Write-Host "   -> Adding preview size flag " -NoNewline
    Write-Host "[--preview-size ${PreviewSize}]" -ForegroundColor Blue
    $Arguments += "--preview-size", $PreviewSize
}

# Attention Mode Toggles
switch ($AttentionMode) {
    "split" {
        Write-Host "   -> Adding attention flag " -NoNewline
        Write-Host "[--use-split-cross-attention]" -ForegroundColor Blue
        $Arguments += "--use-split-cross-attention"
    }
    "quad" {
        Write-Host "   -> Adding attention flag " -NoNewline
        Write-Host "[--use-quad-cross-attention]" -ForegroundColor Blue
        $Arguments += "--use-quad-cross-attention"
    }
    "pytorch" {
        Write-Host "   -> Adding attention flag " -NoNewline
        Write-Host "[--use-pytorch-cross-attention]" -ForegroundColor Blue
        $Arguments += "--use-pytorch-cross-attention"
    }
    "flash" {
        Write-Host "   -> Adding attention flag " -NoNewline
        Write-Host "[--use-flash-attention]" -ForegroundColor Blue
        $Arguments += "--use-flash-attention"
    }
    "sage" {
        Write-Host "   -> Adding attention flag " -NoNewline
        Write-Host "[--use-sage-attention]" -ForegroundColor Blue
        $Arguments += "--use-sage-attention"
    }
    default {
        Write-Host "   -> No Attention mode selected, deferring to defaults."
    }
}

# Optional --supports-fp8-compute toggle
if ($SupportFP8) {
    Write-Host "   -> Adding FP8 flag " -NoNewline
    Write-Host "[--supports-fp8-compute]" -ForegroundColor Blue
    $Arguments += "--supports-fp8-compute"
}

# Optional Force FP Precision
switch ($ForceFP) {
    "fp32" {
        Write-Host "   -> Adding force fp32 flag " -NoNewline
        Write-Host "[--force-fp32]" -ForegroundColor Blue
        $Arguments += "--force-fp32"
    }
    "fp16" {
        Write-Host "   -> Adding force fp16 flag " -NoNewline
        Write-Host "[--force-fp16]" -ForegroundColor Blue
        $Arguments += "--force-fp16"
    }
    default {
        Write-Host "   -> No force FP precision selected, deferring to defaults."
    }
}

# Optional VAE Precision
switch ($VAEPrecision) {
    "fp32" {
        Write-Host "   -> Adding VAE fp32 flag " -NoNewline
        Write-Host "[--fp32-vae]" -ForegroundColor Blue
        $Arguments += "--fp32-vae"
    }
    "fp16" {
        Write-Host "   -> Adding VAE fp16 flag " -NoNewline
        Write-Host "[--fp16-vae]" -ForegroundColor Blue
        $Arguments += "--fp16-vae"
    }
    "bf16" {
        Write-Host "   -> Adding VAE bf16 flag " -NoNewline
        Write-Host "[--bf16-vae]" -ForegroundColor Blue
        $Arguments += "--bf16-vae"
    }
    default {
        Write-Host "   -> No VAE precision selected, deferring to defaults."
    }
}

# Optional UNET Precision
switch ($UNETPrecision) {
    "fp64" {
        Write-Host "   -> Adding UNET fp64 flag " -NoNewline
        Write-Host "[--fp64-unet]" -ForegroundColor Blue
        $Arguments += "--fp64-unet"
    }
    "fp32" {
        Write-Host "   -> Adding UNET fp32 flag " -NoNewline
        Write-Host "[--fp32-unet]" -ForegroundColor Blue
        $Arguments += "--fp32-unet"
    }
    "fp16" {
        Write-Host "   -> Adding UNET fp16 flag " -NoNewline
        Write-Host "[--fp16-unet]" -ForegroundColor Blue
        $Arguments += "--fp16-unet"
    }
    "bf16" {
        Write-Host "   -> Adding UNET bf16 flag " -NoNewline
        Write-Host "[--bf16-unet]" -ForegroundColor Blue
        $Arguments += "--bf16-unet"
    }
    "fp8-e4m3fn" {
        Write-Host "   -> Adding UNET fp8 e4m3fn flag " -NoNewline
        Write-Host "[--fp8_e4m3fn-unet]" -ForegroundColor Blue
        $Arguments += "--fp8_e4m3fn-unet"
    }
    "fp8-e5m2" {
        Write-Host "   -> Adding UNET fp8 e5m2 flags " -NoNewline
        Write-Host "[--fp8_e5m2-unet]" -ForegroundColor Blue
        $Arguments += "--fp8_e5m2-unet"
    }
    "fp8-e8m0fnu" {
        Write-Host "   -> Adding UNET fp8 e8m0fnu flag " -NoNewline
        Write-Host "[--fp8_e8m0fnu-unet]" -ForegroundColor Blue
        $Arguments += "--fp8_e8m0fnu-unet"
    }
    default {
        Write-Host "   -> No UNET precision selected, deferring to defaults."
    }
}

# Optional Text Encoder Precision
switch ($TextEncPrecision) {
    "fp32" {
        Write-Host "   -> Adding text encoder fp32 flag " -NoNewline
        Write-Host "[--fp32-text-enc]" -ForegroundColor Blue
        $Arguments += "--fp32-text-enc"
    }
    "fp16" {
        Write-Host "   -> Adding text encoder fp16 flag " -NoNewline
        Write-Host "[--fp16-text-enc]" -ForegroundColor Blue
        $Arguments += "--fp16-text-enc"
    }
    "bf16" {
        Write-Host "   -> Adding text encoder bf16 flag " -NoNewline
        Write-Host "[--bf16-text-enc]" -ForegroundColor Blue
        $Arguments += "--bf16-text-enc"
    }
    "fp8-e4m3fn" {
        Write-Host "   -> Adding text encoder fp8 e4m3fn flag " -NoNewline
        Write-Host "[--fp8_e4m3fn-text-enc]" -ForegroundColor Blue
        $Arguments += "--fp8_e4m3fn-text-enc"
    }
    "fp8-e5m2" {
        Write-Host "   -> Adding text encoder fp8 e5m2 flags " -NoNewline
        Write-Host "[--fp8_e5m2-text-enc]" -ForegroundColor Blue
        $Arguments += "--fp8_e5m2-text-enc"
    }
    default {
        Write-Host "   -> No text encoder precision selected, deferring to defaults."
    }
}

# Optional --cuda-device toggle
if (-not [string]::IsNullOrWhiteSpace($SetExclusiveGPU)) {
    Write-Host "   -> Adding exclusive device id flag " -NoNewline
    Write-Host "[--cuda-device ${SetExclusiveGPU}]" -ForegroundColor Blue
    $Arguments += "--cuda-device", $SetExclusiveGPU
}

# Optional --default-device toggle
if (-not [string]::IsNullOrWhiteSpace($SetDefaultGPU)) {
    Write-Host "   -> Adding default device id flag " -NoNewline
    Write-Host "[--default-device ${SetDefaultGPU}]" -ForegroundColor Blue
    $Arguments += "--default-device", $SetDefaultGPU
}

# Optional --fast toggle
if ($EnableFastPerfOps) {
    Write-Host "   -> Adding all untested performance features flag " -NoNewline
    Write-Host "[--fast]" -ForegroundColor Blue
    $Arguments += "--fast"
}

# Optional --force-upcast-attention toggle
if ($EnableForceUpcastAttention) {
    Write-Host "   -> Adding force upcast flag " -NoNewline
    Write-Host "[--force-upcast-attention]" -ForegroundColor Blue
    $Arguments += "--force-upcast-attention"
}

# Optional --force-channels-last toggle
if ($EnableForceLastFormat) {
    Write-Host "   -> Adding force channeling last format flag " -NoNewline
    Write-Host "[--force-channels-last]" -ForegroundColor Blue
    $Arguments += "--force-channels-last"
}

# Optional --cache-none toggle
if ($EnableCacheNone) {
    Write-Host "   -> Adding no cache flag " -NoNewline
    Write-Host "[--cache-none]" -ForegroundColor Blue
    $Arguments += "--cache-none"
}

# Optional --disable-smart-memory toggle
if ($DisableSmartMemory) {
    Write-Host "   -> Adding aggressive RAM offloading flag " -NoNewline
    Write-Host "[--disable-smart-memory]" -ForegroundColor Blue
    $Arguments += "--disable-smart-memory"
}

# Optional --async-offload toggle
if ($EnableAsyncOffload) {
    Write-Host "   -> Adding async weight offloading flag " -NoNewline
    Write-Host "[--async-offload]" -ForegroundColor Blue
    $Arguments += "--async-offload"
}

# Optional --force-non-blocking toggle
if ($EnableForceNonBlocking) {
    Write-Host "   -> Adding force non-blocking ops flag " -NoNewline
    Write-Host "[--force-non-blocking]" -ForegroundColor Blue
    $Arguments += "--force-non-blocking"
}

# Optional --output-directory toggle
if (-not [string]::IsNullOrWhiteSpace($OverrideOutputDirectory)) {
    Write-Host "   -> Adding override ouput directory flag " -NoNewline
    Write-Host "[--output-directory ${OverrideOutputDirectory}]" -ForegroundColor Blue
    $Arguments += "--output-directory", $OverrideOutputDirectory
}

# Optional --listen & --port toggle
if ($EnableRemoteAccess) {
    Write-Host "   -> Adding network flags " -NoNewline
    Write-Host "[--listen ${ListenIPAddress}] [--port ${ListenPort}]" -ForegroundColor Blue
    $Arguments += "--listen", $ListenIPAddress, "--port", $ListenPort
    Write-Warning "   ⚠️ Remote access enabled on ${ListenIPAddress}:${ListenPort}."
}

# Optional --quick-test-for-ci toggle
if ($EnableCLIQuickTest) {
    Write-Host "   -> Adding CLI quick test flag " -NoNewline
    Write-Host "[--quick-test-for-ci]" -ForegroundColor Blue
    $Arguments += "--quick-test-for-ci"
    Write-Warning "   ⚠️ CLI quick test mode activated."
}

# Optional --disable-all-custom-nodes
if ($DisableCustomNodes) {
    Write-Host "   -> Adding disable custom nodes flag " -NoNewline
    Write-Host "[--disable-all-custom-nodes]" -ForegroundColor Blue
    $Arguments += "--disable-all-custom-nodes"
    Write-Warning "   ⚠️ All custom nodes disabled."
}

# Optional --disable-api-nodes
if ($DisableAPINodes) {
    Write-Host "   -> Adding disable api nodes flag " -NoNewline
    Write-Host "[--disable-api-nodes]" -ForegroundColor Blue
    $Arguments += "--disable-api-nodes"
    Write-Warning "   ⚠️ All API nodes disabled."
}



# ==============================================================================
# 4. EXECUTION AND CLEANUP
# ==============================================================================

# Change directory to the ComfyUI root before execution
Write-Host "`n📂 8. Changing directory to ComfyUI root..."
try {
    Set-Location $ComfyUIRoot -ErrorAction Stop
}
catch {
    Exit-ScriptWithError "❌ Failed to change directory to '${ComfyUIRoot}'. The directory might be locked or inaccessible."
}

try {
    Write-Host "`n🚀 9. Launching ComfyUI...`n"
    Write-Host "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "░░░░░░░░░░░▒▒░▒▒░▒▒░▒▒▒▒▒▒▒▒▒▒▒▓▓▒▓▓▒▓▓▒▓▓▓▓▓▓▓▓▓▓▌▌▌ FULL COMMAND ▐▐▐▓▓▓▓▓▓▓▓▓▓▒▓▓▒▓▓▒▓▓▒▒▒▒▒▒▒▒▒▒▒░▒▒░▒▒░▒▒░░░░░░░░░░░" -ForegroundColor DarkCyan
    Write-Host "python ${MainScript} $($Arguments -join ' ')" -ForegroundColor White
    Write-Host "░░░░░░░░░░░▒▒░▒▒░▒▒░▒▒▒▒▒▒▒▒▒▒▒▓▓▒▓▓▒▓▓▒▓▓▓▓▓▓▓▓▓▓█▓▓█▓▓████████▓▓█▓▓█▓▓▓▓▓▓▓▓▓▓▒▓▓▒▓▓▒▓▓▒▒▒▒▒▒▒▒▒▒▒░▒▒░▒▒░▒▒░░░░░░░░░░░" -ForegroundColor DarkCyan
    Write-Host "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════`n" -ForegroundColor DarkCyan

    if ($ConfirmBeforeLaunching) {
        Write-Host "Proceed ? " -NoNewline -ForegroundColor DarkYellow
        Write-Host "[ " -NoNewline
        Write-Host "Y" -NoNewline -ForegroundColor DarkGreen
        Write-Host " / " -NoNewline
        Write-Host "N" -NoNewline -ForegroundColor DarkRed
        $confirm = Read-Host " ]`n"
        if ($confirm -notin @('Y','y')) {
            Exit-ScriptWithError "User aborted." 
        }
    }

    # Use the call operator (&) to execute the Python script with the array of arguments.
    & python $MainScript $Arguments
}
catch {
    # This catches errors in PowerShell's execution of the Python command itself.
    # We check if the error was NOT caused by Ctrl+C (PipelineStoppedException).
    if ($_.Exception.GetType().Name -ne 'PipelineStoppedException') {
        Write-Error "❌ A PowerShell error occurred during ComfyUI process initiation: $($_.Exception.Message)"
    }
    # If it was Ctrl+C, we do nothing and let the 'finally' block take over.
}
finally {
    #  Check the exit code of the Python process to determine if ComfyUI is restarting or terminating.
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n======================================="
        Write-Host "`n♻️ ComfyUI clean exit detected (restart initiated by manager)." -ForegroundColor DarkGreen
        Write-Host "   Skipping environment cleanup to allow for a seamless restart."
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "⚠️ ComfyUI process exited with a non-zero exit code ($LASTEXITCODE). This typically indicates an internal application failure, crash or user interrupt."

        Write-Host "`n======================================="
        Write-Host "`n🛑 ComfyUI session ended."
        Write-Host "🧹 10. Performing environment cleanup..."

        # --- Environment Variable Cleanup ---
        # Remove the temporary environment variables set for the session
        Remove-Item Env:\TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\PYTORCH_TUNABLEOP_ENABLED -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\PYTORCH_HIP_ALLOC_CONF -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\HCC_AMDGPU_TARGET -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\PYTORCH_ROCM_ARCH -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\TRITON_OVERRIDE_ARCH -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\TORCH_BLAS_PREFER_HIPBLASLT -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\TORCHINDUCTOR_MAX_AUTOTUNE_GEMM_BACKENDS -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\TORCHINDUCTOR_MAX_AUTOTUNE_GEMM_SEARCH_SPACE -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\TORCHINDUCTOR_FORCE_FALLBACK -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\TRITON_USE_ROCM -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\FLASH_ATTENTION_BACKEND -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\USE_CK -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\FLASH_ATTENTION_TRITON_AMD_ENABLE -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\FLASH_ATTENTION_TRITON_AMD_AUTOTUNE -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\TRANSFORMERS_USE_FLASH_ATTENTION -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\FLASH_ATTENTION_TRITON_AMD_SEQ_LEN -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\VLLM_USE_TRITON_FLASH_ATTN -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\OMP_NUM_THREADS -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\MKL_NUM_THREADS -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\NUMEXPR_NUM_THREADS -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\MIOPEN_FIND_MODE -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\MIOPEN_ENABLE_CACHE -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\HSA_ENABLE_ASYNC_COPY -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\HSA_ENABLE_SDMA -Force -ErrorAction SilentlyContinue

        Write-Host "🗑️ Temporary environment variables cleaned." -ForegroundColor DarkGreen

        # --- Virtual Environment Deactivation ---
        # The Activate.ps1 script defines a 'deactivate' function in the current scope.
        # We call it to reverse the PATH and VIRTUAL_ENV changes.
        if (Get-Command deactivate -ErrorAction SilentlyContinue) {
            Write-Host "🐍 Deactivating Python virtual environment..."
            deactivate
        } else {
            Write-Warning "⚠️ Could not find 'deactivate' function. Virtual environment may still be active in this shell session."
        }

        Write-Host "✨ Clean-up operations finished." -ForegroundColor DarkGreen
        Read-Host -Prompt "`n👋 Hit enter to close this terminal window"
    }
}
# -------------------------------------------------------------------------------------
# NOTE on closing the terminal:
# We do not automatically close the terminal using 'exit' or similar commands.
# This ensures the user can review the log output, confirm cleanup, and see any errors.
# To close the terminal automatically, the user would need to wrap this script
# execution in a separate batch file or modify this script with 'exit' at the end.