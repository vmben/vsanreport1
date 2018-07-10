$username="apiuser@vsphere.local"
$password="Apiuser123@"

if (-not ([System.Management.Automation.PSTypeName]"TrustEverything").Type)
    {
	        Add-Type -TypeDefinition  @"
			using System.Net.Security;
			using System.Security.Cryptography.X509Certificates;
			public static class TrustEverything{
			    private static bool ValidationCallback(object sender, X509Certificate certificate, X509Chain chain,
				        SslPolicyErrors sslPolicyErrors) { return true; }
						    public static void SetCallback() { System.Net.ServicePointManager.ServerCertificateValidationCallback = ValidationCallback; }
							    public static void UnsetCallback() { System.Net.ServicePointManager.ServerCertificateValidationCallback = null; }
								}
"@
								    }
[TrustEverything]::SetCallback()



$Headers = @{ Authorization = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password))) }


Invoke-RestMethod -uri "https://192.168.1.222/rest/vxm/v1/system-health" -Headers $headers -method get