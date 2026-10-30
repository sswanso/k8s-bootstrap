# 📖 Workshop WSL2 Windows 11 Setup

## Automated WSL Setup

### What does `Setup-WSL2-Windows11.ps1` do?
This script automates the creation of a secure, proxy-aware Linux environment for the workshop without messing up your personal settings. It does this by executing these tasks:
1. **Configures Proxy Passthrough (`.wslconfig`):** Ensures WSL2 automatically inherits your corporate proxy setting dynamically from Windows.
2. **System Feature Verification:** Scans and enables the Windows hypervisor features (WSL Engine & Virtual Machine Platform).
3. **Installs the Linux Environment:** Downloads the default stable Ubuntu package from Microsoft, registers it cleanly, and binds it to your isolated workshop workspace, `breaking-kubernetes`.

---

### How to run the automated script:
1. Click the **Start Menu**, search for **PowerShell**.
2. Right-click **Windows PowerShell** and select **Run as Administrator** (Required to configure virtual features).
3. Execute the script by pasting the command below (or by dragging your saved `.ps1` file into the terminal):
   ```powershell
   .\Setup-WSL2-Windows11.ps1
   ```
4. **Note on Rebooting:** If the virtual machine features were not previously enabled on your corporate laptop, the script will halt and prompt you to reboot. Save your work, restart your machine, reopen PowerShell as Administrator, and run the script one more time to complete the Ubuntu download.

#### Troubleshooting
##### Security Policy

In case you get an error that says the setup script cannot be run because running scripts is disabled on this system, there are two things to do.
First, try running the script with the execution policy bypass flag like this:
```powershell
PowerShell -ExecutionPolicy Bypass -File .\Setup-WSL2-Windows11.ps1
```
And if the system complains because the script is unsigned, you can unblock execution of the file by running this command:
```powershell
Unblock-File -Path .\Setup-WSL2-Windows11.ps1
```

---

## Manual Step-by-Step Installation (Alternative to Automated Setup)

If you prefer to run the setup commands manually you can achieve the exact same configuration by following these manual command line steps.

### Step 1: Create the Global Proxy Config File
WSL needs to know it must inherit the Windows proxy settings.
1. Open PowerShell or Command Prompt.
2. Run the following command to write the `.wslconfig` file directly into your User Profile folder:
   ```powershell
   Set-Content -Path "$env:USERPROFILE\.wslconfig" -Value "[wsl2]`r`nautoProxy=true"
   ```

---

### Step 2: Enable WSL Virtualization Features
You must manually enable the Windows Subsystem for Linux and the Hypervisor platform.
1. Open **PowerShell as an Administrator**
2. Run these two commands to register the required Windows Features:
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart
   Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart
   ```
3. **Reboot your laptop now** to load these drivers into the active Windows kernel.

---

### Step 3: Install the "breaking-kubernetes" Distribution
After restarting your laptop, download the default Ubuntu image and assign it your specific workshop name.
1. Open **PowerShell as an Administrator**.
2. Set your default system architecture to WSL 2:
   ```powershell
   wsl --set-default-version 2
   ```
3. Run the installer specifying the default Ubuntu distribution, but register it under the workshop name. **Include the `--no-launch` flag so it registers silently in the background:**
   ```powershell
   wsl --install -d Ubuntu --name breaking-kubernetes --no-launch
   ```

---

### Step 4: Access and Verify Your Environment
You can now access your clean Linux workspace.
1. To enter your dedicated shell, run:
   ```powershell
   wsl -d breaking-kubernetes
   ```
2. Verify that WSL is routing traffic through your corporate proxy by checking your default shell variables:
   ```bash
   echo $http_proxy
   # Output should confirm your proxy has been inherited automatically
   ```
