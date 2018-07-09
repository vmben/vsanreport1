
Import-Module VMware.VimAutomation.Core -ErrorAction:SilentlyContinue
Import-Module VMware.VimAutomation.Storage -ErrorAction:SilentlyContinue

#----------------------------------------------------------[Declarations]--------------------------------------------
#Change the following as required
####################################################################################
 $vSANFile = "C:\vsan.xml"				#Path to generated report
 $vCenter= Read-Host 'Please enter vCenter Server IP or FQDN'				#vCenter hostname or IP Address
 $clusName = Read-Host 'Please enter cluster name'			#Cluster name
 $vSANPolName="Virtual SAN Default Storage Policy"	#vSAN Storage Policy - Assuming default name
 $vSANDSName="vsanDatastore"				#Default name for the VSAN DS
####################################################################################
 $ReportVersion="0.1"
 $vSANIssues=""						#String var holding VSAN error / warning msg
 $dn=0							#Used a disk counter

#----------------------------------------------------------[Execution]-----------------------------------------------
#Drop any existing open VI connections and connect to vCenter Server $vCenter
try{
       Disconnect-VIServer -Confirm:$false -ErrorAction:SilentlyContinue
       Connect-VIServer -Server $vCenter 
}
catch{
       Write-Host "Failed to connect to vCenter Server $vCenter"
       exit #Exit script on error
}

#Retrieve cluster and vSAN info
 $Clus = Get-Cluster -Name $clusName
 $vSanDisks = Get-VSanDisk
 $vSanDGroups = Get-VsanDiskGroup
 $vSANPolicy = (Get-SpbmStoragePolicy -Name $vSANPolName).AnyOfRuleSets.allofrules
 $vSANDS = (Get-Datastore -Name $vSANDSName)  

#Write vSAN info to file $vSANFile
#vSAN Settings
(@"
 <?xml version="1.0"?> 
 <Report_Version>$($Report_Version)</Report_Version>
 <VSAN>
  <General_Info>
   <Is_VSAN_Enabled>$($clus.VsanEnabled)</Is_VSAN_Enabled>
   <No_Of_Disk_Groups>$(($vSanDGroups).count)</No_Of_Disk_Groups>
   <No_of_SSD_Disks>$(($vSanDisks | where {$_.IsSSD -eq "True"}).count)</No_of_SSD_Disks>
   <No_of_Non_SSD_Disks>$(($vSanDisks | where {$_.IsSSD -ne "True"}).count)</No_of_Non_SSD_Disks>
   <Disk_Claim_Mode>$($clus.VsanDiskClaimMode)</Disk_Claim_Mode>
  </General_Info>
"@) | Out-File $vSANFile -Append

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

#-------------------------------------------------------------------------------------
#vSAN Datastore Table Header and Data

(@"
  <vSAN_DS_Info>
   <State>$($vSANDS.State)</State>
   <Capacity_(GB)>$($vSANDS.CapacityGB)</Capacity_(GB)>
   <Free_Space_(GB)>$($vSANDS.FreeSpaceGB)</Free_Space_(GB)>
   <ID>$($vSANDS.Id)</ID>
  </vSAN_DS_Info>
  <vSAN_Storage_Policy>
"@) | Out-File $vSANFile -Append

#-------------------------------------------------------------------------------------
#vSAN Storage Policy Table Header and Data

$vSANPolicy | % { #Get rules set capabilities
(@"
   <$($_.Capability)>$($_.value)</$($_.Capability)>
"@) | Out-File $vSANFile -Append
}

(@"
  </vSAN_Storage_Policy>
</VSAN>  
"@) | Out-File $vSANFile -Append
