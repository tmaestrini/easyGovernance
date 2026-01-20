# Select Base Image for Docker
# Image 'lts-7.4-debian-12' provides PowerShell 7.4.7 (required for PnP.PowerShell 3.1.0 minimum version 7.4.6)
# Note: Only supports linux/amd64 - will run under emulation (Rosetta 2) on Apple Silicon Macs
# Compatible with Windows (Intel/AMD), Mac Intel, and Mac M1-M4 (via emulation)
FROM mcr.microsoft.com/powershell:lts-7.4-debian-12

# Install 'xdg-utils' to support Interactive Logons
RUN apt-get update
RUN apt-get install xdg-utils -y

# Install Powershell Moduels to Support Installation
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name powershell-yaml"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name PnP.Powershell -RequiredVersion 3.1.0"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name PSLogs -RequiredVersion 5.2.1"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name MarkdownPS -RequiredVersion 1.9"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name MarkdownToHtml -RequiredVersion 2.7.1"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name EPS -RequiredVersion 1.0.0"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name Pester -RequiredVersion 5.7.1"

# Overwrites Default Shell to PowerShell
SHELL [ "pwsh", "-c" ]