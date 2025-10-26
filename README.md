# ComfyUI-PS-Launch-Script
A custom PowerShell script that automates the launch of a manual install of ComfyUI with configurable CLI arguments and environment variables.




# Features
1. Defines paths and configuration settings.
2. Performs path and file existence checks and configuration validation.
3. Checks for and activates the Python virtual environment (venv).
4. Sets environment variables.
5. Dynamically builds the argument list based on configuration toggles.
6. Executes main.py from the ComfyUI root directory and handles cleanup.
7. Handles cleanup when ComfyUI instance is terminated.




# To Do
- Create helper function for repetitive Write-Host calls (for printing CLI arguments and environment variable messages).
- Refactor CLI argument building with a splatting hashtable instead of using an array.
- Refactor environment variables to use explicit strings.
- Parameterize the script by refactoring configuration variables into a param() block (partially redundant since ComfyUI's main.py already supports parameterized calls).
