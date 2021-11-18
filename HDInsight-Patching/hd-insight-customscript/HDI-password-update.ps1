[CmdletBinding()]
param (
        [Parameter()]
		[string] $subscription_id ,
        [Parameter()]
		[string] $resource_group_name ,
        [Parameter()]
		[string] $cluster_name ,
        [Parameter()]
		[string] $script_action_name ,
        [Parameter()]
		$nodeTypes = @("HeadNode"), #, "WorkerNode", "ZookeeperNode"),
        [Parameter()]
		[string] $script_action_uri,
        [Parameter()]
		[string]$remove_persisted_script_action = $false,
        [Parameter()]
        $keyvaultName,
        [Parameter()]
        $keyvaultSecretName,
        [Parameter()]
        $identifier='01'
    )

    #Install-Module Az.HDInsight -Force
    Write-host "-----------------------------------------------------------------------------------------"
    Write-host "=================== Arguments ===================="
    Write-host "SubscriptionId ::" $subscription_id
    Write-host "resource_group_name ::" $resource_group_name
    Write-host "cluster_name ::" $cluster_name
    Write-host "script_action_name ::" $script_action_name
    Write-host "script_action_uri ::" $script_action_uri
    Write-host "remove_persisted_script_action ::" $remove_persisted_script_action
    Write-host "keyvaultName ::" $keyvaultName
    Write-host "keyvaultSecretName ::" $keyvaultSecretName
    Write-host "-----------------------------------------------------------------------------------------"

    #Select-AzSubscription -SubscriptionId $subscription_id
    Get-AzContext

    function Get-RandomCharacters($length, $characters) {
        $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
        $private:ofs=""
        return [String]$characters[$random]
      }
      
      function Scramble-String([string]$inputString){     
        $characterArray = $inputString.ToCharArray()   
        $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
        $outputString = -join $scrambledStringArray
        return $outputString 
      }
      
      $password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
      $password += Get-RandomCharacters -length 2 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
      $password += Get-RandomCharacters -length 3 -characters '1234567890'
      $password += Get-RandomCharacters -length 2 -characters '@#*+'

      #not allowed character " ' ` / \ < % ~ | $ & !
      
      $password = Scramble-String $password
      
      write-host "password is :::" $password
      
        $Bytes = [System.Text.Encoding]::Unicode.GetBytes($password)
        $EncodedText =[Convert]::ToBase64String($Bytes)
    
      
      $scriptParameters = "spadmin $EncodedText"

        
        $script_action_name = "$script_action_name-$identifier".Replace('.','-')
        

        Submit-AzHDInsightScriptAction  -ClusterName $cluster_name `
                                        -ResourceGroupName $resource_group_name `
                                        -Name $script_action_name `
                                        -Uri $script_action_uri `
                                        -NodeTypes $nodeTypes -PersistOnSuccess `
                                        -Parameters $scriptParameters

        if($remove_persisted_script_action -eq $true)
        {
            
            Remove-AzHDInsightPersistedScriptAction -ClusterName $cluster_name `
                                            -ResourceGroupName $resource_group_name `
                                            -Name $script_action_name 
        }

        Set-AzContext -Subscription $subscription_id

        # Password expires in 70 days hence setting up the expiration date
        $Expires = (Get-Date).AddDays(70).ToUniversalTime()
        Write-Host "Update secrets into keyvault $keyVaultName : secret :: $keyvaultSecretName"
        $SecureStringPassword = ConvertTo-SecureString -String $password -AsPlainText -Force

        Write-Host "Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyvaultSecretName -SecretValue $SecureStringPassword -Expires $Expires"
        
        Set-AzKeyVaultSecret -VaultName $keyVaultName -Name ($keyvaultSecretName).ToLower() -SecretValue $SecureStringPassword -Expires $Expires

        Write-Host "secret [$keyvaultSecretName] updated into keyvault : $keyVaultName"
