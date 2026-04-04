SELECT
    ot.OlayAdi,
    sv.SeviyeAdi,
    COUNT(*) AS KayitSayisi,
    SUM(CASE WHEN d.BasariliMi = 1 THEN 1 ELSE 0 END) AS BasariliKayit,
    SUM(CASE WHEN d.BasariliMi = 0 THEN 1 ELSE 0 END) AS BasarisizKayit
FROM [Denetim].[DenetimKayitlari] d
JOIN [Denetim].[OlayTurleri] ot
    ON d.OlayTurID = ot.OlayTurID
JOIN [Denetim].[Seviyeler] sv
    ON d.SeviyeID = sv.SeviyeID
GROUP BY
    ot.OlayAdi,
    sv.SeviyeAdi
ORDER BY KayitSayisi DESC;