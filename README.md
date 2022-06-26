# Overview
Oftentimes, AAD security/M365 groups are dynamically populated based on user attributes (e.g. User Job Title/Department/Office), however certain SaaS apps (e.g. Dynamics CRM at the time of writing) cannot work properly with dynamic security groups. 

In order to workaround this limitation, this PowerShell script syncs the group members of a dynamic group to it’s associated assigned security group.

# Architecture & Functionality
The PowerShell script runs as an Azure function app, making use of the AzureAD PowerShell module. 

The script cycles through and compares the dynamic/assigned group pairs defined in $groupsArray and uses the `Add-AzureADGroupMember` / `Remove-AzureADGroupMember` to assign/remove members from groups as appropriate.

The function will need to be called frequently (e.g. every 24 hours) via it's URL. This was achieved through a Logic App making a simple HTTP GET request, but you could setup the function app to use a timer trigger with a little effort.


# Authentication
The script uses cmdlets in the AzureAD module, and must authenticate to the Azure tenant to use these cmdlets. The function app authenticates to Azure AD via an App Registration, specifying the app id & thumbprint of the certificate in the function app SSL/TLS certificate store to authenticate with. 

- Create an app registration, and grant the associated enterprise app's service principal the directory writers role (AAD > Roles > Directory Writers > Add assignment > Add the Enterprise App).
- Configure the app registration to allow authentication via a certificate. (See [this article](https://docs.microsoft.com/en-us/powershell/azure/active-directory/signing-in-service-principal?view=azureadps-2.0)). 
- Store the certificate under the TLS/SSL settings > Private Key Certificates section of the function app.
- Define the `appID`, `tenantID` and (certificate) `thumbprint` values under the app service Configuration > Application settings
