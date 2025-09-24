# Description
Salibo is a multi-protocol Password Sprayer

# Usage

-u                Username or file containing usernames one per line.

-p                Password or file containing passwords one per line.

-dc               Domain controller to use

-domain           Domain FQDN.

-method           Method to use (WINRM, SMB, CIM). Default: SMB

-auth             Authentication method to use KERBEROS, NTLMDomain (Only applies to CIM method) or DEFAULT). Default: DEFAULT

-delay            Time in seconds to delay between tries. Default: 0

-jitter           Maximum randomized delay variation (Requires delay to be set). Default: 0

-timestamps       Add timestamp to each attempt. Default: $false

-WINRMStealth     If machine is on the domain it will not try to connect to WINRM and will just validate credentials failures are not in logs. Default: $false

# Example
Salibo.ps1 -u ".\users.txt" -p "P@ssword" -dc "BBL-DC" -domain "BBLABS.LOCAL" -method "CIM" -auth "KERBEROS" -timestamps $true -delay 30 -jitter 15
