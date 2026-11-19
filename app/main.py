"""
Mikroservis Sipariş ve Merkezi Audit Sistemi - FastAPI Backend & Analitik API
==============================================================================
Veritabanı mimarisini, 21 analitik sorguyu, mikroservis sipariş simülasyonunu
ve merkezi denetim (audit) izlerini sunan REST API ve Dashboard servisi.
"""

import json
import sqlite3
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "data" / "merkezi_audit_siparis.db"
TEMPLATE_PATH = Path(__file__).resolve().parent / "dashboard.html"

app = FastAPI(
    title="Mikroservis Sipariş & Merkezi Audit Analitik Platformu",
    description="MerkeziAuditSiparisDB (Kimlik, Siparis, Odeme, Kargo, Denetim) Veritabanı Mimarisi ve Canlı Analitik API'si",
    version="2.0.0",
)


def query_db(sql: str, params: tuple = ()):
    if not DB_PATH.exists():
        from scripts.generate_data import build_sqlite_database, export_csv_files, generate_datasets
        ds = generate_datasets()
        export_csv_files(ds)
        build_sqlite_database(ds)

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute(sql, params)
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows


# ============================================================================
# KATALOGLANMIŞ 21 ANALİTİK SORGU (Orijinal SQLQuery2..23 + T-SQL Karşılıkları)
# ============================================================================
ANALYTICS_CATALOG = {
    "q03_table_counts": {
        "code": "SQLQuery3",
        "category": "Genel & Doğrulama",
        "title": "Mikroservis Tabloları Kayıt Sayısı Özeti",
        "description": "5 mikroservis şemasındaki ana hareket ve kimlik tablolarının toplam satır sayılarını döndürür.",
        "tsql": """SELECT 'Kullanicilar' AS TabloAdi, COUNT(*) AS KayitSayisi FROM [Kimlik].[Kullanicilar]
UNION ALL SELECT 'Siparisler', COUNT(*) FROM [Siparis].[Siparisler]
UNION ALL SELECT 'SiparisKalemleri', COUNT(*) FROM [Siparis].[SiparisKalemleri]
UNION ALL SELECT 'OdemeIslemleri', COUNT(*) FROM [Odeme].[OdemeIslemleri]
UNION ALL SELECT 'IadeIslemleri', COUNT(*) FROM [Odeme].[IadeIslemleri]
UNION ALL SELECT 'KargoGonderileri', COUNT(*) FROM [Kargo].[KargoGonderileri]
UNION ALL SELECT 'KargoHareketleri', COUNT(*) FROM [Kargo].[KargoHareketleri]
UNION ALL SELECT 'DenetimKayitlari', COUNT(*) FROM [Denetim].[DenetimKayitlari];""",
        "sqlite": """SELECT 'Kimlik.Kullanicilar' AS TabloAdi, COUNT(*) AS KayitSayisi FROM Kimlik_Kullanicilar
UNION ALL SELECT 'Siparis.Siparisler', COUNT(*) FROM Siparis_Siparisler
UNION ALL SELECT 'Siparis.SiparisKalemleri', COUNT(*) FROM Siparis_SiparisKalemleri
UNION ALL SELECT 'Odeme.OdemeIslemleri', COUNT(*) FROM Odeme_OdemeIslemleri
UNION ALL SELECT 'Odeme.IadeIslemleri', COUNT(*) FROM Odeme_IadeIslemleri
UNION ALL SELECT 'Kargo.KargoGonderileri', COUNT(*) FROM Kargo_KargoGonderileri
UNION ALL SELECT 'Kargo.KargoHareketleri', COUNT(*) FROM Kargo_KargoHareketleri
UNION ALL SELECT 'Denetim.DenetimKayitlari', COUNT(*) FROM Denetim_DenetimKayitlari;""",
    },
    "q04_top_customers": {
        "code": "SQLQuery4",
        "category": "Müşteri & Kimlik",
        "title": "En Çok Sipariş Veren İlk 10 VIP Müşteri",
        "description": "Sipariş adedi ve toplam harcama tutarına göre en değerli ilk 10 müşteriyi listeler.",
        "tsql": """SELECT TOP 10 k.KullaniciID, k.KullaniciAdi, k.Ad, k.Soyad,
       COUNT(s.SiparisID) AS SiparisSayisi, SUM(s.GenelToplam) AS ToplamHarcama
FROM [Kimlik].[Kullanicilar] k
JOIN [Siparis].[Siparisler] s ON s.KullaniciID = k.KullaniciID
GROUP BY k.KullaniciID, k.KullaniciAdi, k.Ad, k.Soyad
ORDER BY SiparisSayisi DESC, ToplamHarcama DESC;""",
        "sqlite": """SELECT k.KullaniciID, k.KullaniciAdi, k.Ad || ' ' || k.Soyad AS AdSoyad,
       COUNT(s.SiparisID) AS SiparisSayisi, ROUND(SUM(s.GenelToplam), 2) AS ToplamHarcama
FROM Kimlik_Kullanicilar k
JOIN Siparis_Siparisler s ON s.KullaniciID = k.KullaniciID
GROUP BY k.KullaniciID, k.KullaniciAdi, k.Ad, k.Soyad
ORDER BY SiparisSayisi DESC, ToplamHarcama DESC LIMIT 10;""",
    },
    "q05_recent_orders": {
        "code": "SQLQuery5",
        "category": "Sipariş & Ciro",
        "title": "Mikroservis Kaynaklı Son 20 Sipariş",
        "description": "Siparişleri müşteri, durum ve siparişi oluşturan mikroservis bilgisiyle birlikte getirir.",
        "tsql": """SELECT TOP 20 s.SiparisID, s.SiparisNo, k.Ad + N' ' + k.Soyad AS Musteri,
       sd.DurumAdi AS SiparisDurumu, srv.ServisAdi AS OlusturanServis,
       s.GenelToplam, s.ParaBirimi, s.SiparisTarihi
FROM [Siparis].[Siparisler] s
JOIN [Kimlik].[Kullanicilar] k ON s.KullaniciID = k.KullaniciID
JOIN [Siparis].[SiparisDurumlari] sd ON s.SiparisDurumID = sd.SiparisDurumID
JOIN [Kimlik].[Servisler] srv ON s.OlusturanServisID = srv.ServisID
ORDER BY s.SiparisTarihi DESC;""",
        "sqlite": """SELECT s.SiparisID, s.SiparisNo, k.Ad || ' ' || k.Soyad AS Musteri,
       sd.DurumAdi AS SiparisDurumu, srv.ServisAdi AS OlusturanServis,
       ROUND(s.GenelToplam, 2) AS GenelToplam, s.ParaBirimi, s.SiparisTarihi
FROM Siparis_Siparisler s
JOIN Kimlik_Kullanicilar k ON s.KullaniciID = k.KullaniciID
JOIN Siparis_SiparisDurumlari sd ON s.SiparisDurumID = sd.SiparisDurumID
JOIN Kimlik_Servisler srv ON s.OlusturanServisID = srv.ServisID
ORDER BY s.SiparisTarihi DESC LIMIT 20;""",
    },
    "q07_status_revenue": {
        "code": "SQLQuery7",
        "category": "Sipariş & Ciro",
        "title": "Sipariş Durumlarına Göre Ciro ve Ortalama Sepet",
        "description": "Her bir sipariş durumundaki toplam sipariş sayısını, toplam ciroyu ve ortalama sepet tutarını hesaplar.",
        "tsql": """SELECT sd.DurumAdi, COUNT(*) AS SiparisSayisi,
       SUM(s.GenelToplam) AS ToplamCiro, AVG(s.GenelToplam) AS OrtalamaSiparisTutari
FROM [Siparis].[Siparisler] s
JOIN [Siparis].[SiparisDurumlari] sd ON s.SiparisDurumID = sd.SiparisDurumID
GROUP BY sd.DurumAdi ORDER BY ToplamCiro DESC;""",
        "sqlite": """SELECT sd.DurumAdi, COUNT(*) AS SiparisSayisi,
       ROUND(SUM(s.GenelToplam), 2) AS ToplamCiro,
       ROUND(AVG(s.GenelToplam), 2) AS OrtalamaSiparisTutari
FROM Siparis_Siparisler s
JOIN Siparis_SiparisDurumlari sd ON s.SiparisDurumID = sd.SiparisDurumID
GROUP BY sd.DurumAdi ORDER BY ToplamCiro DESC;""",
    },
    "q09_monthly_growth": {
        "code": "SQLQuery8 & SQLQuery9",
        "category": "Sipariş & Ciro",
        "title": "Window Function (LAG) ile Aylık Ciro ve Büyüme Analizi",
        "description": "Aylık toplam ciroyu ve bir önceki aya göre ciro farkını (LAG Window Function) raporlar.",
        "tsql": """WITH Aylik AS (
    SELECT YEAR(SiparisTarihi) AS Yil, MONTH(SiparisTarihi) AS Ay, SUM(GenelToplam) AS ToplamCiro
    FROM [Siparis].[Siparisler] GROUP BY YEAR(SiparisTarihi), MONTH(SiparisTarihi)
)
SELECT Yil, Ay, ToplamCiro,
       LAG(ToplamCiro) OVER (ORDER BY Yil, Ay) AS OncekiAyCiro,
       ToplamCiro - LAG(ToplamCiro) OVER (ORDER BY Yil, Ay) AS AylikFark
FROM Aylik ORDER BY Yil, Ay;""",
        "sqlite": """WITH Aylik AS (
    SELECT substr(SiparisTarihi, 1, 7) AS Donem,
           COUNT(*) AS SiparisSayisi,
           ROUND(SUM(GenelToplam), 2) AS ToplamCiro
    FROM Siparis_Siparisler
    GROUP BY substr(SiparisTarihi, 1, 7)
)
SELECT Donem, SiparisSayisi, ToplamCiro,
       ROUND(LAG(ToplamCiro) OVER (ORDER BY Donem), 2) AS OncekiAyCiro,
       ROUND(ToplamCiro - COALESCE(LAG(ToplamCiro) OVER (ORDER BY Donem), ToplamCiro), 2) AS AylikFark
FROM Aylik ORDER BY Donem;""",
    },
    "q10_top_products_qty": {
        "code": "SQLQuery10 & SQLQuery11",
        "category": "Ürün Performansı",
        "title": "En Çok Satan ve Ciro Üreten İlk 10 Ürün",
        "description": "Satış adedi, toplam gelir ve ortalama birim fiyata göre ürün performans sıralaması.",
        "tsql": """SELECT TOP 10 sk.UrunKodu, sk.UrunAdi,
       SUM(sk.Miktar) AS ToplamAdet, SUM(sk.SatirToplami) AS ToplamSatisTutari,
       AVG(sk.BirimFiyat) AS OrtalamaBirimFiyat
FROM [Siparis].[SiparisKalemleri] sk
GROUP BY sk.UrunKodu, sk.UrunAdi
ORDER BY ToplamSatisTutari DESC;""",
        "sqlite": """SELECT sk.UrunKodu, sk.UrunAdi,
       SUM(sk.Miktar) AS ToplamAdet,
       ROUND(SUM(sk.SatirToplami), 2) AS ToplamSatisTutari,
       ROUND(AVG(sk.BirimFiyat), 2) AS OrtalamaBirimFiyat
FROM Siparis_SiparisKalemleri sk
GROUP BY sk.UrunKodu, sk.UrunAdi
ORDER BY ToplamSatisTutari DESC LIMIT 10;""",
    },
    "q13_inactive_users": {
        "code": "SQLQuery13",
        "category": "Müşteri & Kimlik",
        "title": "Kayıtlı Olup Henüz Sipariş Vermemiş Kullanıcılar (Churn/Aktivasyon)",
        "description": "LEFT JOIN ile sipariş tablosunda karşılığı olmayan pasif kullanıcıları tespit eder.",
        "tsql": """SELECT TOP 20 k.KullaniciID, k.KullaniciAdi, k.Ad, k.Soyad, k.Eposta
FROM [Kimlik].[Kullanicilar] k
LEFT JOIN [Siparis].[Siparisler] s ON s.KullaniciID = k.KullaniciID
WHERE s.SiparisID IS NULL ORDER BY k.KullaniciID;""",
        "sqlite": """SELECT k.KullaniciID, k.KullaniciAdi, k.Ad, k.Soyad, k.Eposta, k.KayitTarihi
FROM Kimlik_Kullanicilar k
LEFT JOIN Siparis_Siparisler s ON s.KullaniciID = k.KullaniciID
WHERE s.SiparisID IS NULL ORDER BY k.KullaniciID LIMIT 20;""",
    },
    "q14_payment_methods": {
        "code": "SQLQuery14",
        "category": "Ödeme & İade Finans",
        "title": "Ödeme Yöntemi ve Durumuna Göre Finansal Dağılım",
        "description": "Kredi kartı, banka kartı, EFT ve dijital cüzdan işlemlerinin başarı/hata ve tutar kırılımı.",
        "tsql": """SELECT oy.YontemAdi, od.DurumAdi, COUNT(*) AS IslemSayisi,
       SUM(o.Tutar) AS ToplamTutar, AVG(o.Tutar) AS OrtalamaTutar
FROM [Odeme].[OdemeIslemleri] o
JOIN [Odeme].[OdemeYontemleri] oy ON o.OdemeYontemID = oy.OdemeYontemID
JOIN [Odeme].[OdemeDurumlari] od ON o.OdemeDurumID = od.OdemeDurumID
GROUP BY oy.YontemAdi, od.DurumAdi ORDER BY ToplamTutar DESC;""",
        "sqlite": """SELECT oy.YontemAdi, od.DurumAdi, COUNT(*) AS IslemSayisi,
       ROUND(SUM(o.Tutar), 2) AS ToplamTutar, ROUND(AVG(o.Tutar), 2) AS OrtalamaTutar
FROM Odeme_OdemeIslemleri o
JOIN Odeme_OdemeYontemleri oy ON o.OdemeYontemID = oy.OdemeYontemID
JOIN Odeme_OdemeDurumlari od ON o.OdemeDurumID = od.OdemeDurumID
GROUP BY oy.YontemAdi, od.DurumAdi ORDER BY ToplamTutar DESC;""",
    },
    "q15_failed_payments": {
        "code": "SQLQuery15",
        "category": "Ödeme & İade Finans",
        "title": "Hata Mesajı İçeren Başarısız Ödeme İşlemleri",
        "description": "Banka reddi, yetersiz bakiye veya 3D Secure zaman aşımı nedeniyle hata alan ödemeler.",
        "tsql": """SELECT TOP 20 o.OdemeID, s.SiparisNo, oy.YontemAdi, od.DurumAdi,
       o.Tutar, o.HataMesaji, o.IslemTarihi
FROM [Odeme].[OdemeIslemleri] o
JOIN [Siparis].[Siparisler] s ON o.SiparisID = s.SiparisID
JOIN [Odeme].[OdemeYontemleri] oy ON o.OdemeYontemID = oy.OdemeYontemID
JOIN [Odeme].[OdemeDurumlari] od ON o.OdemeDurumID = od.OdemeDurumID
WHERE o.HataMesaji IS NOT NULL ORDER BY o.IslemTarihi DESC;""",
        "sqlite": """SELECT o.OdemeID, s.SiparisNo, oy.YontemAdi, od.DurumAdi,
       ROUND(o.Tutar, 2) AS Tutar, o.HataMesaji, o.IslemTarihi
FROM Odeme_OdemeIslemleri o
JOIN Siparis_Siparisler s ON o.SiparisID = s.SiparisID
JOIN Odeme_OdemeYontemleri oy ON o.OdemeYontemID = oy.OdemeYontemID
JOIN Odeme_OdemeDurumlari od ON o.OdemeDurumID = od.OdemeDurumID
WHERE o.HataMesaji IS NOT NULL AND o.HataMesaji != ''
ORDER BY o.IslemTarihi DESC LIMIT 20;""",
    },
    "q17_refunds": {
        "code": "SQLQuery16 & SQLQuery17",
        "category": "Ödeme & İade Finans",
        "title": "İade İşlemleri ve Müşteri İade Nedenleri",
        "description": "Tamamlanan ücret iadelerini, müşteri bilgisini ve iade nedenlerini listeler.",
        "tsql": """SELECT TOP 20 i.IadeID, s.SiparisNo, k.Ad + N' ' + k.Soyad AS Musteri,
       i.IadeTutari, i.IadeDurumu, i.IadeNedeni, i.IadeTarihi
FROM [Odeme].[IadeIslemleri] i
JOIN [Odeme].[OdemeIslemleri] o ON i.OdemeID = o.OdemeID
JOIN [Siparis].[Siparisler] s ON o.SiparisID = s.SiparisID
JOIN [Kimlik].[Kullanicilar] k ON s.KullaniciID = k.KullaniciID
ORDER BY i.IadeTarihi DESC;""",
        "sqlite": """SELECT i.IadeID, s.SiparisNo, k.Ad || ' ' || k.Soyad AS Musteri,
       ROUND(i.IadeTutari, 2) AS IadeTutari, i.IadeDurumu, i.IadeNedeni, i.IadeTarihi
FROM Odeme_IadeIslemleri i
JOIN Odeme_OdemeIslemleri o ON i.OdemeID = o.OdemeID
JOIN Siparis_Siparisler s ON o.SiparisID = s.SiparisID
JOIN Kimlik_Kullanicilar k ON s.KullaniciID = k.KullaniciID
ORDER BY i.IadeTarihi DESC LIMIT 20;""",
    },
    "q19_paid_not_shipped": {
        "code": "SQLQuery18 & SQLQuery19",
        "category": "Kargo & Lojistik",
        "title": "Ödemesi Alınmış Ancak Henüz Kargoya Verilmemiş Siparişler (SLA Uyarı)",
        "description": "Ödeme kaydı bulunan fakat KargoGonderileri tablosunda kaydı olmayan gecikmiş/bekleyen siparişler.",
        "tsql": """SELECT TOP 20 s.SiparisNo, k.Ad + N' ' + k.Soyad AS Musteri,
       o.OdemeID, o.Tutar, o.IslemTarihi
FROM [Siparis].[Siparisler] s
JOIN [Kimlik].[Kullanicilar] k ON s.KullaniciID = k.KullaniciID
JOIN [Odeme].[OdemeIslemleri] o ON s.SiparisID = o.SiparisID
LEFT JOIN [Kargo].[KargoGonderileri] kg ON s.SiparisID = kg.SiparisID
WHERE kg.KargoGonderiID IS NULL ORDER BY o.IslemTarihi DESC;""",
        "sqlite": """SELECT s.SiparisNo, sd.DurumAdi AS SiparisDurumu,
       k.Ad || ' ' || k.Soyad AS Musteri,
       o.OdemeID, ROUND(o.Tutar, 2) AS Tutar, o.IslemTarihi
FROM Siparis_Siparisler s
JOIN Siparis_SiparisDurumlari sd ON s.SiparisDurumID = sd.SiparisDurumID
JOIN Kimlik_Kullanicilar k ON s.KullaniciID = k.KullaniciID
JOIN Odeme_OdemeIslemleri o ON s.SiparisID = o.SiparisID AND o.OdemeDurumID = 1
LEFT JOIN Kargo_KargoGonderileri kg ON s.SiparisID = kg.SiparisID
WHERE kg.KargoGonderiID IS NULL ORDER BY o.IslemTarihi DESC LIMIT 20;""",
    },
    "q22_audit_summary": {
        "code": "SQLQuery22",
        "category": "Merkezi Audit & Mutabakat",
        "title": "Merkezi Denetim (Audit) Olay Türü ve Seviye Dağılımı",
        "description": "DenetimKayitlari tablosundaki olayların tür, kritiklik seviyesi ve başarı/hata oranlarını özetler.",
        "tsql": """SELECT ot.OlayAdi, sv.SeviyeAdi, COUNT(*) AS KayitSayisi,
       SUM(CASE WHEN d.BasariliMi = 1 THEN 1 ELSE 0 END) AS BasariliKayit,
       SUM(CASE WHEN d.BasariliMi = 0 THEN 1 ELSE 0 END) AS BasarisizKayit
FROM [Denetim].[DenetimKayitlari] d
JOIN [Denetim].[OlayTurleri] ot ON d.OlayTurID = ot.OlayTurID
JOIN [Denetim].[Seviyeler] sv ON d.SeviyeID = sv.SeviyeID
GROUP BY ot.OlayAdi, sv.SeviyeAdi ORDER BY KayitSayisi DESC;""",
        "sqlite": """SELECT ot.Kategori, ot.OlayAdi, sv.SeviyeAdi, COUNT(*) AS KayitSayisi,
       SUM(CASE WHEN d.BasariliMi = 1 THEN 1 ELSE 0 END) AS BasariliKayit,
       SUM(CASE WHEN d.BasariliMi = 0 THEN 1 ELSE 0 END) AS BasarisizKayit
FROM Denetim_DenetimKayitlari d
JOIN Denetim_OlayTurleri ot ON d.OlayTurID = ot.OlayTurID
JOIN Denetim_Seviyeler sv ON d.SeviyeID = sv.SeviyeID
GROUP BY ot.Kategori, ot.OlayAdi, sv.SeviyeAdi ORDER BY KayitSayisi DESC;""",
    },
    "q23_reconciliation": {
        "code": "SQLQuery23",
        "category": "Merkezi Audit & Mutabakat",
        "title": "Sipariş AraToplam vs Kalemler Toplamı Tutarsızlık Denetimi (Reconciliation)",
        "description": "Sipariş başlığındaki AraToplam ile kalemlerin SatirToplami toplamı arasında 0.01 TL'den fazla fark olan anomalileri yakalar.",
        "tsql": """SELECT TOP 20 s.SiparisNo, s.AraToplam,
       SUM(sk.SatirToplami) AS KalemlerToplami,
       s.AraToplam - SUM(sk.SatirToplami) AS Fark
FROM [Siparis].[Siparisler] s
JOIN [Siparis].[SiparisKalemleri] sk ON s.SiparisID = sk.SiparisID
GROUP BY s.SiparisNo, s.AraToplam
HAVING ABS(s.AraToplam - SUM(sk.SatirToplami)) > 0.01
ORDER BY ABS(s.AraToplam - SUM(sk.SatirToplami)) DESC;""",
        "sqlite": """SELECT s.SiparisID, s.SiparisNo, ROUND(s.AraToplam, 2) AS AraToplam,
       ROUND(SUM(sk.SatirToplami), 2) AS KalemlerToplami,
       ROUND(s.AraToplam - SUM(sk.SatirToplami), 2) AS Fark
FROM Siparis_Siparisler s
JOIN Siparis_SiparisKalemleri sk ON s.SiparisID = sk.SiparisID
GROUP BY s.SiparisID, s.SiparisNo, s.AraToplam
HAVING ABS(s.AraToplam - SUM(sk.SatirToplami)) > 0.01
ORDER BY ABS(s.AraToplam - SUM(sk.SatirToplami)) DESC;""",
    },
}


class StatusUpdateRequest(BaseModel):
    yeni_durum_id: int
    aciklama: Optional[str] = "Operasyon paneli üzerinden durum güncellendi"


@app.get("/", response_class=HTMLResponse)
def serve_dashboard():
    return TEMPLATE_PATH.read_text(encoding="utf-8")


@app.get("/api/overview")
def get_overview():
    kpi_orders = query_db(
        "SELECT COUNT(*) AS ToplamSiparis, ROUND(SUM(GenelToplam), 2) AS ToplamCiro, ROUND(AVG(GenelToplam), 2) AS OrtalamaSepet FROM Siparis_Siparisler"
    )[0]
    kpi_users = query_db("SELECT COUNT(*) AS ToplamKullanici FROM Kimlik_Kullanicilar")[0]
    kpi_audit = query_db(
        "SELECT COUNT(*) AS ToplamAudit, SUM(CASE WHEN BasariliMi = 0 THEN 1 ELSE 0 END) AS HataliOlaySayisi FROM Denetim_DenetimKayitlari"
    )[0]
    kpi_refunds = query_db(
        "SELECT COUNT(*) AS IadeSayisi, ROUND(COALESCE(SUM(IadeTutari),0), 2) AS ToplamIadeTutari FROM Odeme_IadeIslemleri"
    )[0]

    monthly = query_db(ANALYTICS_CATALOG["q09_monthly_growth"]["sqlite"])
    status_dist = query_db(ANALYTICS_CATALOG["q07_status_revenue"]["sqlite"])
    audit_dist = query_db(ANALYTICS_CATALOG["q22_audit_summary"]["sqlite"])
    services = query_db("SELECT * FROM Kimlik_Servisler ORDER BY ServisID")

    return {
        "kpis": {
            **kpi_orders,
            **kpi_users,
            **kpi_audit,
            **kpi_refunds,
        },
        "monthly_trend": monthly,
        "status_distribution": status_dist,
        "audit_distribution": audit_dist,
        "microservices": services,
    }


@app.get("/api/queries")
def list_queries():
    return [
        {
            "key": k,
            "code": v["code"],
            "category": v["category"],
            "title": v["title"],
            "description": v["description"],
            "tsql": v["tsql"],
        }
        for k, v in ANALYTICS_CATALOG.items()
    ]


@app.get("/api/queries/{query_key}")
def execute_catalog_query(query_key: str):
    if query_key not in ANALYTICS_CATALOG:
        raise HTTPException(status_code=404, detail="Analitik sorgu bulunamadı")
    q = ANALYTICS_CATALOG[query_key]
    rows = query_db(q["sqlite"])
    return {
        "key": query_key,
        "code": q["code"],
        "title": q["title"],
        "description": q["description"],
        "tsql": q["tsql"],
        "row_count": len(rows),
        "rows": rows,
    }


@app.get("/api/orders/{siparis_id}/timeline")
def get_order_timeline(siparis_id: int):
    """SQLQuery20 (Kargo Hareketleri) ve SQLQuery21 (Sipariş Durum Geçmişi) + Audit İzleri"""
    order_rows = query_db(
        """SELECT s.*, k.Ad || ' ' || k.Soyad AS MusteriAdi, k.Eposta,
                  sd.DurumAdi AS MevcutDurum, srv.ServisAdi AS OlusturanServis
           FROM Siparis_Siparisler s
           JOIN Kimlik_Kullanicilar k ON s.KullaniciID = k.KullaniciID
           JOIN Siparis_SiparisDurumlari sd ON s.SiparisDurumID = sd.SiparisDurumID
           JOIN Kimlik_Servisler srv ON s.OlusturanServisID = srv.ServisID
           WHERE s.SiparisID = ?""",
        (siparis_id,),
    )
    if not order_rows:
        raise HTTPException(status_code=404, detail="Sipariş bulunamadı")

    order = order_rows[0]

    # SQLQuery21: Sipariş Durum Geçmişi
    state_history = query_db(
        """SELECT sdg.SiparisDurumGecmisID, s.SiparisNo,
                  COALESCE(es.DurumAdi, 'Başlangıç (Yok)') AS EskiDurum,
                  ys.DurumAdi AS YeniDurum,
                  k.KullaniciAdi AS DegistirenKullanici,
                  sdg.DegisimTarihi, sdg.Aciklama
           FROM Siparis_SiparisDurumGecmisi sdg
           JOIN Siparis_Siparisler s ON sdg.SiparisID = s.SiparisID
           LEFT JOIN Siparis_SiparisDurumlari es ON sdg.EskiSiparisDurumID = es.SiparisDurumID
           JOIN Siparis_SiparisDurumlari ys ON sdg.YeniSiparisDurumID = ys.SiparisDurumID
           LEFT JOIN Kimlik_Kullanicilar k ON sdg.DegistirenKullaniciID = k.KullaniciID
           WHERE sdg.SiparisID = ?
           ORDER BY sdg.DegisimTarihi""",
        (siparis_id,),
    )

    # SQLQuery20: Kargo Hareketleri
    cargo_movements = query_db(
        """SELECT s.SiparisNo, kf.FirmaAdi, kg.TakipNo, kd.DurumAdi,
                  kh.Lokasyon, kh.Aciklama, kh.HareketTarihi
           FROM Siparis_Siparisler s
           JOIN Kargo_KargoGonderileri kg ON s.SiparisID = kg.SiparisID
           JOIN Kargo_KargoFirmalari kf ON kg.KargoFirmaID = kf.KargoFirmaID
           JOIN Kargo_KargoHareketleri kh ON kg.KargoGonderiID = kh.KargoGonderiID
           JOIN Kargo_KargoDurumlari kd ON kh.KargoDurumID = kd.KargoDurumID
           WHERE s.SiparisID = ?
           ORDER BY kh.HareketTarihi""",
        (siparis_id,),
    )

    items = query_db(
        "SELECT * FROM Siparis_SiparisKalemleri WHERE SiparisID = ?",
        (siparis_id,),
    )

    audits = query_db(
        """SELECT d.DenetimID, srv.ServisKodu, ot.OlayAdi, sv.SeviyeKodu,
                  d.VarlikTipi, d.VarlikID, d.KorelasyonID, d.IpAdresi,
                  d.BasariliMi, d.Mesaj, d.DetayJson, d.OlusturmaTarihi
           FROM Denetim_DenetimKayitlari d
           JOIN Kimlik_Servisler srv ON d.ServisID = srv.ServisID
           JOIN Denetim_OlayTurleri ot ON d.OlayTurID = ot.OlayTurID
           JOIN Denetim_Seviyeler sv ON d.SeviyeID = sv.SeviyeID
           WHERE d.VarlikID = ?
           ORDER BY d.OlusturmaTarihi DESC""",
        (order["SiparisNo"],),
    )

    return {
        "order": order,
        "items": items,
        "state_history": state_history,
        "cargo_movements": cargo_movements,
        "audit_logs": audits,
    }


@app.post("/api/orders/{siparis_id}/status")
def simulate_status_transition_trigger(siparis_id: int, req: StatusUpdateRequest):
    """
    03_triggers_and_procedures.sql içerisindeki [Siparis].[trg_Siparisler_DurumVeAudit]
    trigger davranışını canlı simüle eder:
    1. Sipariş durumunu günceller
    2. SiparisDurumGecmisi tablosuna eski/yeni durum kaydı ekler
    3. DenetimKayitlari tablosuna otomatik KorelasyonID'li merkezi audit kaydı düşer
    """
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    cur.execute("SELECT * FROM Siparis_Siparisler WHERE SiparisID = ?", (siparis_id,))
    order = cur.fetchone()
    if not order:
        conn.close()
        raise HTTPException(status_code=404, detail="Sipariş bulunamadı")

    eski_durum_id = order["SiparisDurumID"]
    yeni_durum_id = req.yeni_durum_id
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    cur.execute(
        "UPDATE Siparis_Siparisler SET SiparisDurumID = ? WHERE SiparisID = ?",
        (yeni_durum_id, siparis_id),
    )

    cur.execute("SELECT COALESCE(MAX(SiparisDurumGecmisID), 0) + 1 FROM Siparis_SiparisDurumGecmisi")
    next_hist_id = cur.fetchone()[0]
    cur.execute(
        """INSERT INTO Siparis_SiparisDurumGecmisi
           (SiparisDurumGecmisID, SiparisID, EskiSiparisDurumID, YeniSiparisDurumID, DegistirenKullaniciID, DegisimTarihi, Aciklama)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (next_hist_id, siparis_id, eski_durum_id, yeni_durum_id, order["KullaniciID"], now_str, req.aciklama),
    )

    cur.execute("SELECT COALESCE(MAX(DenetimID), 0) + 1 FROM Denetim_DenetimKayitlari")
    next_audit_id = cur.fetchone()[0]
    korelasyon_id = str(uuid.uuid4())
    detay_json = json.dumps(
        {
            "Trigger": "Siparis.trg_Siparisler_DurumVeAudit",
            "SiparisNo": order["SiparisNo"],
            "EskiDurumID": eski_durum_id,
            "YeniDurumID": yeni_durum_id,
        },
        ensure_ascii=False,
    )
    cur.execute(
        """INSERT INTO Denetim_DenetimKayitlari
           (DenetimID, ServisID, OlayTurID, SeviyeID, KullaniciID, VarlikTipi, VarlikID,
            KorelasyonID, IpAdresi, BasariliMi, Mesaj, DetayJson, OlusturmaTarihi)
           VALUES (?, 3, 3, 1, ?, 'Siparis', ?, ?, '10.0.0.10', 1, ?, ?, ?)""",
        (
            next_audit_id,
            order["KullaniciID"],
            order["SiparisNo"],
            korelasyon_id,
            f"Otomatik Trigger Audit: Sipariş ({order['SiparisNo']}) durumu {eski_durum_id} -> {yeni_durum_id} olarak güncellendi.",
            detay_json,
            now_str,
        ),
    )

    conn.commit()
    conn.close()
    return {
        "status": "ok",
        "message": "Sipariş durumu güncellendi; Durum Geçmişi ve Merkezi Audit Trigger kaydı otomatik oluşturuldu.",
        "korelasyon_id": korelasyon_id,
    }


@app.get("/api/audit-logs")
def get_recent_audit_logs(limit: int = Query(30, ge=1, le=200), seviye: Optional[str] = None):
    sql = """SELECT d.DenetimID, srv.ServisKodu, srv.ServisAdi,
                    ot.Kategori, ot.OlayKodu, ot.OlayAdi,
                    sv.SeviyeKodu, sv.SeviyeAdi,
                    d.VarlikTipi, d.VarlikID, d.KorelasyonID,
                    d.IpAdresi, d.BasariliMi, d.Mesaj, d.DetayJson, d.OlusturmaTarihi
             FROM Denetim_DenetimKayitlari d
             JOIN Kimlik_Servisler srv ON d.ServisID = srv.ServisID
             JOIN Denetim_OlayTurleri ot ON d.OlayTurID = ot.OlayTurID
             JOIN Denetim_Seviyeler sv ON d.SeviyeID = sv.SeviyeID"""
    params = []
    if seviye:
        sql += " WHERE sv.SeviyeKodu = ?"
        params.append(seviye)
    sql += " ORDER BY d.DenetimID DESC LIMIT ?"
    params.append(limit)
    return query_db(sql, tuple(params))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)

