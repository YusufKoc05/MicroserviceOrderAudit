SELECT
    YEAR(s.SiparisTarihi) AS Yil,
    MONTH(s.SiparisTarihi) AS Ay,
    COUNT(*) AS SiparisSayisi,
    SUM(s.GenelToplam) AS ToplamCiro,
    AVG(s.GenelToplam) AS OrtalamaSepetTutari
FROM [Siparis].[Siparisler] s
GROUP BY
    YEAR(s.SiparisTarihi),
    MONTH(s.SiparisTarihi)
ORDER BY Yil, Ay;