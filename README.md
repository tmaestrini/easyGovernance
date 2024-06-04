# easyGovernance – governance and validation for configuration baselines in M365 made as easy as possible

_easyGovernance_ offers a quick and easy way to validate several configurations and resources along predefined configuration baselines for an entire Microsoft 365 tenant or dedicated services.
By defining a _configuration baseline_ (YAML) that contains all the desired configuration parameters, this tool is a straightforward approach to govern and validate any given environment in M365. It does NOT offer a DSC setup and related mechanisms.

Any _configuration baseline_ is considered to reference the baseline suggestions from the [Secure Cloud Business Applications (SCuBA) for Microsoft 365](https://www.cisa.gov/resources-tools/services/secure-cloud-business-applications-scuba-project) by CISA and [the blueprint](https://blueprint.oobe.com.au/) by oobe.

> [!NOTE]
> 👉 For now, configuration baselines for an M365 tenant and SPO service are currently supported – but other services will follow asap. Any contributors are welcome! 🙌

Give it a try – We're sure you will like it! 💪

## Architecture and Dependencies

Under the hood, the baseline validation engine is powered by the [PnP.Powershell](https://pnp.github.io/powershell/) module and the [Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview). This provides us with a powerful toolset – driven by the power of PowerShell 😃.

The implementation is based on the following PowerShell modules:

![PowerShell](https://img.shields.io/badge/Powershell-7.4.1-blue.svg)
![PnP.PowerShell](https://img.shields.io/badge/PnP.Powershell-2.4.0-blue.svg)
![Microsoft.Graph](https://img.shields.io/badge/Microsoft.Graph-2.15.0-blue.svg)
![Az.Accounts](https://img.shields.io/badge/Az.Accounts-2.19.0-blue.svg)
![PSLogs](https://img.shields.io/badge/PSLogs-5.2.1-blue.svg)
![powershell-yaml](https://img.shields.io/badge/powershell--yaml-0.4.7-blue.svg)
![MarkdownPS](https://img.shields.io/badge/MarkdownPS-1.9-blue.svg)
![MarkdownToHTML](https://img.shields.io/badge/MarkdownToHTML-2.7.1-blue.svg)

## Applies to

- [Microsoft 365 tenant](https://docs.microsoft.com/en-us/sharepoint/dev/spfx/set-up-your-developer-tenant)
- [SharePoint Online](https://learn.microsoft.com/en-us/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-service-description)

> Get your own free development tenant by subscribing to [Microsoft 365 developer program](http://aka.ms/o365devprogram)

## Contributors

- Tobias Maestrini [@tmaestrini](https://github.com/tmaestrini)
- Daniel Kordes [@dako365](https://github.com/dako365)
- Marc D. Anderson [@sympmarc](https://github.com/sympmarc)

Any contribution is welcome. Please read our [contribution guidelines](./Contributing.md) first.

## Version history

| Version | Date           | Comments        |
| ------- | :------------- | :-------------- |
| 1.0     | February, 2024 | Initial release |

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
2. After that, reopen the project and select `Reopen in Container`. This will spin up a virtual environment that contains all the required dependencies, based on the `Dockerfile` and the `devcontainer.json` definition in [`.devcontainer`](.devcontainer) – and all PowerShell modules installed on your local machine will remain unaffected. 😃

> [!NOTE]
> The remote container is based on PowerShell 7.2 (differs from the version mentioned in the dependencies); this is not a problem.
> You're good to go!

### Local installation

> [!NOTE]
> 👉 Make sure you're at least on PowerShell >7 – see dependencies section for best reference.

Before using, install all dependencies on your local machine:

```powershell
Install-Module -Name powershell-yaml -Scope CurrentUser
Install-Module -Name PnP.PowerShell -RequiredVersion 2.4.0 -Scope CurrentUser
Install-Module -Name Microsoft.Graph -RequiredVersion 2.15.0 -Scope CurrentUser
Install-Module -Name Az.Accounts -RequiredVersion 2.19.0 -Scope CurrentUser
Install-Module -Name PSLogs -RequiredVersion 5.2.1 -Scope CurrentUser
Install-Module -Name MarkdownPS	-RequiredVersion 1.9 -Scope CurrentUser
Install-Module -Name MarkdownToHTML -RequiredVersion 2.7.1 -Scope CurrentUser
```

## Usage

There are two approaches to analyze your M365 tenant or the M365 services.

👉 Each approach uses the **configuration baselines**.

Currently, we recommend the following sequence to get up and running:

- Create a fork of the repo and copy it locally
- Copy one or more of the example scripts into the tenants folder in your forked copy. Files in the tenant folder are excluded in the .gitignore file, so anything you create there will stay local to your repo.
- Copy the **tenant settings file** (`settings_template.yml`) and edit it `MyTenantName` to be the tenant where you would like to compare the baselines.
- Run the baselines you choose with your copy of the example scripts.

### Tenant settings file

In order to configure a dedicated baseline configuration for a specific tenant, an according **tenant settings file** must be created (`yml`). The _file name_ can be chosen according to your needs (ending with `.yml`); consider using the tenant's name as the file descriptor, e.g. `[tenantname.yml]`.

The tenant settings file must follow this structure:

```yaml
Tenant: MyTenantName

BaselinesPath: <relative path to the folder that contains your baselines> # optional attribute
Baselines:
  - M365.1-1.1
  - M365.1-5.1
  - M365.1-5.2
```

Feel free to include only the baseline definition according to your needs.

> [!NOTE]
> If the attribute `BaselinesPath` is not provided in the tenant settings file, the execution process looks for the standard baseline's path (folder path from root: `./baselines`). In case of an erroneous path definition, the execution of the script is stopped.

### Validation of services

To run a validation for a tenant according to the defined baselines, simply call the `Start-Validation` cmdlet.
This will compare the existing setup from the tenant settings file (`[tenantname.yml]`) with the configured baseline and print
the result to the std output.

```powershell
# Validate a given tenant from settings file
Import-Module .\src\Validation.psm1 -Force
Start-Validation -TemplateName "[tenantname].yml" # 👈 references the specific tenant template in the 'tenants' folder
```

If you would like to store the validation results in a variable – for example to process the results further, simply add the `ReturnAsObject` parameter, which will print out the validation statistics but suppress the validation results:

```powershell
# Validate a given tenant from settings file and store the result in a variable
Import-Module .\src\Validation.psm1 -Force
$validationResults = Start-Validation -TemplateName "[tenantname].yml" -ReturnAsObject
```

The returned object contains following attributes:

- `Tenant`: The identifier of the tenant
- `Validation`: The validation results
  - `Baseline`: The baseline Id
  - `Version`: The selected version of the baseline
  - `Result`: An array containing all the test results (aka validation results) with the following structure (example formatted as JSON for better readability):
  ```typescript
  [
    {
      Group: string, // The configuration group from the baseline, e.g. 'AccessControl'
      Setting: string, // The policy setting within the according baseline group, e.g. 'BrowserIdleSignout'
      Result: string, // The test result, e.g. '--- [Should be 'True']' or '✔︎ [...]' or '✘ [Should be 'False' but is 'True']'
      Status: 'CHECK NEEDED' | 'PASS' | 'FAIL' // The status of the test result
      Reference?: string, // Reference to documentation or whatever; only set if defined in baseline and in case of status = 'CHECK NEEDED' or 'FAIL'
    }
  ]
  ```
  - `ResultGroupedText`: The test results as text (grouped)
  - `Statistics`: The statistics of the validation
    - `Total`: amount of processed checks in total
    - `Passed`: amount of checks passed (no difference to the baseline)
    - `Failed`: amount of checks failed (with difference to the baseline)
    - `Manual`: amount of checks that need to be examined by an administrator

### Generating validation reports

After having validated a tenant against its baselines, a report that summarizes the results can easily be generated by calling the `New-Report` cmdlet.
The report generation engine always creates a Markdown file (.md), which automatically is stored in the `output` folder within the project structure.
The filename of the report follows this convention: `[tenantname]-[yyyyMMddHHmm] report.md`

> [!NOTE]
> The report to be generated needs the stored results from the validation run.

Therefore, make sure that you return the validation results as object by using the `-ReturnAsObject` switch on the `Start-Validation` cmdlet and pass the object to the `New-Report` call:

```powershell
# Validate a given tenant from settings file
Import-Module .\src\Validation.psm1 -Force
$result = Start-Validation -TemplateName "[tenantname].yml" -ReturnAsObject

# Generate a report in directory ./output (optionally as HTML)
New-Report -ValidationResults $result #-AsHTML
```

> [!NOTE]
> Optionally, you can also generate a HTML report in addition to the report in Markdown.
> This offers a well-designed option which is suitable to put the validation results into a presentation or to share with management.

### Configuration baselines

Every configuration baseline is a YAML file that contains an initial setup of configuration parameters for a specific service or a tenant. For example, here is the SharePoint Online baseline (as of 1 April 2024):

```yaml
Topic: SharePoint Online
Type: Baseline
Id: M365.SPO-5.2
Version: 1.0

References:
  - https://www.cisa.gov/sites/default/files/2023-12/SharePoint%20and%20OneDrive%20SCB_12.20.2023.pdf
  - https://blueprint.oobe.com.au/as-built-as-configured/office-365/#sharing
  - https://blueprint.oobe.com.au/as-built-as-configured/office-365/#access-control
  - https://blueprint.oobe.com.au/as-built-as-configured/office-365/#sharepoint-settings

Configuration:
  - enforces: ExternalSharing
    with:
      SharingCapability: ExistingExternalUserSharingOnly # Specifies what the sharing capabilities are for the site
      DefaultSharingLinkType: Internal # Specifies the default sharing link type
      DefaultLinkPermission: View
      RequireAcceptingAccountMatchInvitedAccount: true # Ensures that an external user can only accept an external sharing invitation with an account matching the invited email address.
      RequireAnonymousLinksExpireInDays: 30 # Specifies all anonymous links that have been created (or will be created) will expire after the set number of days (set to 0 to remove).
      FileAnonymousLinkType: View # Sets whether anonymous access links can allow recipients to only view or view and edit.
      FolderAnonymousLinkType: View # Sets whether anonymous access links can allow recipients to only view or view and edit.
      CoreRequestFilesLinkEnabled: true # Enable or disable the Request files link on the core partition for all SharePoint sites (not including OneDrive sites).
      ExternalUserExpireInDays: 30 # When a value is set, it means that the access of the external user will expire in those many number of days.
      EmailAttestationRequired: true # Sets email attestation to required.
      EmailAttestationReAuthDays: 30 # Sets the number of days for email attestation re-authentication. Value can be from 1 to 365 days.
      PreventExternalUsersFromResharing: true # Prevents external users from resharing files, folders, and sites that they do not own.
      SharingDomainRestrictionMode: AllowList # Specifies the external sharing mode for domains.
      SharingAllowedDomainList: "" # Specifies a list of email domains that is allowed for sharing with the external collaborators (comma separated).
      ShowEveryoneClaim: false # Enables the administrator to hide the Everyone claim in the People Picker.
      ShowEveryoneExceptExternalUsersClaim: false # Enables the administrator to hide the "Everyone except external users" claim in the People Picker.

  - enforces: ApplicationsAndWebparts
    with:
      DisabledWebPartIds: ""

  - enforces: AccessControl
    with:
      ConditionalAccessPolicy: AllowLimitedAccess # Blocks or limits access to SharePoint and OneDrive content from un-managed devices.
      BrowserIdleSignout: true
      BrowserIdleSignoutMinutes: 60
      BrowserIdleSignoutWarningMinutes: 5
      LegacyAuthProtocolsEnabled: false # Setting this parameter prevents Office clients using non-modern authentication protocols from accessing SharePoint Online resources
    references:
      - BrowserIdleSignout: ${{tenantAdminUrl}}/_layouts/15/online/AdminHome.aspx#/accessControl/IdleSession

  - enforces: SiteCreationAndStorageLimits
    with:
      NotificationsInSharePointEnabled: true # Enables or disables notifications in SharePoint.
      DenyPagesCreationByUsers: true
      DenySiteCreationByUsers: true
    references:
      - DenyPagesCreationByUsers: "Make sure the setting 'Allow users to create new modern pages' is checked on ${{tenantAdminUrl}}/_layouts/15/online/AdminHome.aspx#/settings/ModernPages"
      - DenySiteCreationByUsers: "Uncheck the setting 'Users can create SharePoint sites' on ${{tenantAdminUrl}}/_layouts/15/online/AdminHome.aspx#/settings/SiteCreation"
```

### Provision of services

> [!IMPORTANT]
> TODO
