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
![PnP.PowerShell](https://img.shields.io/badge/PnP.Powershell-2.4.0-blue.svg) 
![Microsoft.Graph](https://img.shields.io/badge/Microsoft.Graph-2.15.0-blue.svg) 
![Microsoft.Graph](https://img.shields.io/badge/powershell--yaml-0.4.7-blue.svg) 

## Applies to
- [Microsoft 365 tenant](https://docs.microsoft.com/en-us/sharepoint/dev/spfx/set-up-your-developer-tenant)
- [SharePoint Online](https://learn.microsoft.com/en-us/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-service-description)

> Get your own free development tenant by subscribing to [Microsoft 365 developer program](http://aka.ms/o365devprogram)


## Contributors

* Tobias Maestrini [@tmaestrini](https://github.com/tmaestrini)
* Daniel Kordes [@dako365](https://github.com/dako365)
* Marc D. Anderson [@sympmarc](https://github.com/sympmarc)


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

> [!NOTE]
> The remote container is based on PowerShell 7.2 (differs from the version mentioned in the dependencies); this is not a problem.
You're good to go!

### Local installation

> [!NOTE]
> 👉 Make sure you're at least on PowerShell >7 – see dependencies section for best reference.

Before using any fragement, either install all dependencies on your local machine:

```powershell
Install-Module -Name powershell-yaml -Scope CurrentUser
Install-Module -Name PnP.PowerShell -RequiredVersion 2.4.0 -Scope CurrentUser
Install-Module -Name Microsoft.Graph -RequiredVersion 2.15.0 -Scope CurrentUser
```


## Usage

There are two approaches to get «in contact» with your M365 tenant or the M365 services.<br>
👉 Basically, every approach focusses the **configuration baselines**.

### Configuration baselines
Every configuration baseline is a YAML file that contains an initial setup of configuration parameters for a specific service or a tenant:
```yaml
Topic: SharePoint Online
Type: Baseline
Id: M365.SPO-5.2

References:
  - https://www.cisa.gov/sites/default/files/2023-12/SharePoint%20and%20OneDrive%20SCB_12.20.2023.pdf
  - https://blueprint.oobe.com.au/as-built-as-configured/office-365/#sharing
  - https://blueprint.oobe.com.au/as-built-as-configured/office-365/#access-control
  - https://blueprint.oobe.com.au/as-built-as-configured/office-365/#sharepoint-settings	

Configuration:
  ExternalSharing:
    - SharingCapability: ExistingExternalUserSharingOnly # Specifies what the sharing capabilities are for the site
    - DefaultSharingLinkType: Internal # Specifies the default sharing link type
    - DefaultLinkPermission: View
    - RequireAcceptingAccountMatchInvitedAccount: true # Ensures that an external user can only accept an external sharing invitation with an account matching the invited email address.
    - RequireAnonymousLinksExpireInDays: 30 # Specifies all anonymous links that have been created (or will be created) will expire after the set number of days (set to 0 to remove).
    - FileAnonymousLinkType: View # Sets whether anonymous access links can allow recipients to only view or view and edit. 
    - FolderAnonymousLinkType: View # Sets whether anonymous access links can allow recipients to only view or view and edit. 
    - CoreRequestFilesLinkEnabled: true # Enable or disable the Request files link on the core partition for all SharePoint sites (not including OneDrive sites).
    - ExternalUserExpireInDays: 30 # When a value is set, it means that the access of the external user will expire in those many number of days.
    - EmailAttestationRequired: true # Sets email attestation to required.
    - EmailAttestationReAuthDays: 30 # Sets the number of days for email attestation re-authentication. Value can be from 1 to 365 days.
    - PreventExternalUsersFromResharing: true # Prevents external users from resharing files, folders, and sites that they do not own.
    - SharingDomainRestrictionMode: AllowList # Specifies the external sharing mode for domains.
    - SharingAllowedDomainList: "" # Specifies a list of email domains that is allowed for sharing with the external collaborators (comma separated).
    - ShowEveryoneClaim: false # Enables the administrator to hide the Everyone claim in the People Picker. 
    - ShowEveryoneExceptExternalUsersClaim: false # Enables the administrator to hide the "Everyone except external users" claim in the People Picker. 
  ApplicationsAndWebparts:
    - DisabledWebPartIds: ""
  AccessControl:
    - ConditionalAccessPolicy: AllowFullAccess # Blocks or limits access to SharePoint and OneDrive content from un-managed devices.
    - BrowserIdleSignout: true
    - BrowserIdleSignoutMinutes: 60
    - BrowserIdleSignoutWarningMinutes: 5
    - LegacyAuthProtocolsEnabled: false # Setting this parameter prevents Office clients using non-modern authentication protocols from accessing SharePoint Online resources
  SiteCreationAndStorageLimits:
    - NotificationsInSharePointEnabled: true # Enables or disables notifications in SharePoint.
    - DenyAddAndCustomizePages: true
```

### Provision of services
> [!IMPORTANT]
> TODO

### Validation of services 
To run a validation for a tenant according to the defined baselines, simply call the `Start-Validation` cmdlet.
This will compare the existing setup from the settings file (`[tenantname.yml]`) with the configured baseline and print
the result to the std output.

```powershell
# Validate a given tenant from settings file
Import-Module .\src\Validation.psm1 -Force
Start-Validation -TemplateName "[tenantname].yml" # 👈 references the specific tenant template in the 'tenants' folder
```
If you would like to store the validation results in a variable – for example to process the results in a further way.
Simply add the `ReturnAsObject` parameter, which will print out the validation statistics but suppress the validation results:

```powershell
# Validate a given tenant from settings file and store the result in a variable
Import-Module .\src\Validation.psm1 -Force
$validationResults = Start-Validation -TemplateName "[tenantname].yml" -ReturnAsObject
```
The returned object contains following attributes:
* `Baseline`: The Baseline Id 
* `Result`: The test result (aka validation results)
* `ResultGroupedText`: The test results as text (grouped)
* `Statistics`: The statistics of the validation