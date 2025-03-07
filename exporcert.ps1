[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
try {
    $request = [System.Net.HttpWebRequest]::Create("https://digicert.com")
    $response = $request.GetResponse()
    $cert = $request.ServicePoint.Certificate  # Access from ServicePoint
    $response.Close()

    if ($cert) {
        $bytes = $cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        [System.IO.File]::WriteAllBytes("C:\Users\user1\certificate_digi.cer", $bytes)
        Write-Host "Certificate exported successfully!"
    } else {
        Write-Host "Error: No certificate found on ServicePoint."
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}
