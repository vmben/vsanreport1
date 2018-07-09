Import-Module VMware.VimAutomation.Core -ErrorAction:SilentlyContinue
Import-Module VMware.VimAutomation.Storage -ErrorAction:SilentlyContinue

####################################################################################
#Change the following as required
####################################################################################
 $XMLFile = "vsan.xml"				#Path to generated report
 $vCenter= Read-Host 'Please enter vCenter Server IP or FQDN'				
 $ReportVersion="0.1"
 $dn=0 #disk counter

#Initial XML Setup
(@"
 <?xml version="1.0"?> 
 <Report_Version>$($ReportVersion)</Report_Version>
"@) | Out-File $XMLFile
 
 
 
 
try{
       Disconnect-VIServer -Confirm:$false -ErrorAction:SilentlyContinue
       Connect-VIServer -Server $vCenter  -ErrorAction:SilentlyContinue
}
catch{
       Write-Host "Failed to connect to vCenter Server $vCenter"
       exit 
}


$vSANClusterList = Get-Cluster | Sort-Object -Property Name

foreach ($vSAN in $vSANClusterList) {
  
        if ($vSAN.VsanEnabled -eq $true) {
            
             $vSANStatus = 'Enabled'
            
            
        Write-Host "`tGathering configuration details from vSAN Cluster: $vSAN ..."
        Write-Host ((Get-Date -Format G) + "`tGathering claimed disks configuration...")
        $vSAN = $vSAN | Get-VsanClusterConfiguration
        $vSanDiskGroups = Get-VsanDiskGroup -Cluster $vSAN.name
        $vSanDisks = Get-VsanDisk -vSANDiskGroup $vSanDiskGroups
        $numberDisks = $vSanDisks.Count


		Write-Host ((Get-Date -Format G) + "`tGathering disk group configuration...")
        $numberDiskGroups = $vSanDiskGroups.Count
    
        Write-Host ((Get-Date -Format G) + "`tGathering cluster type Configuration...")
        $magneticDiskCounter = ($vSanDisks | Where-Object {$_.IsSsd -eq $true}).Count
        if ($magneticDiskCounter -gt 0) {
            $clusterType = "Hybrid"
        }
        else {
            $clusterType = "All Flash"
        } 
		
		
        Write-Host ((Get-Date -Format G) + "`tGathering disk claim mode configuration...")
        $diskClaimMode = $vSAN.VsanDiskClaimMode

        
        Write-Host((Get-Date -Format G) + "`tGathering deduplication & compression configuration...")
        $deduplicationCompression = $vSAN.SpaceEfficiencyEnabled

        
        Write-Host ((Get-Date -Format G) + "`tGathering stretched cluster configuration...")
        $stretchedCluster = $vSAN.StretchedClusterEnabled
            
        
        Write-Host ((Get-Date -Format G) + "`tGathering space usage data...")
        $vSANCapacity = Get-VsanSpaceUsage -Cluster $vSAN.name

		
		#Append XML
		
(@"
  <VSAN_$($vSAN.name)>
  <General_Info>
   <Is_VSAN_Enabled>$($vSANStatus)</Is_VSAN_Enabled>
   <Cluster_Type>$(($clusterType))</Cluster_Type>
   <Disk_Claim_Mode>$($diskClaimMode)</Disk_Claim_Mode>
   <Stretched_Cluster>$($stretchedCluster)</Stretched_Cluster>
   <Number_Disks>$($$numberDisks)</Number_Disks>
   <Number_Diskgroups>$($numberDiskGroups)</Number_Diskgroups>
   </General_Info>
  <VSAN_$($vSAN.name)>
  <Disks>
"@) | Out-File $XMLFile -Append
		
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


}
        else {
                      
             Write-Host "vSAN disabled on Cluster $vSAN.Name"
                
            } #END [PSCustomObject]
            continue
        } 

		

<#



#>
