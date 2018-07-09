Import-Module VMware.VimAutomation.Core -ErrorAction:SilentlyContinue
Import-Module VMware.VimAutomation.Storage -ErrorAction:SilentlyContinue

#----------------------------------------------------------[Declarations]--------------------------------------------
#Change the following as required
####################################################################################
 $XMLFile = "vsan.xml"				#Path to generated report
 $vCenter= Read-Host 'Please enter vCenter Server IP or FQDN'				#vCenter hostname or IP Address
 $ReportVersion="0.1"


#Initial XML Setup
(@"
 <?xml version="1.0"?> 
 <Report_Version>$($Report_Version)</Report_Version>
 
"@) | Out-File $XMLFile
 
 
 
 
try{
       Disconnect-VIServer -Confirm:$false -ErrorAction:SilentlyContinue
       Connect-VIServer -Server $vCenter 
}
catch{
       Write-Host "Failed to connect to vCenter Server $vCenter"
       exit #Exit script on error
}


$vSANClusterList = Get-Cluster | Sort-Object -Property Name

foreach ($vSAN in $vSANClusterList) {
  
        if ($vSAN.VsanEnabled -eq $true) {
            
             $vSANStatus = 'Enabled'
            
            
        Write-Host "`tGathering configuration details from vSAN Cluster: $vSAN ..."
        Write-Verbose -Message ((Get-Date -Format G) + "`tGathering claimed disks configuration...")
        $vSAN = $vSAN | Get-VsanClusterConfiguration
        $vSanDiskGroups = Get-VsanDiskGroup -Cluster $vSAN.name
        $vSanDisks = Get-VsanDisk -vSANDiskGroup $vSanDiskGroups
        $numberDisks = $vSanDisks.Count


		Write-Verbose -Message ((Get-Date -Format G) + "`tGathering disk group configuration...")
        $numberDiskGroups = $vSanDiskGroups.Count
    
        Write-Verbose -Message ((Get-Date -Format G) + "`tGathering cluster type Configuration...")
        $magneticDiskCounter = ($vSanDisks | Where-Object {$_.IsSsd -eq $true}).Count
        if ($magneticDiskCounter -gt 0) {
            $clusterType = "Hybrid"
        }
        else {
            $clusterType = "All Flash"
        } 
		
		
        Write-Verbose -Message ((Get-Date -Format G) + "`tGathering disk claim mode configuration...")
        $diskClaimMode = $vSAN.VsanDiskClaimMode

        
        Write-Verbose -Message ((Get-Date -Format G) + "`tGathering deduplication & compression configuration...")
        $deduplicationCompression = $vSAN.SpaceEfficiencyEnabled

        
        Write-Verbose -Message ((Get-Date -Format G) + "`tGathering stretched cluster configuration...")
        $stretchedCluster = $vSAN.StretchedClusterEnabled
            
        
        Write-Verbose -Message ((Get-Date -Format G) + "`tGathering space usage data...")
        $vSANCapacity = Get-VsanSpaceUsage -Cluster $vSAN.name

		
		#Append XML
		
(@"
  <VSAN_$($vSAN.name)>
  <General_Info>
   <Is_VSAN_Enabled>$($vSANStatus)</Is_VSAN_Enabled>
   <Cluster_Type>$(($clusterType))</Cluster_Type>
   <Disk_Claim_Mode>$($diskClaimMode)</Disk_Claim_Mode>
   <Stretched_Cluster>$($stretchedCluster)</Stretched_Cluster>
   </General_Info>
  <VSAN_$($vSAN.name)>
"@) | Out-File $XMLFile -Append
		
		



}
        else {
                      
             Write-Host "vSAN disabled on Cluster $vSAN.Name"
                
            } #END [PSCustomObject]
            continue
        } 

		

<#

#-------------------------------------------------------------------------------------
#vSAN Health Info
if ( $Clus.ExtensionData.ConfigIssue.ObjectName -eq "VSAN") {$vSANIssues = $Clus.ExtensionData.ConfigIssue[0].FullFormattedMessage}

(@"
  <Health>
   <Issues>$vSANIssues</Issues>
  </Health>
  <Disks>
"@) | Out-File $vSANFile -Append

#-------------------------------------------------------------------------------------
#vSAN Disks Info

$vSanDisks | % {
  
(@"
  <Disk_$dn>
   <Number>$dn</Number>
   <Name>$($_.Name)</Name>
   <Health>$($_.ExtensionData.OperationalState)</Health>
   <Vendor>$($_.ExtensionData.Vendor)</Vendor>
   <Model>$($_.ExtensionData.Model)</Model>
   <SSD>$($_.IsSsd)</SSD>
   <Size_GB>$(($_.ExtensionData.Capacity.BlockSize * $_.ExtensionData.Capacity.Block) / (1024*1024*1024)))</Size_GB>
   <Queue_Length>$($_.ExtensionData.QueueDepth)</Queue_Length>
   <Format_Ver>$($_.ExtensionData.VsanDiskInfo.FormatVersion)</Format_Ver>
   <vSAN_UIID>$($_.ExtensionData.VsanDiskInfo.VsanUuid)</vSAN_UIID>
   <ESXi_Host>$($_.VsanDiskGroup.vmhost.name)</ESXi_Host>
   <Disk_Group>$($_.VsanDiskGroup)</Disk_Group>
  </Disk>
"@) | Out-File $vSANFile -Append
  
  $dn++
}

" </Disks>" | Out-File $vSANFile -Append
#>
