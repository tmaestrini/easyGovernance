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

        $settings.Settings = Get-TeamsSettings -Properties ActivityFeed, TeamsTargetingPolicy, TeamsClientConfiguration, ExternalAccess, GuestAccess
        $settings.Policies = Get-Policies -Properties OrgWideTeamsPolicy, OrgWideAppPolicy, OrgWideCallingPolicy, OrgWideMeetingPolicy, OrgWideLiveEventsPolicy

        return $settings
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        $settings = @{}

        # Teams Settings
        $teamsActivityFeedSettings = $extractedSettings.Settings.ActivityFeed | Where-Object { $_.Identity -eq "Global" }
        $teamsTargetingPolicySettings = $extractedSettings.Settings.TeamsTargetingPolicy | Where-Object { $_.Identity -eq "Global" }
        $teamsClientConfiguration = $extractedSettings.Settings.TeamsClientConfiguration | Where-Object { $_.Identity -eq "Global" }
        $teamsExternalAccessSettings = $extractedSettings.Settings.ExternalAccess | Where-Object { $_.Identity -eq "Global" }
        $teamsGuestAccessSettings = $extractedSettings.Settings.GuestAccess | Where-Object { $_.ConfigId -eq "Global" }

        $settings.TeamsSettings = @{
          FeedSuggestionsInUsersActivityFeed = ($teamsActivityFeedSettings.SuggestedFeedsEnabledType) -eq "EnabledUserOverride" ? "Allow" : "Block" ?? "n/a"
          TeamsTargetingPolicy               = @{
            WhoCanManageTags                    = ($teamsTargetingPolicySettings.ManageTagsPermissionMode) -eq "EnabledTeamOwner" ? "TeamOwners" : $teamsTargetingPolicySettings.ManageTagsPermissionMode
            LetTeamOwnersChangeWhoCanManageTags = ($teamsTargetingPolicySettings.TeamOwnersEditWhoCanManageTagsMode) -eq "TeamOwnersEditWhoCanManageTagsMode"
            CustomTags                          = ($teamsTargetingPolicySettings.CustomTagsMode) -eq "Enabled" ? "Allow" : "Block" ?? "n/a"
            ShiftsAppCanApplyTags               = ($teamsTargetingPolicySettings.ShiftBackedTagsMode) -eq "ShiftBackedTagsMode" ? "Allow" : "Block" ?? "n/a"
          }
          TeamsClientConfiguration           = @{
            AllowUsersCanSendEmailsToAChannel = ($teamsClientConfiguration.AllowEmailIntoChannel) -eq $true ? "Allow" : "Block" ?? 'n/a'
            AllowCitrix                       = ($teamsClientConfiguration.AllowShareFile) -eq $true ? "Allow" : "Block" ?? 'n/a'
            AllowDropBox                      = ($teamsClientConfiguration.AllowDropBox) -eq $true ? "Allow" : "Block" ?? 'n/a'
            AllowBox                          = ($teamsClientConfiguration.AllowBox) -eq $true ? "Allow" : "Block" ?? 'n/a'
            AllowGoogleDrive                  = ($teamsClientConfiguration.AllowGoogleDrive) -eq $true ? "Allow" : "Block" ?? 'n/a'
            AllowEgnyte                       = ($teamsClientConfiguration.AllowEgnyte) -eq $true ? "Allow" : "Block" ?? 'n/a'
            AllowOrganizationTabForUsers      = ($teamsClientConfiguration.AllowOrganizationTab) -eq $true ? "Allow" : "Block" ?? 'n/a'
            Require2ndAuthforMeeting          = ($teamsClientConfiguration.ResourceAccountContentAccess) -eq $true ? "Allow" : "Block" ?? 'n/a'
            SetContentPin                     = ($teamsClientConfiguration.ContentPin) -eq $true ? "Allow" : "Block" ?? 'n/a'
            SurfaceHubCanSendMails            = ($teamsClientConfiguration.SurfaceHubCanSendMails) -eq $true ? "Allow" : "Block" ?? 'n/a'
            ScopeDirectorySearch              = ($teamsClientConfiguration.AllowScopedPeopleSearchandAccess) -eq $true ? "Allow" : "Block" ?? 'n/a'
            ExtendedWorkInfoInPeopleSearch    = ($teamsClientConfiguration.ExtendedWorkInfoInPeopleSearch) -eq $true ? "Allow" : "Block" ?? 'n/a'
            RoleBasedChatPermissions          = ($teamsClientConfiguration.AllowRoleBasedChatPermissions) -eq $true ? "Allow" : "Block" ?? 'n/a'
            ProvideLinkToSupportRequestPage   = ($teamsClientConfiguration.ProvideLinkToSupportRequestPage) -eq $true ? "Allow" : "Block" ?? 'n/a'
          }
          ExternalAccess                     = @{
            UsersInExternalOrgs                      = if ($teamsExternalAccessSettings.AllowFederatedUsers -and $teamsExternalAccessSettings.AllowedDomains.Count -eq 0) {
              "AllowEveryone"
            }
            elseif ($teamsExternalAccessSettings.AllowFederatedUsers -and $teamsExternalAccessSettings.AllowedDomains.Count -gt 0) {
              "AllowOnlySpecificExternalDomains"
            }
            elseif (!$teamsExternalAccessSettings.AllowFederatedUsers -and $teamsExternalAccessSettings.BlockedDomains.Count -gt 0) {
              "BlockOnlySpecificExternalDomains"
            }
            else {
              "Block"
            }
            AllowedExternalDomains                   = (([string[]]$teamsExternalAccessSettings.AllowedDomains.AllowList) | Sort-Object)
            ExternalAccessWithTrialTenants           = ($teamsExternalAccessSettings.ExternalAccessWithTrialTenants) -eq "Blocked" ? "Block" : "Allow" ?? 'n/a'
            MyOrgCanCommunicateWithUnmanagedAccounts = ($teamsExternalAccessSettings.AllowTeamsConsumer) -eq $true ? "Allow" : "Block" ?? 'n/a'
            UnmanagedAccountsCanContactMyOrg         = ($teamsExternalAccessSettings.AllowTeamsConsumerInbound) -eq $true ? "Allow" : "Block" ?? 'n/a'
          }
          TeamsGuestAccess                   = @{
            AllowGuestsToAccessTeams = ($teamsGuestAccessSettings.AllowGuestUser) -eq $true ? "Allow" : "Block" ?? 'n/a'
            MakePrivateCalls         = ($teamsGuestAccessSettings.AllowPrivateCalling) -eq $true ? "Allow" : "Block" ?? 'n/a'
            VideoConferencing        = ($teamsGuestAccessSettings.AllowIPVideo) -eq $true ? "Allow" : "Block" ?? 'n/a'
            ScreenSharingMode        = $teamsGuestAccessSettings.ScreenSharingMode ?? 'n/a'
            MeetNow                  = ($teamsGuestAccessSettings.AllowMeetNow) -eq $true ? "Allow" : "Block" ?? 'n/a'
            EditSentMessages         = ($teamsGuestAccessSettings.AllowUserEditMessage) -eq $true ? "Allow" : "Block" ?? 'n/a'
            DeleteSentMessages       = ($teamsGuestAccessSettings.AllowUserDeleteMessage) -eq $true ? "Allow" : "Block" ?? 'n/a'
            DeleteChat               = ($teamsGuestAccessSettings.AllowUserDeleteChat) -eq $true ? "Allow" : "Block" ?? 'n/a'
            Chat                     = ($teamsGuestAccessSettings.AllowUserChat) -eq $true ? "Allow" : "Block" ?? 'n/a'
            GiphyInConversations     = ($teamsGuestAccessSettings.AllowGiphy) -eq $true ? "Allow" : "Block" ?? 'n/a'
            GiphyContentRating       = $teamsGuestAccessSettings.GiphyContentRating ?? 'n/a'
            MemesInConversations     = ($teamsGuestAccessSettings.AllowMemes) -eq $true ? "Allow" : "Block" ?? 'n/a'
            StickersInConversations  = ($teamsGuestAccessSettings.AllowStickers) -eq $true ? "Allow" : "Block" ?? 'n/a'
            ImmerseReaderForMessages = ($teamsGuestAccessSettings.AllowImmersiveReader) -eq $true ? "Allow" : "Block" ?? 'n/a'
          }
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

        # Meeting policy
        $orgWideDefaultMeetingPolicy = $extractedSettings.Policies.OrgWideMeetingPolicy | Where-Object { $_.Identity -eq "Global" }
        $settings.MeetingPolicies = @{
          Name                                       = $orgWideDefaultMeetingPolicy.Identity ?? "n/a"
          MeetNowInChannels                          = ($orgWideDefaultMeetingPolicy.AllowMeetNow -eq $true) -and ($orgWideDefaultMeetingPolicy.AllowPrivateMeetNow -eq $true) ? "Allow" : "Block" ?? "n/a"
          OutlookAddIn                               = $orgWideDefaultMeetingPolicy.AllowOutlookAddIn -eq $true ? "Allow" : "Block" ?? "n/a"
          ChannelMeetingScheduling                   = ($orgWideDefaultMeetingPolicy.AllowChannelMeetingScheduling) -eq $true ? "Allow" : "Block" ?? "n/a"
          PrivateMeetingScheduling                   = $orgWideDefaultMeetingPolicy.AllowPrivateMeetingScheduling -eq $true ? "Allow" : "Block" ?? "n/a"
          EngagementReport                           = $orgWideDefaultMeetingPolicy.AllowEngagementReport -eq $true ? "Allow" : "Block" ?? "n/a"
          MeetingRegistration                        = $orgWideDefaultMeetingPolicy.AllowMeetingRegistration -eq $true ? "Allow" : "Block" ?? "n/a"
          WhoCanRegister                             = $orgWideDefaultMeetingPolicy.WhoCanRegister ?? "n/a"
          IPAudio                                    = $orgWideDefaultMeetingPolicy.AllowIPAudio -eq $true ? "Allow" : "Block" ?? "n/a"
          ModeForIPAudio                             = $orgWideDefaultMeetingPolicy.IPAudioMode ?? "n/a"
          IPVideo                                    = $orgWideDefaultMeetingPolicy.AllowIPVideo -eq $true ? "Allow" : "Block" ?? "n/a"
          ModeforIPVideo                             = $orgWideDefaultMeetingPolicy.IPVideoMode ?? "n/a"
          LocalBroadcasting                          = $orgWideDefaultMeetingPolicy.AllowNDIStreaming -eq $true ? "Allow" : "Block" ?? "n/a"
          MediaBitRateKb                             = $orgWideDefaultMeetingPolicy.MediaBitRateKb ?? "n/a"
          NetworkConfigurationLookup                 = $orgWideDefaultMeetingPolicy.AllowNetworkConfigurationSettingsLookup -eq $true ? "Allow" : "Block" ?? "n/a"
          Transcription                              = $orgWideDefaultMeetingPolicy.AllowTranscription -eq $true ? "Allow" : "Block" ?? "n/a"
          CloudRecording                             = $orgWideDefaultMeetingPolicy.AllowCloudRecording -eq $true ? "Allow" : "Block" ?? "n/a"
          MeetingsAutomaticallyExpire                = $orgWideDefaultMeetingPolicy.NewMeetingRecordingExpirationDays ? "Allow" : "Block" ?? "n/a"
          DefaultExpirationTimeDays                  = $orgWideDefaultMeetingPolicy.NewMeetingRecordingExpirationDays ?? "n/a"
          StoreRecordingsOutsideofYourCountry        = $orgWideDefaultMeetingPolicy.AllowRecordingStorageOutsideRegion -eq $true ? "Allow" : "Block" ?? "n/a"
          ScreenSharingMode                          = $orgWideDefaultMeetingPolicy.ScreenSharingMode ?? "n/a"
          AllowInternalParticipantGiveRequestControl = $orgWideDefaultMeetingPolicy.AllowInternalParticipantGiveRequestControl ?? "n/a"
          AllowExternalParticipantGiveRequestControl = $orgWideDefaultMeetingPolicy.AllowExternalParticipantGiveRequestControl ?? "n/a"
          PowerPointSharing                          = $orgWideDefaultMeetingPolicy.AllowPowerPointSharing -eq $true ? "Allow" : "Block" ?? "n/a"
          Whiteboard                                 = $orgWideDefaultMeetingPolicy.AllowWhiteboard -eq $true ? "Allow" : "Block" ?? "n/a"
          SharedNotes                                = $orgWideDefaultMeetingPolicy.AllowSharedNotes -eq $true ? "Allow" : "Block" ?? "n/a"
          SelectVideoFilters                         = $orgWideDefaultMeetingPolicy.VideoFiltersMode ?? "n/a"
          AnonymousJoinMeeting                       = $orgWideDefaultMeetingPolicy.AllowAnonymousUsersToJoinMeeting -eq $true ? "Allow" : "Block" ?? "n/a"
          AnonymousStartMeeting                      = $orgWideDefaultMeetingPolicy.AllowAnonymousUsersToStartMeeting -eq $true ? "Allow" : "Block" ?? "n/a"
          RolesWithPresenterRights                   = $orgWideDefaultMeetingPolicy.DesignatedPresenterRoleMode ?? "n/a"
          AutoAdmitPeople                            = $orgWideDefaultMeetingPolicy.AutoAdmittedUsers -eq $true ? "Allow" : "Block" ?? "n/a"
          AllowDialInBypassLobby                     = $orgWideDefaultMeetingPolicy.AllowPSTNUsersToBypassLobby -eq $true ? "Allow" : "Block" ?? "n/a"
          MeetNowPrivateMeetings                     = $orgWideDefaultMeetingPolicy.AllowPrivateMeetNow -eq $true ? "Allow" : "Block" ?? "n/a"
          LiveCaptions                               = $orgWideDefaultMeetingPolicy.LiveCaptionsEnabledType ?? "n/a"
          ChatInMeetings                             = $orgWideDefaultMeetingPolicy.MeetingChatEnabledType -eq "Enabled" ? "Allow" : "Block" ?? "n/a"
        }

        # Live Events policy
        $orgWideLiveEventsPolicy = $extractedSettings.Policies.OrgWideLiveEventsPolicy | Where-Object { $_.Identity -eq "Global" }
        $settings.LiveEventsPolicies = @{
          Name                      = $orgWideLiveEventsPolicy.Identity ?? "n/a"
          LiveEventScheduling       = $orgWideLiveEventsPolicy.AllowBroadcastScheduling -eq $true ? "Allow" : "Block" ?? "n/a"
          TranscriptionForAttendees = $orgWideLiveEventsPolicy.AllowBroadcastTranscription -eq $true ? "Allow" : "Block" ?? "n/a"
          WhoCanJoinLiveEvent       = $orgWideLiveEventsPolicy.BroadcastAttendeeVisibilityMode ?? "n/a"
          RecordingMode             = $orgWideLiveEventsPolicy.BroadcastRecordingMode ?? "n/a"
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