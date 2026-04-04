SELECT TOP 20
    s.SiparisNo,
    s.AraToplam,
    SUM(sk.SatirToplami) AS KalemlerToplami,
    s.AraToplam - SUM(sk.SatirToplami) AS Fark
FROM [Siparis].[Siparisler] s
JOIN [Siparis].[SiparisKalemleri] sk
    ON s.SiparisID = sk.SiparisID
GROUP BY
    s.SiparisNo,
    s.AraToplam
HAVING ABS(s.AraToplam - SUM(sk.SatirToplami)) > 0.01
ORDER BY ABS(s.AraToplam - SUM(sk.SatirToplami)) DESC;