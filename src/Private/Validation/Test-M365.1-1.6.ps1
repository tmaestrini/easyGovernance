using module .\Class\BaselineValidator.psm1

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Test-M365.1-6.1
#>

Function Test-M365.1-6.1 {
  [CmdletBinding()]
  [Alias()]
  [OutputType([hashtable])]
  
  Param
  (
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The baseline itself"
    )][PSCustomObject]$Baseline,
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The id of the tenant (https://[tenantId].onmicrosoft.com)"
    )][string] $tenantId,
    [Parameter(
      Mandatory = $false
    )][switch] $ReturnAsObject
  )
 
  Begin {
    class TeamsSettingsValidator : BaselineValidator {
      TeamsSettingsValidator([PSCustomObject] $Baseline, [string] $TenantId, [switch] $ReturnAsObject = $false) : base($Baseline, $TenantId, $ReturnAsObject) {}

      Connect() {
        Connect-TeamsAdminCenter
      }

      [PSCustomObject] Extract() {
        $settings = @{}

        $settings.Settings = Get-TeamsSettings -Properties FeedSuggestionsInUsersActivityFeed, WhoCanManageTags, LetTeamOwnersChangeWhoCanManageTags, CustomTags, ShiftsAppCanApplyTags, AllowEmailIntoChannel
        $settings.Policies = Get-Policies -Properties OrgWideTeamsPolicy, OrgWideAppPolicy, OrgWideCallingPolicy, OrgWideMeetingPolicy

        return $settings
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        $settings = @{}

        # FeedSuggestionsInUsersActivityFeed
        $settings.TeamsSettings = @{
          FeedSuggestionsInUsersActivityFeed  = ($extractedSettings.Settings.FeedSuggestionsInUsersActivityFeed -eq "EnabledUserOverride")
          
          # TeamsTargetingPolicy contain string values that need to be transformed to boolean or other string values
          WhoCanManageTags                    = ($extractedSettings.Settings.TeamsTargetingPolicy.ManageTagsPermissionMode -eq "EnabledTeamOwner") ? "TeamOwners" : $extractedSettings.Settings.WhoCanManageTags
          LetTeamOwnersChangeWhoCanManageTags = ($extractedSettings.Settings.TeamsTargetingPolicy.TeamOwnersEditWhoCanManageTagsMode -eq "TeamOwnersEditWhoCanManageTagsMode")
          CustomTags                          = ($extractedSettings.Settings.TeamsTargetingPolicy.CustomTagsMode -eq "Enabled")
          ShiftsAppCanApplyTags               = ($extractedSettings.Settings.TeamsTargetingPolicy.ShiftBackedTagsMode -eq "ShiftBackedTagsMode")
          
          # TeamsClientConfiguration contain boolean values
          AllowUsersCanSendEmailsToAChannel   = $extractedSettings.Settings.TeamsClientConfiguration.AllowEmailIntoChannel ?? 'n/a'
          AllowCitrix                         = $extractedSettings.Settings.TeamsClientConfiguration.AllowShareFile ?? 'n/a'
          AllowDropBox                        = $extractedSettings.Settings.TeamsClientConfiguration.AllowDropBox ?? 'n/a'
          AllowBox                            = $extractedSettings.Settings.TeamsClientConfiguration.AllowBox ?? 'n/a'
          AllowGoogleDrive                    = $extractedSettings.Settings.TeamsClientConfiguration.AllowGoogleDrive ?? 'n/a'
          AllowEgnyte                         = $extractedSettings.Settings.TeamsClientConfiguration.AllowEgnyte ?? 'n/a'
          AllowOrganizationTabForUsers        = $extractedSettings.Settings.TeamsClientConfiguration.AllowOrganizationTab ?? 'n/a'
          Require2ndAuthforMeeting            = $extractedSettings.Settings.TeamsClientConfiguration.ResourceAccountContentAccess ?? 'n/a'
          SetContentPin                       = $extractedSettings.Settings.TeamsClientConfiguration.ContentPin ?? 'n/a'
          SurfaceHubCanSendMails              = $extractedSettings.Settings.TeamsClientConfiguration.SurfaceHubCanSendMails ?? 'n/a'
          ScopeDirectorySearch                = $extractedSettings.Settings.TeamsClientConfiguration.AllowScopedPeopleSearchandAccess ?? 'n/a'
          ExtendedWorkInfoInPeopleSearch      = $extractedSettings.Settings.TeamsClientConfiguration.ExtendedWorkInfoInPeopleSearch ?? 'n/a'
          RoleBasedChatPermissions            = $extractedSettings.Settings.TeamsClientConfiguration.AllowRoleBasedChatPermissions ?? 'n/a'
          ProvideLinkToSupportRequestPage     = $extractedSettings.Settings.TeamsClientConfiguration.ProvideLinkToSupportRequestPage ?? 'n/a'
        }
          
        # Teams Policies
        $settings.TeamsPolicies = @{
          CreatePrivateChannels = ($extractedSettings.Policies.OrgWideTeamsPolicy.AllowPrivateChannelCreation) -eq $true ? "Allow" : "Block"
        }

        # Apps Policies
        $orgWideDefaultAppPolicy = $extractedSettings.Policies.OrgWideAppPolicy | Where-Object { $_.ConfigId -eq "Global" }
        $settings.AppPolicies = @{
          Name             = $orgWideDefaultAppPolicy.Identity ?? "n/a"
          UploadCustomApps = ($orgWideDefaultAppPolicy.AllowSideLoading) -eq $true ? "Allow" : "Block" ?? "n/a"
          UserPinning      = ($orgWideDefaultAppPolicy.AllowUserPinning) -eq $true ? "Allow" : "Block" ?? "n/a"
        }
        
        # Calling policy
        $orgWideDefaultCallingPolicy = $extractedSettings.Policies.OrgWideCallingPolicy
        $settings.CallingPolicies = @{
          Name                                   = $orgWideDefaultCallingPolicy.Identity ?? "n/a"
          MakePrivateCalls                       = ($orgWideDefaultCallingPolicy.AllowPrivateCalling) -eq $true ? "Allow" : "Block" ?? "n/a"
          CloudRecordingForCalling               = ($orgWideDefaultCallingPolicy.AllowCloudRecordingForCalls) -eq $true ? "Allow" : "Block" ?? "n/a"
          # InternalCallForwardingAndRinging = ($orgWideDefaultCallingPolicy.AllowInternalCallForwardingAndRinging) -eq $true ? "Allow" : "Block" ?? "n/a"
          # ExternalCallForwardingAndRinging = ($orgWideDefaultCallingPolicy.AllowExternalCallForwardingAndRinging) -eq $true ? "Allow" : "Block" ?? "n/a"
          VoicemailEnabledForRoutingInboundCalls = ($orgWideDefaultCallingPolicy.AllowVoicemail) ?? "n/a"
          # DelegationInboundOutbound = ($extractedSettings.CallingPolicies.OrgWideCallingPolicy.AllowDelegationInboundOutbound) -eq $true ? "Allow" : "Block" ?? "n/a"
          PreventTollBypass                      = ($extractedSettings.CallingPolicies.OrgWideCallingPolicy.PreventTollBypass) -eq $true ? "Allow" : "Block" ?? "n/a"
          MusicOnHoldPSTN                        = $extractedSettings.CallingPolicies.OrgWideCallingPolicy.MusicOnHoldEnabledType ?? "n/a"
          BusyOnBusy                             = ($extractedSettings.CallingPolicies.OrgWideCallingPolicy.BusyOnBusyEnabledType) -eq "Enabled" ? "Allow" : "Block" ?? "n/a"
          WebPSTNCalling                         = ($extractedSettings.CallingPolicies.OrgWideCallingPolicy.AllowWebPSTNCalling) -eq $true ? "Allow" : "Block" ?? "n/a"
          RealTimeCaptions                       = ($extractedSettings.CallingPolicies.OrgWideCallingPolicy.LiveCaptionsEnabledTypeForCalling) -eq "Disabled" ? "Block" : "Allow" ?? "n/a"
          AutoAnswerMeetingInvites               = ($extractedSettings.CallingPolicies.OrgWideCallingPolicy.AutoAnswerEnabledType) -eq "Enabled" ? "Allow" : "Block" ?? "n/a"
          SIPDevicesPerformCalling               = ($extractedSettings.CallingPolicies.OrgWideCallingPolicy.AllowSIPDevicesCalling) -eq $true ? "Allow" : "Block" ?? "n/a"
          CopilotEnabled                         = ($extractedSettings.CallingPolicies.OrgWideCallingPolicy.Copilot) -eq "Enabled" ? "Allow" : "Block" ?? "n/a"
        }

        return $settings
      }
    }
  }

  Process {
    try {
      $validator = [TeamsSettingsValidator]::new($Baseline, $tenantId, $ReturnAsObject)
      $validator.StartValidation()
      $result = $validator.GetValidationResult()
      
      if ($returnAsObject) {
        return $result
      }
    }
    catch {
      throw $_
    }
  }
}