# Select Base Image for Docker
# Image 'lts-debian-12' provides PowerShell 7.4.x LTS (required for PnP.PowerShell 3.1.0 minimum version 7.4.6)
# Note: Explicitly set platform for compatibility
# Compatible with Windows (Intel/AMD), Mac Intel, and Mac M1-M4 (via emulation)
FROM mcr.microsoft.com/powershell:lts-debian-12

# Install 'xdg-utils' to support Interactive Logons
RUN apt-get update
RUN apt-get install xdg-utils -y

# Install Powershell Moduels to Support Installation
RUN pwsh -c "Install-Module -Name powershell-yaml -Force -Scope CurrentUser -Verbose"
RUN pwsh -c "Install-Module -Name PnP.Powershell -RequiredVersion 3.1.0 -Force -Scope CurrentUser -Verbose"
RUN pwsh -c "Install-Module -Name Az.Accounts -RequiredVersion 5.3.2 -Force -Scope CurrentUser -Verbose"
RUN pwsh -c "Install-Module -Name Az.Resources -RequiredVersion 8.0.1 -Force -Scope CurrentUser -Verbose"
RUN pwsh -c "Install-Module -Name PSLogs -RequiredVersion 5.2.1 -Force -Scope CurrentUser -Verbose"
RUN pwsh -c "Install-Module -Name MarkdownPS -RequiredVersion 1.9 -Force -Scope CurrentUser -Verbose"
RUN pwsh -c "Install-Module -Name MarkdownToHtml -RequiredVersion 2.7.1 -Force -Scope CurrentUser -Verbose"
RUN pwsh -c "Install-Module -Name EPS -RequiredVersion 1.0.0 -Force -Scope CurrentUser -Verbose"
RUN pwsh -c "Install-Module -Name Pester -RequiredVersion 5.7.1 -Force -Scope CurrentUser -Verbose"

# Overwrites Default Shell to PowerShell
SHELL [ "pwsh", "-c" ]