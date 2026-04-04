WITH Aylik AS
(
    SELECT
        YEAR(SiparisTarihi) AS Yil,
        MONTH(SiparisTarihi) AS Ay,
        SUM(GenelToplam) AS ToplamCiro
    FROM [Siparis].[Siparisler]
    GROUP BY YEAR(SiparisTarihi), MONTH(SiparisTarihi)
)
SELECT
    Yil,
    Ay,
    ToplamCiro,
    LAG(ToplamCiro) OVER (ORDER BY Yil, Ay) AS OncekiAyCiro,
    ToplamCiro - LAG(ToplamCiro) OVER (ORDER BY Yil, Ay) AS AylikFark
FROM Aylik
ORDER BY Yil, Ay;