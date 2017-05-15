function SumoExport{
<#
    .SYNOPSIS
    Extracts search results in bulk from Sumo Logic.
    
    .DESCRIPTION
    Following the process described in https://help.sumologic.com/Search/Search_FAQs/Export_the_Results_of_a_Saved_File, except
    in powershell, and it will iterate through a large result set for you. Tested up to 6.7M records, not sure what the end limits are.
    
    .PARAMETER credential
    Your Sumo Logic API credentials. You can type these in via get-credential, or pass in a pre-made one.
    You can generate these by going to your profile. The username is your "Access ID" and the password is your "Access Key"
    .PARAMETER query
    The Sumo logic search query (https://help.sumologic.com/Search/Search_Query_Language)
    .PARAMETER fromDate
    The date range start point
    .PARAMETER toDate
    The date range finish point
    .PARAMETER timeZone
    The three letter timezone code for date interpretation. Defaults to 'UTC'
    .PARAMETER filePrefix
    The prefix for the exported files, as the results are downloaded in batches. Can be a full path or just a file name
    .PARAMETER pageSize
    The number of messages to download at a time. Maximum value is the Sumo Logic maximum of 10,000
    .PARAMETER apiEndpoint
    The Sumo Logic API endpoint, defaults to https://api.au.sumologic.com/api/v1. These are listed here: 
    https://help.sumologic.com/APIs/General_API_Information/Sumo_Logic_Endpoints_and_Firewall_Security
    
    .EXAMPLE
    SumoExport -credential (Get-Credential) -query "_sourceCategory=my_app" -fromDate (get-date).AddDays(-2) -toDate (get-date)
    
    .LINK
    Also similar to https://github.com/rdegges/sumologic-export, except you can specify a filter rather than just a date range.

    .NOTES
    Originally had the different parts split into functions, but there is so much state to pass around that it was simpler as a big
    ball of mud.
    #>
    param(
  [System.Management.Automation.CredentialAttribute()] $credential,
  [String]$query,
  [DateTime]$fromDate = (get-date).AddDays(-30),
  [DateTime]$toDate = (get-date),
  [String]$timeZone = "UTC",
  [String]$filePrefix = "export_",  
  [int]$pageSize = 10000,
  [String]$apiEndpoint="https://api.au.sumologic.com/api/v1")

  # Create a Basic auth header value out of the provided credentials
  $authpair = "$($credential.UserName):$($credential.GetNetworkCredential().Password)"
  $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($authpair))
  $basicAuthValue = "Basic $encodedCreds"
  # Create the headers required for the initial Sumo request
  $headers =  @{"Accept"="application/json";"Content-type"= "application/json";"Authorization" = $basicAuthValue}
  
  # Build the job search request
  $fromDateString = $fromDate.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ss" )
  $toDateString = $toDate.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ss" )
  $body=@{"query"=$query;"from"= $fromDateString;"to"=$toDateString;"timeZone"=$timeZone} | ConvertTo-Json
  write-host "Creating a search job"
  # The sumo logic "API" requires carrying cookies between calls ಠ_ಠ
  $response=Invoke-WebRequest -Uri "$apiEndpoint/search/jobs" -Method Post -Headers $headers -Body $body -SessionVariable webSession
  $content=$response.Content | ConvertFrom-Json
  write-host "Search job created, ID: $($content.id)"
  $jobid=$content.id
  $status=$null
  # Ask Sumo every 5 seconds if the results are in
  while ($true) {
    $response = Invoke-WebRequest -Uri "$apiEndpoint/search/jobs/$jobid" -Method Get -WebSession $webSession
    $status = $response.Content | ConvertFrom-Json
    write-host "State of search job $($jobid) : $($status.state), current message count: $($status.messageCount)"
    if ($status.state -ne 'DONE GATHERING RESULTS'){
      sleep 5
    }
    else{
      break;
    }
  }
  # Retrieve in batches until all messages are downloaded
  $counter=0
  $total=$status.messageCount
  while ($counter -lt $total){
    $filePath = "$($filePrefix)_$($counter).json"
    Invoke-WebRequest -Uri "$apiEndpoint/search/jobs/$($jobid)/messages?offset=$counter&limit=$pageSize" -Method Get -WebSession $createSearchJobResult.webSession -OutFile $filePath
    echo $counter;$counter += $pageSize;
  }
  write-host "Export complete!"
}



