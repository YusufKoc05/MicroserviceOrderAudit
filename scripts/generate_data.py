"""
Mikroservis Sipariş ve Merkezi Audit Sistemi - Veri Üretici (Data Generator)
=============================================================================
Bu script:
1. MSSQL `04_csv_bulk_import.sql` scriptinin beklediği 20 adet CSV dosyasını
   `data/csv/` klasörüne UTF-8 formatında ve referans bütünlüğüne uygun üretir.
2. Aynı verileri kullanarak Python FastAPI + Analitik Dashboard uygulamasının
   anında çalışabilmesi için `data/merkezi_audit_siparis.db` SQLite veritabanını
   oluşturur ve doldurur.
"""

import csv
import json
import os
import random
import sqlite3
import uuid
from datetime import datetime, timedelta
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
CSV_DIR = BASE_DIR / "data" / "csv"
SQLITE_PATH = BASE_DIR / "data" / "merkezi_audit_siparis.db"

random.seed(42)


def generate_datasets():
    # 1. Kimlik_Roller
    roller = [
        {"RolID": 1, "RolAdi": "Musteri", "Aciklama": "Standart e-ticaret müşterisi"},
        {"RolID": 2, "RolAdi": "VIP_Musteri", "Aciklama": "Yüksek hacimli kurumsal/bireysel müşteri"},
        {"RolID": 3, "RolAdi": "Operasyon_Uzmani", "Aciklama": "Sipariş ve kargo operasyon yetkilisi"},
        {"RolID": 4, "RolAdi": "Finans_Denetcisi", "Aciklama": "Ödeme, iade ve mutabakat denetçisi"},
        {"RolID": 5, "RolAdi": "Sistem_Yoneticisi", "Aciklama": "Mikroservis ve merkezi audit yöneticisi"},
    ]

    # 2. Kimlik_Servisler
    servisler = [
        {"ServisID": 1, "ServisKodu": "API-GW", "ServisAdi": "API Gateway Servisi", "Surum": "v2.4.0", "AktifMi": 1},
        {"ServisID": 2, "ServisKodu": "IDENTITY-SVC", "ServisAdi": "Kimlik ve Yetkilendirme Servisi", "Surum": "v1.8.2", "AktifMi": 1},
        {"ServisID": 3, "ServisKodu": "ORDER-SVC", "ServisAdi": "Sipariş Yönetim Mikroservisi", "Surum": "v3.1.0", "AktifMi": 1},
        {"ServisID": 4, "ServisKodu": "PAYMENT-SVC", "ServisAdi": "Ödeme ve İade Mikroservisi", "Surum": "v2.5.1", "AktifMi": 1},
        {"ServisID": 5, "ServisKodu": "CARGO-SVC", "ServisAdi": "Kargo ve Lojistik Mikroservisi", "Surum": "v1.9.4", "AktifMi": 1},
        {"ServisID": 6, "ServisKodu": "AUDIT-SVC", "ServisAdi": "Merkezi Denetim ve İzleme Servisi", "Surum": "v2.0.0", "AktifMi": 1},
    ]

    # 3. Siparis_SiparisDurumlari
    siparis_durumlari = [
        {"SiparisDurumID": 1, "DurumKodu": "CREATED", "DurumAdi": "Sipariş Oluşturuldu", "Aciklama": "Sipariş alındı, ödeme bekleniyor"},
        {"SiparisDurumID": 2, "DurumKodu": "PAYMENT_APPROVED", "DurumAdi": "Ödeme Onaylandı", "Aciklama": "Ödeme başarıyla tahsil edildi"},
        {"SiparisDurumID": 3, "DurumKodu": "PREPARING", "DurumAdi": "Hazırlanıyor", "Aciklama": "Depoda paketleme aşamasında"},
        {"SiparisDurumID": 4, "DurumKodu": "SHIPPED", "DurumAdi": "Kargoya Verildi", "Aciklama": "Kargo firmasına teslim edildi"},
        {"SiparisDurumID": 5, "DurumKodu": "DELIVERED", "DurumAdi": "Teslim Edildi", "Aciklama": "Müşteriye başarıyla teslim edildi"},
        {"SiparisDurumID": 6, "DurumKodu": "CANCELLED", "DurumAdi": "İptal Edildi", "Aciklama": "Sipariş iptal edildi"},
        {"SiparisDurumID": 7, "DurumKodu": "REFUNDED", "DurumAdi": "İade Edildi", "Aciklama": "Ücret iadesi tamamlandı"},
    ]

    # 4. Odeme_OdemeYontemleri
    odeme_yontemleri = [
        {"OdemeYontemID": 1, "YontemKodu": "CREDIT_CARD", "YontemAdi": "Kredi Kartı (3D Secure)", "AktifMi": 1},
        {"OdemeYontemID": 2, "YontemKodu": "DEBIT_CARD", "YontemAdi": "Banka Kartı", "AktifMi": 1},
        {"OdemeYontemID": 3, "YontemKodu": "WIRE_EFT", "YontemAdi": "Havale / FAST / EFT", "AktifMi": 1},
        {"OdemeYontemID": 4, "YontemKodu": "DIGITAL_WALLET", "YontemAdi": "Dijital Cüzdan", "AktifMi": 1},
    ]

    # 5. Odeme_OdemeDurumlari
    odeme_durumlari = [
        {"OdemeDurumID": 1, "DurumKodu": "SUCCESS", "DurumAdi": "Başarılı"},
        {"OdemeDurumID": 2, "DurumKodu": "PENDING", "DurumAdi": "Beklemede"},
        {"OdemeDurumID": 3, "DurumKodu": "FAILED", "DurumAdi": "Başarısız"},
        {"OdemeDurumID": 4, "DurumKodu": "REFUNDED", "DurumAdi": "İade Edildi"},
    ]

    # 6. Kargo_KargoDurumlari
    kargo_durumlari = [
        {"KargoDurumID": 1, "DurumKodu": "BARCODE_CREATED", "DurumAdi": "Barkod Oluşturuldu"},
        {"KargoDurumID": 2, "DurumKodu": "IN_TRANSIT", "DurumAdi": "Transfer Merkezinde"},
        {"KargoDurumID": 3, "DurumKodu": "OUT_FOR_DELIVERY", "DurumAdi": "Daophyımda (Kuryede)"},
        {"KargoDurumID": 4, "DurumKodu": "DELIVERED", "DurumAdi": "Teslim Edildi"},
        {"KargoDurumID": 5, "DurumKodu": "RETURNED_TO_SENDER", "DurumAdi": "Göndericiye İade"},
    ]
    kargo_durumlari[2]["DurumAdi"] = "Dağıtımda (Kuryede)"

    # 7. Kargo_KargoFirmalari
    kargo_firmalari = [
        {"KargoFirmaID": 1, "FirmaKodu": "YURTICI", "FirmaAdi": "Yurtiçi Kargo", "AktifMi": 1},
        {"KargoFirmaID": 2, "FirmaKodu": "ARAS", "FirmaAdi": "Aras Kargo", "AktifMi": 1},
        {"KargoFirmaID": 3, "FirmaKodu": "MNG", "FirmaAdi": "MNG Kargo (DHL)", "AktifMi": 1},
        {"KargoFirmaID": 4, "FirmaKodu": "HEPSIJET", "FirmaAdi": "HepsiJet Ekspres", "AktifMi": 1},
    ]

    # 8. Denetim_OlayTurleri
    olay_turleri = [
        {"OlayTurID": 1, "OlayKodu": "USER_LOGIN", "OlayAdi": "Kullanıcı Girişi", "Kategori": "Kimlik"},
        {"OlayTurID": 2, "OlayKodu": "ORDER_CREATED", "OlayAdi": "Yeni Sipariş Oluşturuldu", "Kategori": "Siparis"},
        {"OlayTurID": 3, "OlayKodu": "ORDER_STATUS_CHANGED", "OlayAdi": "Sipariş Durumu Değişti", "Kategori": "Siparis"},
        {"OlayTurID": 4, "OlayKodu": "PAYMENT_PROCESSED", "OlayAdi": "Ödeme İşlemi Gerçekleşti", "Kategori": "Odeme"},
        {"OlayTurID": 5, "OlayKodu": "PAYMENT_FAILED", "OlayAdi": "Ödeme Hatası Alındı", "Kategori": "Odeme"},
        {"OlayTurID": 6, "OlayKodu": "REFUND_ISSUED", "OlayAdi": "İade İşlemi Başlatıldı", "Kategori": "Odeme"},
        {"OlayTurID": 7, "OlayKodu": "SHIPMENT_DISPATCHED", "OlayAdi": "Kargo Çıkışı Yapıldı", "Kategori": "Kargo"},
        {"OlayTurID": 8, "OlayKodu": "SHIPMENT_DELIVERED", "OlayAdi": "Kargo Teslim Edildi", "Kategori": "Kargo"},
        {"OlayTurID": 9, "OlayKodu": "DATA_RECONCILIATION_WARN", "OlayAdi": "Finansal Mutabakat Uyarısı", "Kategori": "Denetim"},
    ]

    # 9. Denetim_Seviyeler
    seviyeler = [
        {"SeviyeID": 1, "SeviyeKodu": "INFO", "SeviyeAdi": "Bilgi (INFO)", "OncelikSirasi": 1},
        {"SeviyeID": 2, "SeviyeKodu": "WARN", "SeviyeAdi": "Uyarı (WARN)", "OncelikSirasi": 2},
        {"SeviyeID": 3, "SeviyeKodu": "ERROR", "SeviyeAdi": "Hata (ERROR)", "OncelikSirasi": 3},
        {"SeviyeID": 4, "SeviyeKodu": "CRITICAL", "SeviyeAdi": "Kritik (CRITICAL)", "OncelikSirasi": 4},
        {"SeviyeID": 5, "SeviyeKodu": "SECURITY", "SeviyeAdi": "Güvenlik (SECURITY)", "OncelikSirasi": 5},
    ]

    # 10. Kimlik_Kullanicilar (60 kullanıcı, son 10 tanesi hiç sipariş vermemiş olsun -> SQLQuery13 için)
    adlar = ["Yusuf", "Ahmet", "Mehmet", "Ayşe", "Fatma", "Zeynep", "Elif", "Burak", "Emre", "Can", "Selin", "Deniz", "Merve", "Kaan", "Ece"]
    soyadlar = ["Koç", "Yılmaz", "Kaya", "Demir", "Çelik", "Şahin", "Yıldız", "Öztürk", "Aydın", "Özdemir", "Arslan", "Doğan", "Kılıç", "Aslan", "Çetin"]
    sehirler = [
        ("İstanbul", ["Kadıköy", "Beşiktaş", "Üsküdar", "Şişli", "Ataşehir"]),
        ("Ankara", ["Çankaya", "Yenimahalle", "Keçiören", "Gölbaşı"]),
        ("İzmir", ["Karşıyaka", "Bornova", "Konak", "Buca"]),
        ("Bursa", ["Nilüfer", "Osmangazi"]),
        ("Antalya", ["Muratpaşa", "Konyaaltı"]),
    ]

    kullanicilar = []
    adresler = []
    kullanici_rolleri = []
    adres_id_counter = 1
    rol_id_counter = 1

    base_date = datetime(2025, 1, 10, 9, 0, 0)

    for uid in range(1, 61):
        ad = adlar[uid % len(adlar)]
        soyad = soyadlar[(uid * 3) % len(soyadlar)]
        if uid == 1:
            ad, soyad = "Yusuf", "Koç"
        kullanici_adi = f"{ad.lower().replace('ş','s').replace('ç','c').replace('ğ','g').replace('ı','i').replace('ö','o').replace('ü','u')}.{soyad.lower().replace('ş','s').replace('ç','c').replace('ğ','g').replace('ı','i').replace('ö','o').replace('ü','u')}{uid}"
        eposta = f"{kullanici_adi}@example.com"
        kayit_tarihi = (base_date + timedelta(days=uid * 2, hours=uid % 12)).strftime("%Y-%m-%d %H:%M:%S")

        kullanicilar.append({
            "KullaniciID": uid,
            "KullaniciAdi": kullanici_adi,
            "Ad": ad,
            "Soyad": soyad,
            "Eposta": eposta,
            "Telefon": f"+9053{random.randint(20000000, 99999999)}",
            "AktifMi": 1,
            "KayitTarihi": kayit_tarihi,
        })

        sehir, ilceler = random.choice(sehirler)
        ilce = random.choice(ilceler)
        adresler.append({
            "AdresID": adres_id_counter,
            "KullaniciID": uid,
            "AdresBasligi": "Ev Adresi",
            "Sehir": sehir,
            "Ilce": ilce,
            "PostaKodu": f"{random.randint(10, 81)}000",
            "AcikAdres": f"{ilce} Mah. Atatürk Cad. No:{random.randint(1, 120)} D:{random.randint(1, 20)}",
            "VarsayilanMi": 1,
        })
        adres_id_counter += 1

        kullanici_rolleri.append({
            "KullaniciRolID": rol_id_counter,
            "KullaniciID": uid,
            "RolID": 2 if uid <= 10 else 1,
            "AtanmaTarihi": kayit_tarihi,
        })
        rol_id_counter += 1

    # Ürün Kataloğu
    urun_katalogu = [
        ("PRD-LAPTOP-01", "ProBook Ultra 16GB RAM 1TB SSD Laptop", 34500.00),
        ("PRD-MON-02", "27 inç 4K IPS 144Hz Oyuncu Monitörü", 12800.00),
        ("PRD-KB-03", "Mekanik RGB Kablosuz Klavye", 2450.00),
        ("PRD-MSE-04", "Ergonomik Kablosuz Lazer Mouse", 1350.00),
        ("PRD-HDP-05", "ANC Aktif Gürültü Engelleyici Kulaklık", 4900.00),
        ("PRD-SSD-06", "2TB NVMe PCIe 4.0 M.2 Harici SSD", 5600.00),
        ("PRD-DOC-07", "USB-C Thunderbolt 12-in-1 Docking Station", 3200.00),
        ("PRD-CAM-08", "4K Ultra HD Otomatik Odaklı Webcam", 2850.00),
        ("PRD-CHR-09", "100W GaN Hızlı Şarj Adaptörü", 1450.00),
        ("PRD-TAB-10", "11 inç 256GB Wi-Fi Grafik Tablet", 18900.00),
        ("PRD-MIC-11", "Stüdyo Tipi USB Kondenser Mikrofon", 3750.00),
        ("PRD-RTR-12", "Wi-Fi 6E Mesh Gigabit Router", 4200.00),
    ]

    siparisler = []
    siparis_kalemleri = []
    siparis_durum_gecmisi = []
    odeme_islemleri = []
    iade_islemleri = []
    kargo_gonderileri = []
    kargo_hareketleri = []
    denetim_kayitlari = []

    kalem_id = 1
    gecmis_id = 1
    odeme_id = 1
    iade_id = 1
    kargo_id = 1
    hareket_id = 1
    denetim_id = 1

    start_order_date = datetime(2025, 6, 1, 10, 0, 0)

    # 180 adet zengin sipariş oluştur (İlk 50 aktif müşteri arasında; 51-60 arası pasif kalır -> SQLQuery13)
    for sid in range(1, 181):
        uid = random.randint(1, 50)
        order_dt = start_order_date + timedelta(days=int(sid * 1.8), hours=random.randint(0, 22), minutes=random.randint(0, 59))
        order_dt_str = order_dt.strftime("%Y-%m-%d %H:%M:%S")
        siparis_no = f"SIP-{order_dt.strftime('%Y%m')}-{sid:05d}"
        korelasyon_id = str(uuid.uuid4())

        # Kalemleri oluştur (1 ila 4 kalem)
        secilen_urunler = random.sample(urun_katalogu, k=random.randint(1, 4))
        kalem_toplami = 0.0
        for ukod, uad, bfiyat in secilen_urunler:
            miktar = random.randint(1, 3)
            indirim = round(bfiyat * miktar * (0.05 if miktar > 1 else 0.0), 2)
            satir_top = round(bfiyat * miktar - indirim, 2)
            kalem_toplami = round(kalem_toplami + satir_top, 2)
            siparis_kalemleri.append({
                "SiparisKalemID": kalem_id,
                "SiparisID": sid,
                "UrunKodu": ukod,
                "UrunAdi": uad,
                "Miktar": miktar,
                "BirimFiyat": f"{bfiyat:.2f}",
                "IndirimTutari": f"{indirim:.2f}",
                "SatirToplami": f"{satir_top:.2f}",
            })
            kalem_id += 1

        # SQLQuery23 (Mutabakat / Reconciliation testi) için 4 siparişte kasıtlı küçük kuruş/indirim farkı bırakalım
        ara_toplam = kalem_toplami
        if sid in (17, 48, 95, 142):
            ara_toplam = round(kalem_toplami + random.choice([-45.50, 75.25, -120.00, 32.80]), 2)

        vergi = round(ara_toplam * 0.20, 2)
        kargo_tutari = 0.00 if ara_toplam >= 5000 else 149.90
        genel_toplam = round(ara_toplam + vergi + kargo_tutari, 2)

        # Sipariş durum dağılımı
        if sid % 15 == 0:
            durum_id = 6  # İptal Edildi
        elif sid % 12 == 0:
            durum_id = 7  # İade Edildi
        elif sid % 9 == 0:
            durum_id = 2  # Ödeme Onaylandı (Henüz kargoya verilmemiş -> SQLQuery19 için!)
        elif sid % 7 == 0:
            durum_id = 4  # Kargoya Verildi
        else:
            durum_id = 5  # Teslim Edildi

        olusturan_servis_id = 3  # ORDER-SVC

        siparisler.append({
            "SiparisID": sid,
            "SiparisNo": siparis_no,
            "KullaniciID": uid,
            "TeslimatAdresID": uid,
            "SiparisDurumID": durum_id,
            "OlusturanServisID": olusturan_servis_id,
            "AraToplam": f"{ara_toplam:.2f}",
            "VergiTutari": f"{vergi:.2f}",
            "KargoTutari": f"{kargo_tutari:.2f}",
            "GenelToplam": f"{genel_toplam:.2f}",
            "ParaBirimi": "TRY",
            "SiparisTarihi": order_dt_str,
        })

        # Sipariş Durum Geçmişi
        adimlar = [
            (None, 1, order_dt, "Sipariş müşteri tarafından oluşturuldu."),
            (1, 2, order_dt + timedelta(minutes=2), "Ödeme servisi onayı alındı."),
        ]
        if durum_id in (4, 5, 7):
            adimlar.append((2, 3, order_dt + timedelta(hours=3), "Depo hazırlık süreci başladı."))
            adimlar.append((3, 4, order_dt + timedelta(hours=10), "Kargo firmasına çıkış yapıldı."))
        if durum_id in (5, 7):
            adimlar.append((4, 5, order_dt + timedelta(days=2), "Müşteriye teslim edildi."))
        if durum_id == 6:
            adimlar.append((2, 6, order_dt + timedelta(hours=1), "Müşteri talebiyle iptal edildi."))
        if durum_id == 7:
            adimlar.append((5, 7, order_dt + timedelta(days=5), "İade incelendi ve ücret iadesi onaylandı."))

        for eski_d, yeni_d, dt_step, aciklama in adimlar:
            siparis_durum_gecmisi.append({
                "SiparisDurumGecmisID": gecmis_id,
                "SiparisID": sid,
                "EskiSiparisDurumID": "" if eski_d is None else eski_d,
                "YeniSiparisDurumID": yeni_d,
                "DegistirenKullaniciID": uid,
                "DegisimTarihi": dt_step.strftime("%Y-%m-%d %H:%M:%S"),
                "Aciklama": aciklama,
            })
            gecmis_id += 1

        # Audit: ORDER_CREATED
        denetim_kayitlari.append({
            "DenetimID": denetim_id,
            "ServisID": 3,
            "OlayTurID": 2,
            "SeviyeID": 1,
            "KullaniciID": uid,
            "VarlikTipi": "Siparis",
            "VarlikID": siparis_no,
            "KorelasyonID": korelasyon_id,
            "IpAdresi": f"192.168.1.{random.randint(10, 250)}",
            "BasariliMi": 1,
            "Mesaj": f"Sipariş başarıyla oluşturuldu ({siparis_no})",
            "DetayJson": json.dumps({"SiparisNo": siparis_no, "GenelToplam": genel_toplam}, ensure_ascii=False),
            "OlusturmaTarihi": order_dt_str,
        })
        denetim_id += 1

        # Eğer tutarsızlık varsa Audit WARN kaydı da düş (SQLQuery22 & SQLQuery23 bağlantısı)
        if sid in (17, 48, 95, 142):
            denetim_kayitlari.append({
                "DenetimID": denetim_id,
                "ServisID": 6,
                "OlayTurID": 9,
                "SeviyeID": 2,
                "KullaniciID": uid,
                "VarlikTipi": "Siparis",
                "VarlikID": siparis_no,
                "KorelasyonID": korelasyon_id,
                "IpAdresi": "10.0.0.60",
                "BasariliMi": 0,
                "Mesaj": f"Sipariş ara toplamı ile kalem toplamı arasında fark tespit edildi: {siparis_no}",
                "DetayJson": json.dumps({"AraToplam": ara_toplam, "KalemlerToplami": kalem_toplami}, ensure_ascii=False),
                "OlusturmaTarihi": (order_dt + timedelta(minutes=5)).strftime("%Y-%m-%d %H:%M:%S"),
            })
            denetim_id += 1

        # Ödeme İşlemleri (Bazı siparişlerde ilk deneme başarısız olsun -> SQLQuery15 için!)
        yontem_id = random.randint(1, 4)
        if sid % 11 == 0:
            hata_mesaji = random.choice([
                "ERR_INSUFFICIENT_FUNDS: Kart bakiyesi yetersiz",
                "ERR_3DS_TIMEOUT: 3D Secure doğrulama süresi doldu",
                "ERR_BANK_DECLINED: Banka tarafından işlem reddedildi (Kod: 05)",
                "ERR_DAILY_LIMIT: Günlük internet alışveriş limiti aşıldı",
            ])
            odeme_islemleri.append({
                "OdemeID": odeme_id,
                "SiparisID": sid,
                "OdemeYontemID": yontem_id,
                "OdemeDurumID": 3,  # Başarısız
                "Tutar": f"{genel_toplam:.2f}",
                "ParaBirimi": "TRY",
                "SaglayiciRefNo": f"PAY-ERR-{odeme_id:06d}",
                "HataMesaji": hata_mesaji,
                "IslemTarihi": (order_dt + timedelta(seconds=45)).strftime("%Y-%m-%d %H:%M:%S"),
            })
            odeme_id += 1

            denetim_kayitlari.append({
                "DenetimID": denetim_id,
                "ServisID": 4,
                "OlayTurID": 5,
                "SeviyeID": 3,
                "KullaniciID": uid,
                "VarlikTipi": "Odeme",
                "VarlikID": siparis_no,
                "KorelasyonID": korelasyon_id,
                "IpAdresi": f"192.168.1.{random.randint(10, 250)}",
                "BasariliMi": 0,
                "Mesaj": f"Ödeme tahsilatı başarısız oldu: {hata_mesaji}",
                "DetayJson": json.dumps({"Hata": hata_mesaji, "Tutar": genel_toplam}, ensure_ascii=False),
                "OlusturmaTarihi": (order_dt + timedelta(seconds=46)).strftime("%Y-%m-%d %H:%M:%S"),
            })
            denetim_id += 1

        # Başarılı ödeme kaydı
        basarili_odeme_id = odeme_id
        odeme_durum = 4 if durum_id == 7 else 1
        odeme_islemleri.append({
            "OdemeID": basarili_odeme_id,
            "SiparisID": sid,
            "OdemeYontemID": yontem_id,
            "OdemeDurumID": odeme_durum,
            "Tutar": f"{genel_toplam:.2f}",
            "ParaBirimi": "TRY",
            "SaglayiciRefNo": f"PAY-OK-{basarili_odeme_id:06d}",
            "HataMesaji": None,
            "IslemTarihi": (order_dt + timedelta(minutes=2)).strftime("%Y-%m-%d %H:%M:%S"),
        })
        odeme_id += 1

        denetim_kayitlari.append({
            "DenetimID": denetim_id,
            "ServisID": 4,
            "OlayTurID": 4,
            "SeviyeID": 1,
            "KullaniciID": uid,
            "VarlikTipi": "Odeme",
            "VarlikID": f"PAY-OK-{basarili_odeme_id:06d}",
            "KorelasyonID": korelasyon_id,
            "IpAdresi": "10.0.0.40",
            "BasariliMi": 1,
            "Mesaj": f"Ödeme başarıyla tahsil edildi ({genel_toplam:.2f} TRY)",
            "DetayJson": json.dumps({"OdemeID": basarili_odeme_id, "SiparisNo": siparis_no}, ensure_ascii=False),
            "OlusturmaTarihi": (order_dt + timedelta(minutes=2)).strftime("%Y-%m-%d %H:%M:%S"),
        })
        denetim_id += 1

        # İade İşlemleri (Durum 7 veya 6 olanların bir kısmı -> SQLQuery16 ve SQLQuery17 için)
        if durum_id in (6, 7):
            iade_nedenleri = [
                "Müşteri cayma hakkı kapsamında iade talep etti",
                "Ürün kargo sürecinde hasar gördü",
                "Yanlış model/özellik seçimi nedeniyle değişim/iade",
                "Sipariş kargolanmadan önce müşteri tarafından iptal edildi",
            ]
            iade_tutari = genel_toplam if durum_id == 6 else round(genel_toplam * random.choice([1.0, 0.5]), 2)
            iade_dt = (order_dt + timedelta(days=4)).strftime("%Y-%m-%d %H:%M:%S")
            iade_islemleri.append({
                "IadeID": iade_id,
                "OdemeID": basarili_odeme_id,
                "IadeTutari": f"{iade_tutari:.2f}",
                "IadeDurumu": "Tamamlandı",
                "IadeNedeni": random.choice(iade_nedenleri),
                "IadeTarihi": iade_dt,
            })
            iade_id += 1

            denetim_kayitlari.append({
                "DenetimID": denetim_id,
                "ServisID": 4,
                "OlayTurID": 6,
                "SeviyeID": 2,
                "KullaniciID": uid,
                "VarlikTipi": "Iade",
                "VarlikID": siparis_no,
                "KorelasyonID": korelasyon_id,
                "IpAdresi": "10.0.0.40",
                "BasariliMi": 1,
                "Mesaj": f"Sipariş için {iade_tutari:.2f} TRY tutarında iade gerçekleştirildi",
                "DetayJson": json.dumps({"SiparisNo": siparis_no, "IadeTutari": iade_tutari}, ensure_ascii=False),
                "OlusturmaTarihi": iade_dt,
            })
            denetim_id += 1

        # Kargo Gönderileri (Durum 4, 5, 7 olanlar kargolanmış; Durum 2 ve 6 olanlar kargolanmamış -> SQLQuery19)
        if durum_id in (4, 5, 7):
            firma_id = random.randint(1, 4)
            kargo_durum_id = 4 if durum_id in (5, 7) else random.choice([2, 3])
            verilis_dt = order_dt + timedelta(hours=10)
            teslim_dt = (order_dt + timedelta(days=2, hours=4)) if kargo_durum_id == 4 else None
            takip_no = f"TRK-{order_dt.strftime('%Y')}-{kargo_id:07d}"
            gonderi_ucreti = round(random.uniform(65.0, 185.0), 2)

            kargo_gonderileri.append({
                "KargoGonderiID": kargo_id,
                "SiparisID": sid,
                "KargoFirmaID": firma_id,
                "KargoDurumID": kargo_durum_id,
                "TakipNo": takip_no,
                "GonderiUcreti": f"{gonderi_ucreti:.2f}",
                "KargoyaVerilisTarihi": verilis_dt.strftime("%Y-%m-%d %H:%M:%S"),
                "TeslimTarihi": teslim_dt.strftime("%Y-%m-%d %H:%M:%S") if teslim_dt else "",
            })

            # Kargo Hareketleri (SQLQuery20 için özellikle SiparisID = 1 dahil tüm kargolara adım adım hareket)
            hareket_adimlari = [
                (1, "İstanbul Tuzla Lojistik Merkezi", "Gönderi barkodu oluşturuldu ve çıkış şubesinden teslim alındı", verilis_dt),
                (2, "İstanbul Anadolu Transfer Merkezi", "Transfer merkezinde ayrıştırma işlemi tamamlandı", verilis_dt + timedelta(hours=8)),
            ]
            if kargo_durum_id in (3, 4):
                hareket_adimlari.append((3, "Varış Şubesi Dağıtım Merkezi", "Kurye dağıtıma çıkardı", verilis_dt + timedelta(days=1, hours=6)))
            if kargo_durum_id == 4:
                hareket_adimlari.append((4, "Alıcı Teslimat Adresi", "Alıcıya kimlik/kod doğrulaması ile teslim edildi", teslim_dt))

            for kd_id, lokasyon, kh_aciklama, kh_dt in hareket_adimlari:
                kargo_hareketleri.append({
                    "KargoHareketID": hareket_id,
                    "KargoGonderiID": kargo_id,
                    "KargoDurumID": kd_id,
                    "Lokasyon": lokasyon,
                    "Aciklama": kh_aciklama,
                    "HareketTarihi": kh_dt.strftime("%Y-%m-%d %H:%M:%S"),
                })
                hareket_id += 1

            denetim_kayitlari.append({
                "DenetimID": denetim_id,
                "ServisID": 5,
                "OlayTurID": 8 if kargo_durum_id == 4 else 7,
                "SeviyeID": 1,
                "KullaniciID": uid,
                "VarlikTipi": "Kargo",
                "VarlikID": takip_no,
                "KorelasyonID": korelasyon_id,
                "IpAdresi": "10.0.0.50",
                "BasariliMi": 1,
                "Mesaj": f"Kargo durumu güncellendi: {takip_no}",
                "DetayJson": json.dumps({"TakipNo": takip_no, "SiparisNo": siparis_no, "KargoDurumID": kargo_durum_id}, ensure_ascii=False),
                "OlusturmaTarihi": (teslim_dt or verilis_dt).strftime("%Y-%m-%d %H:%M:%S"),
            })
            denetim_id += 1
            kargo_id += 1

    return {
        "Kimlik_Kullanicilar": kullanicilar,
        "Kimlik_Roller": roller,
        "Kimlik_Servisler": servisler,
        "Siparis_SiparisDurumlari": siparis_durumlari,
        "Odeme_OdemeYontemleri": odeme_yontemleri,
        "Odeme_OdemeDurumlari": odeme_durumlari,
        "Kargo_KargoDurumlari": kargo_durumlari,
        "Kargo_KargoFirmalari": kargo_firmalari,
        "Denetim_OlayTurleri": olay_turleri,
        "Denetim_Seviyeler": seviyeler,
        "Kimlik_Adresler": adresler,
        "Kimlik_KullaniciRolleri": kullanici_rolleri,
        "Siparis_Siparisler": siparisler,
        "Siparis_SiparisKalemleri": siparis_kalemleri,
        "Siparis_SiparisDurumGecmisi": siparis_durum_gecmisi,
        "Odeme_OdemeIslemleri": odeme_islemleri,
        "Odeme_IadeIslemleri": iade_islemleri,
        "Kargo_KargoGonderileri": kargo_gonderileri,
        "Kargo_KargoHareketleri": kargo_hareketleri,
        "Denetim_DenetimKayitlari": denetim_kayitlari,
    }


def export_csv_files(datasets):
    CSV_DIR.mkdir(parents=True, exist_ok=True)
    for name, rows in datasets.items():
        if not rows:
            continue
        csv_path = CSV_DIR / f"{name}.csv"
        fieldnames = list(rows[0].keys())
        with open(csv_path, mode="w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for r in rows:
                clean_row = {k: ("" if v is None else v) for k, v in r.items()}
                writer.writerow(clean_row)
    print(f"[OK] 20 CSV dosyası '{CSV_DIR}' dizinine başarıyla üretildi.")


def build_sqlite_database(datasets):
    SQLITE_PATH.parent.mkdir(parents=True, exist_ok=True)
    if SQLITE_PATH.exists():
        SQLITE_PATH.unlink()

    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()

    for table_name, rows in datasets.items():
        if not rows:
            continue
        cols = list(rows[0].keys())
        col_defs = []
        for idx, c in enumerate(cols):
            if idx == 0:
                col_defs.append(f'"{c}" INTEGER PRIMARY KEY')
            elif any(k in c for k in ("Tutari", "Toplam", "Fiyat", "Ucreti", "Tutar")):
                col_defs.append(f'"{c}" REAL')
            elif c.endswith("ID") or c in ("Miktar", "AktifMi", "VarsayilanMi", "BasariliMi", "OncelikSirasi"):
                col_defs.append(f'"{c}" INTEGER')
            else:
                col_defs.append(f'"{c}" TEXT')

        create_sql = f'CREATE TABLE "{table_name}" ({", ".join(col_defs)});'
        cur.execute(create_sql)

        placeholders = ", ".join(["?"] * len(cols))
        insert_sql = f'INSERT INTO "{table_name}" ({", ".join(cols)}) VALUES ({placeholders})'
        for r in rows:
            values = []
            for c in cols:
                v = r[c]
                if v == "":
                    v = None
                elif any(k in c for k in ("Tutari", "Toplam", "Fiyat", "Ucreti", "Tutar")) and v is not None:
                    v = float(v)
                values.append(v)
            cur.execute(insert_sql, values)

    conn.commit()
    conn.close()
    print(f"[OK] SQLite analitik veritabanı '{SQLITE_PATH}' başarıyla oluşturuldu.")


if __name__ == "__main__":
    data = generate_datasets()
    export_csv_files(data)
    build_sqlite_database(data)
