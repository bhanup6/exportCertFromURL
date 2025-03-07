$webRequest = [Net.WebRequest]::Create("https://example.com")
$webRequest.GetResponse().Dispose()
$cert = $webRequest.ServicePoint.Certificate
$bytes = $cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
[System.IO.File]::WriteAllBytes("certificate.cer", $bytes)
