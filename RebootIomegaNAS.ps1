function RebootIomegaNAS{
    <#
    .SYNOPSIS

    Used to reboot an Iomega NAS using HTTP requests.

    Tested with StorCenter ix2-200.
    
    .DESCRIPTION

    Reboots an Iomega NAS by using the same HTTP requests that are made when manually rebooting via the web browser. 
    
    These were recorded using Chrome developer tools, and the equivalent requests/responses made using System.Net.WebRequest.

    .PARAMETER HostnameOrIp

    The address of the NAS drive.

    .PARAMETER Username

    The NAS username

    .PARAMETER Password

    The NAS password
    
    .EXAMPLE

    RebootIomegaNAS -HostnameOrIp "192.168.0.5" -Username "admin" -Password "admin"
    
    .NOTES

    The Ignore_SSL function included in the script is used to ignore SSL certificate warnings during the requests.

        #>
    Param([string]$HostnameOrIp = $(throw "HostnameOrIp parameter not specified"), 
            [string]$Username = $(throw "Username parameter not specified"), 
            [string]$Password = $(throw "Password parameter not specified"))

    Write-Host "Rebooting $HostnameOrIp..."
    $ErrorActionPreference = "Stop"
    Ignore_SSL

    Write-Host "Making initial request for session cookie"

    $request1 = [System.Net.WebRequest]::Create("https://$HostnameOrIp/");
    $request1.Timeout = 5000;
    $response1 = $request1.GetResponse();
    if ($response1.StatusCode -eq $null -or $response1.StatusCode -ne "OK")
    {
	    Write-Host "Web request failed. Status Code was" $response1.StatusCode
	    exit
    }
    $response1.Close();
    Write-Host "Initial request complete"

    $cookie = $response1.Headers["Set-Cookie"]
    Write-Host "Cookie: $cookie"

    $body2 = "hf_t=1&currentPage=index.html&visitedPages=index.html&login=$Username&passwordx=$Password&apply=Log+In"
    Write-Host "Making login request"
    $request2 = [System.Net.WebRequest]::Create("https://$HostnameOrIp/index.html");
    $request2.Method="POST";
    $request2.Timeout = 5000;
    $request2.ContentType = "application/x-www-form-urlencoded"
    $request2.Headers["Cookie"] = $cookie
    $body2str = [System.Text.Encoding]::UTF8.GetBytes($body2);

    $requestStream2 = $request2.GetRequestStream();
    $requestStream2.Write($body2str, 0,$body2str.length);
    $requestStream2.Close();

    [System.Net.WebResponse] $response2 = $request2.GetResponse();
    $responseStream = $response2.GetResponseStream();
    $sr = new-object System.IO.StreamReader $responseStream 
    $result2 = $sr.ReadToEnd();
    $response2.Close();
    if ($result2.Contains("Invalid Username or Password"))
    {
	    Write-Error "Login failed due to invalid credentials"
    }
    if ($response2.StatusCode -eq $null -or $response2.StatusCode -ne "OK")
    {
	    Write-Host "Web request failed. Status Code was" $response2.StatusCode
	    exit
    }

    Write-Host "Login request complete"

    $body3 = "hf_t=1&currentPage=dashboard.html&visitedPages=dashboard.html&restart=Restart"
    Write-Host "Making reboot request"

    $request3 = [System.Net.WebRequest]::Create("https://$HostnameOrIp/dashboard.html?t=1");
    $request3.Method="POST";
    $request3.Timeout = 5000;
    $request3.Headers["Cookie"] = $cookie
    $request3.ContentType = "application/x-www-form-urlencoded"
    $body3str = [System.Text.Encoding]::UTF8.GetBytes($body3);

    $requestStream3 = $request3.GetRequestStream();
    $requestStream3.Write($body3str, 0,$body3str.length);
    $requestStream3.Close();
    Write-Host "About to call reboot request"
    $ErrorActionPreference = "SilentlyContinue"
    [System.Net.WebResponse] $response3 = $request3.GetResponse();

    $response3.Close();
}


function Ignore_SSL
{
	$Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
	$Compiler= $Provider.CreateCompiler()
	$Params = New-Object System.CodeDom.Compiler.CompilerParameters
	$Params.GenerateExecutable = $False
	$Params.GenerateInMemory = $True
	$Params.IncludeDebugInformation = $False
	$Params.ReferencedAssemblies.Add("System.DLL") > $null
	$TASource=@'
		namespace Local.ToolkitExtensions.Net.CertificatePolicy
		{
			public class TrustAll : System.Net.ICertificatePolicy
			{
				public TrustAll() {}
				public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
				{
					return true;
				}
			}
		}
'@ 
	$TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
	$TAAssembly=$TAResults.CompiledAssembly
    ## We create an instance of TrustAll and attach it to the ServicePointManager
	$TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}