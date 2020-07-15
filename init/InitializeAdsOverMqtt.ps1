$hostname = $args[0]

# Remove any existing files
if (Test-Path -Path "$caPath\$tcSysSrvAdsMqttClientCert") {
    Remove-Item -Recurse -Force "$caPath\$tcSysSrvAdsMqttClientCert"
}
if (Test-Path -Path "$caPath\$tcSysSrvAdsMqttClientKey") {
    Remove-Item -Recurse -Force "$caPath\$tcSysSrvAdsMqttClientKey"
}

# Generate new private key
Start-Process -Wait -WindowStyle Hidden -FilePath "openssl.exe" -WorkingDirectory $caPath -ArgumentList "genrsa -out $tcSysSrvAdsMqttClientKey 2048"

# Generate self-signed certificate
Start-Process -Wait -WindowStyle Hidden -FilePath "openssl.exe" -WorkingDirectory $caPath -ArgumentList "req -new -sha256 -key $tcSysSrvAdsMqttClientKey -out $tcSysSrvAdsMqttClientCert -subj /C=DE/ST=NRW/L=Verl/O=BeckhoffAutomation/OU=DeviceCert/CN=$publicIp"

# Sign self-signed certificate by certificate authority
Start-Process -Wait -WindowStyle Hidden -FilePath "openssl.exe" -WorkingDirectory $caPath -ArgumentList "x509 -req -in $tcSysSrvAdsMqttClientCert -CA $caCert -CAkey $caKey -CAcreateserial -out $tcSysSrvAdsMqttClientCert -days 7300 -sha256"

# Remove any existing ADS-over-MQTT routes file but create a backup first
if (-not (Test-Path -Path $tcSysSrvRoutesPath)) {
  New-Item -Path $tcSysSrvRoutesPath -ItemType "directory"
}
if (Test-Path -Path "$tcSysSrvRoutesPath\$tcSysSrvRoutesName") {
    Copy-Item -Path "$tcSysSrvRoutesPath\$tcSysSrvRoutesName" -Destination "$tcSysSrvRoutesPath\$tcSysSrvRoutesName.bak"
    Remove-Item -Recurse -Force "$tcSysSrvRoutesPath\$tcSysSrvRoutesName"
}

# Create new routes file for ADS-over-MQTT
if (-not (Test-Path -Path "$tcSysSrvRoutesPath\$templateRoutesFile")) {
  Copy-Item -Path "$repoPathInitScripts\templates\$templateRoutesFile" -Destination "$tcSysSrvRoutesPath\$templateRoutesFile"
}
$routesContent = Get-Content -Path "$tcSysSrvRoutesPath\$templateRoutesFile" -Raw
$routesContent = $routesContent.Replace("%hostname%", $publicIp)
$routesContent = $routesContent.Replace("%port%", "8883")
$routesContent = $routesContent.Replace("%caCertPath%", "$caPath\$caCert")
$routesContent = $routesContent.Replace("%clientCertPath%", "$caPath\$tcSysSrvAdsMqttClientCert")
$routesContent = $routesContent.Replace("%clientKeyPath%", "$caPath\$tcSysSrvAdsMqttClientKey")

Set-Content -Path $tcSysSrvRoutesPath\$templateRoutesFile -Value $routesContent

# Restart of TcSysSrv service required -> will be performed by reboot anyway