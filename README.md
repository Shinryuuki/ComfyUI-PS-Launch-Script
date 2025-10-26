## ⚠️ Disclaimer  
This PowerShell script is a personal side-project primarily developed for my individual use and specific system configuration. 
It is hosted publicly on GitHub for convenience and as a backup, not as a formally supported or productized tool. 

<br/>

> [!WARNING]
> Use of this script by anyone other than the repository owner is done entirely <ins>at the user's own risk</ins>.  
> While preliminary validations are in-place, this script has not been thoroughly tested and **may contain bugs, errors, or unexpected behaviors**.

<br/>

> [!NOTE]
> This script is mostly tailored towards **AMD RDNA4 systems (specifically gfx1201) running [ROCm natively on Windows](https://github.com/ROCm/TheRock/blob/main/RELEASES.md)** and is designed around that architecture's environment and requirements.  
> It can be adapted to work with NVIDIA GPUs, though it will require some tweaking (e.g., environment variables) by the user to function correctly.

<br/>

**Support will be extremely limited / non-existent** as this was intended solely for my own personal use. Issues will not be regularly monitored, and pull requests or feature requests are unlikely to be addressed.  
<br/>
Users are expressly **permitted to fork this repository and make any changes** they deem necessary to adapt the script for their own needs.  
<br/>
By using this script, you acknowledge that you are responsible for any modifications, debugging, or troubleshooting required to make it work on your specific system.  

<br/>

## 🖥️ Launch-ComfyUI.ps1  
A custom PowerShell script that automates the launch of a manual install of ComfyUI with configurable CLI arguments and environment variables.

<br/>

## 🎨 Features  
1. Defines paths and configuration settings.
2. Performs path and file existence checks and configuration validation.
3. Checks for and activates the Python virtual environment (venv).
4. Sets environment variables.
5. Dynamically builds the argument list based on configuration toggles.
6. Executes main.py from the ComfyUI root directory.
7. Handles cleanup when ComfyUI instance is terminated.

<br/>

## 📝 To-Do  
- [ ] Create helper function for repetitive Write-Host calls (for printing CLI arguments and environment variable messages).
- [ ] Refactor CLI argument building with a splatting hashtable instead of using an array.
- [ ] Refactor environment variables to use explicit strings.
- [ ] Parameterize the script by refactoring configuration variables into a param() block (partially redundant since ComfyUI's main.py already supports parameterized calls).

<br/>

## ⚖️ Liability Limitation  
> [!CAUTION]
> In no event shall the repository owner be liable for any damages (including, without limitation, lost profits, data loss, or system damage) arising out of the use or inability to use this software.  
> **You assume all responsibility and risk for the use of this script.**
