# Select Base Image for Docker
# Image 'lts-7.2-debian-11' used for Support on Windows and Mac M1 Platform
FROM mcr.microsoft.com/powershell:lts-7.2-debian-11

# Install 'xdg-utils' to support Interactive Logons
RUN apt-get update
RUN apt-get install xdg-utils -y

# Install Powershell Moduels to Support Installation
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name powershell-yaml"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name PnP.Powershell -RequiredVersion 2.12.0"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name Microsoft.Graph -RequiredVersion 2.26.1"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name Az.Accounts -RequiredVersion 4.0.2"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name Az.Resources -RequiredVersion 6.4.0"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name PSLogs -RequiredVersion 5.2.1"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name MarkdownPS -RequiredVersion 1.9"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name MarkdownToHtml -RequiredVersion 2.7.1"
RUN pwsh -c "Install-Module -Force -Scope CurrentUser -Verbose -Name EPS -RequiredVersion 1.0.0"

# Overwrites Default Shell to PowerShell
SHELL [ "pwsh", "-c" ]