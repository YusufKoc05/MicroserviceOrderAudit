SELECT 'Kullanicilar' AS TabloAdi, COUNT(*) AS KayitSayisi FROM [Kimlik].[Kullanicilar]
UNION ALL
SELECT 'Siparisler', COUNT(*) FROM [Siparis].[Siparisler]
UNION ALL
SELECT 'SiparisKalemleri', COUNT(*) FROM [Siparis].[SiparisKalemleri]
UNION ALL
SELECT 'OdemeIslemleri', COUNT(*) FROM [Odeme].[OdemeIslemleri]
UNION ALL
SELECT 'IadeIslemleri', COUNT(*) FROM [Odeme].[IadeIslemleri]
UNION ALL
SELECT 'KargoGonderileri', COUNT(*) FROM [Kargo].[KargoGonderileri]
UNION ALL
SELECT 'KargoHareketleri', COUNT(*) FROM [Kargo].[KargoHareketleri]
UNION ALL
SELECT 'DenetimKayitlari', COUNT(*) FROM [Denetim].[DenetimKayitlari];