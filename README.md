# easyGovernance – governance and validation for configuration baselines in M365 made as easy as possible
*easyGovernance* offers a quick and easy way to validate several configurations and resources along predefined configuration baselines for an entire Microsoft 365 tenant or dedicated services. 
By defining a *configuration baseline* (YAML) that contains all the desired configuration parameters, this tool is a straightforward approach to govern and validate any given environment in M365. It does NOT offer a DSC setup and related mechanisms. 

Any *configuration baseline* is considered to reference the baseline suggestions from the [Secure Cloud Business Applications (SCuBA) for Microsoft 365](https://www.cisa.gov/resources-tools/services/secure-cloud-business-applications-scuba-project) by CISA and [the blueprint](https://blueprint.oobe.com.au/) by oobe.

Under the hood, the baseline validation engine is powered by the [PnP.Powershell](https://pnp.github.io/powershell/) module and the [Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview). This provides us with a powerful toolset – driven by the power of PowerShell 😃.

Give it a try – We're sure you will like it! 💪

> [!NOTE]
> 👉 For now, configuration baselines for an M365 tenant and SPO service are currently supported  – but other services will follow asap. Any contributors are welcome! 🙌


## Dependencies
![PowerShell](https://img.shields.io/badge/Powershell-7.4.1-blue.svg) 
![PnP.PowerShell](https://img.shields.io/badge/PnP.Powershell-2.3.0-blue.svg) 
![Microsoft.Graph](https://img.shields.io/badge/Microsoft.Graph-2.15.0-blue.svg) 
![Microsoft.Graph](https://img.shields.io/badge/powershell--yaml-0.4.7-blue.svg) 

## Applies to
- [Microsoft 365 tenant](https://docs.microsoft.com/en-us/sharepoint/dev/spfx/set-up-your-developer-tenant)
- [SharePoint Online](https://learn.microsoft.com/en-us/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-service-description)

> Get your own free development tenant by subscribing to [Microsoft 365 developer program](http://aka.ms/o365devprogram)


## Contributors

* Tobias Maestrini [@tmaestrini](https://github.com/tmaestrini)
* Daniel Kordes [@dako365](https://github.com/dako365)


## Version history

| Version | Date           | Comments        |
| ------- | :------------- | :-------------- |
| 1.0     | February, 2023 | Initial release |


## Disclaimer

**THIS CODE IS PROVIDED _AS IS_ WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.**

---

## Minimal path to awesome

There are two possibilities to get the stuff up and running.

### Open remote container (VS Code)

> [!TIP]
> This is considered the preferred way.

Get rid of all the local dependencies: in case you're working in Visual Studio Code, you're almost good to go:
1. Make sure you have [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed on your local machine. 
2. After that, reopen the project and select `Reopen in Container`. <br>This will span up a virtual environment that contains all the required dependencies, based on the `Dockerfile` and the `devcontainer.json` definition in [`.devcontainer`](.devcontainer) – and all PowerShell modules installed on your local machine will remain unaffected. 😃

You're good to go!

### Local installation

> [!NOTE]
> 👉 Make sure you're at least on PowerShell >7; dependencies suggest version `7.4.1`.

There are tow
Before using any fragement, either install all dependencies on your local machine:

```powershell
Install-Module -Name powershell-yaml -Scope CurrentUser
Install-Module -Name PnP.PowerShell -RequiredVersion 2.3.0 -Scope CurrentUser
Install-Module -Name Microsoft.Graph -RequiredVersion 2.15.0 -Scope CurrentUser
```


## Usage

There are two approaches to get «in contact» with your M365 tenant or the M365 services.<br>
👉 Basically, every approach focusses the **configuration baselines**.

### Provision of services
> [!IMPORTANT]
> TODO

### Validation of services 
> [!IMPORTANT]
> TODO