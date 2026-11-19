-- ============================================================================
-- PROJE: Mikroservis Sipariş ve Merkezi Audit (Denetim) Veritabanı Sistemi
-- DOSYA: 01_schema_and_tables.sql
-- AÇIKLAMA: Veritabanı, Mikroservis Şemaları (Kimlik, Siparis, Odeme, Kargo, Denetim),
--           20 Tablo, Primary/Foreign Key, Check Constraint ve Default tanımları.
-- ============================================================================

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'MerkeziAuditSiparisDB')
BEGIN
    CREATE DATABASE [MerkeziAuditSiparisDB];
END
GO

USE [MerkeziAuditSiparisDB];
GO

-- ============================================================================
-- 1. MİKROSERVİS ŞEMALARININ (BOUNDED CONTEXT) OLUŞTURULMASI
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'Kimlik')  EXEC('CREATE SCHEMA [Kimlik]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'Siparis') EXEC('CREATE SCHEMA [Siparis]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'Odeme')   EXEC('CREATE SCHEMA [Odeme]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'Kargo')   EXEC('CREATE SCHEMA [Kargo]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'Denetim') EXEC('CREATE SCHEMA [Denetim]');
GO

-- ============================================================================
-- 2. [Kimlik] ŞEMASI TABLOLARI (Identity & Service Registry Context)
-- ============================================================================

-- 2.1. Kullanicilar
IF OBJECT_ID('[Kimlik].[Kullanicilar]', 'U') IS NULL
CREATE TABLE [Kimlik].[Kullanicilar] (
    [KullaniciID]     BIGINT IDENTITY(1,1) NOT NULL,
    [KullaniciAdi]    NVARCHAR(100) NOT NULL,
    [Ad]              NVARCHAR(100) NOT NULL,
    [Soyad]           NVARCHAR(100) NOT NULL,
    [Eposta]          NVARCHAR(255) NOT NULL,
    [Telefon]         NVARCHAR(30)  NULL,
    [AktifMi]         BIT           NOT NULL CONSTRAINT [DF_Kullanicilar_AktifMi] DEFAULT (1),
    [KayitTarihi]     DATETIME2(3)  NOT NULL CONSTRAINT [DF_Kullanicilar_KayitTarihi] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_Kimlik_Kullanicilar] PRIMARY KEY CLUSTERED ([KullaniciID] ASC),
    CONSTRAINT [UQ_Kimlik_Kullanicilar_KullaniciAdi] UNIQUE ([KullaniciAdi]),
    CONSTRAINT [UQ_Kimlik_Kullanicilar_Eposta] UNIQUE ([Eposta])
);
GO

-- 2.2. Roller
IF OBJECT_ID('[Kimlik].[Roller]', 'U') IS NULL
CREATE TABLE [Kimlik].[Roller] (
    [RolID]           INT IDENTITY(1,1) NOT NULL,
    [RolAdi]          NVARCHAR(100) NOT NULL,
    [Aciklama]        NVARCHAR(500) NULL,
    CONSTRAINT [PK_Kimlik_Roller] PRIMARY KEY CLUSTERED ([RolID] ASC),
    CONSTRAINT [UQ_Kimlik_Roller_RolAdi] UNIQUE ([RolAdi])
);
GO

-- 2.3. Servisler (Mikroservis Kayıt Envanteri)
IF OBJECT_ID('[Kimlik].[Servisler]', 'U') IS NULL
CREATE TABLE [Kimlik].[Servisler] (
    [ServisID]        INT IDENTITY(1,1) NOT NULL,
    [ServisKodu]      NVARCHAR(50)  NOT NULL,
    [ServisAdi]       NVARCHAR(150) NOT NULL,
    [Surum]           NVARCHAR(20)  NOT NULL CONSTRAINT [DF_Servisler_Surum] DEFAULT (N'v1.0.0'),
    [AktifMi]         BIT           NOT NULL CONSTRAINT [DF_Servisler_AktifMi] DEFAULT (1),
    CONSTRAINT [PK_Kimlik_Servisler] PRIMARY KEY CLUSTERED ([ServisID] ASC),
    CONSTRAINT [UQ_Kimlik_Servisler_ServisKodu] UNIQUE ([ServisKodu])
);
GO

-- 2.4. Adresler
IF OBJECT_ID('[Kimlik].[Adresler]', 'U') IS NULL
CREATE TABLE [Kimlik].[Adresler] (
    [AdresID]         BIGINT IDENTITY(1,1) NOT NULL,
    [KullaniciID]     BIGINT        NOT NULL,
    [AdresBasligi]    NVARCHAR(100) NOT NULL,
    [Sehir]           NVARCHAR(100) NOT NULL,
    [Ilce]            NVARCHAR(100) NOT NULL,
    [PostaKodu]       NVARCHAR(20)  NULL,
    [AcikAdres]       NVARCHAR(500) NOT NULL,
    [VarsayilanMi]    BIT           NOT NULL CONSTRAINT [DF_Adresler_VarsayilanMi] DEFAULT (0),
    CONSTRAINT [PK_Kimlik_Adresler] PRIMARY KEY CLUSTERED ([AdresID] ASC),
    CONSTRAINT [FK_Adresler_Kullanicilar] FOREIGN KEY ([KullaniciID])
        REFERENCES [Kimlik].[Kullanicilar] ([KullaniciID])
);
GO

-- 2.5. KullaniciRolleri
IF OBJECT_ID('[Kimlik].[KullaniciRolleri]', 'U') IS NULL
CREATE TABLE [Kimlik].[KullaniciRolleri] (
    [KullaniciRolID]  BIGINT IDENTITY(1,1) NOT NULL,
    [KullaniciID]     BIGINT       NOT NULL,
    [RolID]           INT          NOT NULL,
    [AtanmaTarihi]    DATETIME2(3) NOT NULL CONSTRAINT [DF_KullaniciRolleri_AtanmaTarihi] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_Kimlik_KullaniciRolleri] PRIMARY KEY CLUSTERED ([KullaniciRolID] ASC),
    CONSTRAINT [UQ_Kimlik_KullaniciRolleri] UNIQUE ([KullaniciID], [RolID]),
    CONSTRAINT [FK_KullaniciRolleri_Kullanicilar] FOREIGN KEY ([KullaniciID])
        REFERENCES [Kimlik].[Kullanicilar] ([KullaniciID]),
    CONSTRAINT [FK_KullaniciRolleri_Roller] FOREIGN KEY ([RolID])
        REFERENCES [Kimlik].[Roller] ([RolID])
);
GO

-- ============================================================================
-- 3. [Siparis] ŞEMASI TABLOLARI (Order Management Context)
-- ============================================================================

-- 3.1. SiparisDurumlari
IF OBJECT_ID('[Siparis].[SiparisDurumlari]', 'U') IS NULL
CREATE TABLE [Siparis].[SiparisDurumlari] (
    [SiparisDurumID]  INT IDENTITY(1,1) NOT NULL,
    [DurumKodu]       NVARCHAR(50)  NOT NULL,
    [DurumAdi]        NVARCHAR(100) NOT NULL,
    [Aciklama]        NVARCHAR(500) NULL,
    CONSTRAINT [PK_Siparis_SiparisDurumlari] PRIMARY KEY CLUSTERED ([SiparisDurumID] ASC),
    CONSTRAINT [UQ_Siparis_SiparisDurumlari_DurumKodu] UNIQUE ([DurumKodu])
);
GO

-- 3.2. Siparisler
IF OBJECT_ID('[Siparis].[Siparisler]', 'U') IS NULL
CREATE TABLE [Siparis].[Siparisler] (
    [SiparisID]          BIGINT IDENTITY(1,1) NOT NULL,
    [SiparisNo]          NVARCHAR(50)   NOT NULL,
    [KullaniciID]        BIGINT         NOT NULL,
    [TeslimatAdresID]    BIGINT         NULL,
    [SiparisDurumID]     INT            NOT NULL,
    [OlusturanServisID]  INT            NOT NULL,
    [AraToplam]          DECIMAL(18,2)  NOT NULL CONSTRAINT [CK_Siparisler_AraToplam] CHECK ([AraToplam] >= 0),
    [VergiTutari]        DECIMAL(18,2)  NOT NULL CONSTRAINT [DF_Siparisler_Vergi] DEFAULT (0),
    [KargoTutari]        DECIMAL(18,2)  NOT NULL CONSTRAINT [DF_Siparisler_Kargo] DEFAULT (0),
    [GenelToplam]        DECIMAL(18,2)  NOT NULL CONSTRAINT [CK_Siparisler_GenelToplam] CHECK ([GenelToplam] >= 0),
    [ParaBirimi]         NVARCHAR(10)   NOT NULL CONSTRAINT [DF_Siparisler_ParaBirimi] DEFAULT (N'TRY'),
    [SiparisTarihi]      DATETIME2(3)   NOT NULL CONSTRAINT [DF_Siparisler_SiparisTarihi] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_Siparis_Siparisler] PRIMARY KEY CLUSTERED ([SiparisID] ASC),
    CONSTRAINT [UQ_Siparis_Siparisler_SiparisNo] UNIQUE ([SiparisNo]),
    CONSTRAINT [FK_Siparisler_Kullanicilar] FOREIGN KEY ([KullaniciID])
        REFERENCES [Kimlik].[Kullanicilar] ([KullaniciID]),
    CONSTRAINT [FK_Siparisler_Adresler] FOREIGN KEY ([TeslimatAdresID])
        REFERENCES [Kimlik].[Adresler] ([AdresID]),
    CONSTRAINT [FK_Siparisler_SiparisDurumlari] FOREIGN KEY ([SiparisDurumID])
        REFERENCES [Siparis].[SiparisDurumlari] ([SiparisDurumID]),
    CONSTRAINT [FK_Siparisler_Servisler] FOREIGN KEY ([OlusturanServisID])
        REFERENCES [Kimlik].[Servisler] ([ServisID])
);
GO

-- 3.3. SiparisKalemleri
IF OBJECT_ID('[Siparis].[SiparisKalemleri]', 'U') IS NULL
CREATE TABLE [Siparis].[SiparisKalemleri] (
    [SiparisKalemID]  BIGINT IDENTITY(1,1) NOT NULL,
    [SiparisID]       BIGINT         NOT NULL,
    [UrunKodu]        NVARCHAR(50)   NOT NULL,
    [UrunAdi]         NVARCHAR(250)  NOT NULL,
    [Miktar]          INT            NOT NULL CONSTRAINT [CK_SiparisKalemleri_Miktar] CHECK ([Miktar] > 0),
    [BirimFiyat]      DECIMAL(18,2)  NOT NULL CONSTRAINT [CK_SiparisKalemleri_BirimFiyat] CHECK ([BirimFiyat] >= 0),
    [IndirimTutari]   DECIMAL(18,2)  NOT NULL CONSTRAINT [DF_SiparisKalemleri_Indirim] DEFAULT (0),
    [SatirToplami]    DECIMAL(18,2)  NOT NULL,
    CONSTRAINT [PK_Siparis_SiparisKalemleri] PRIMARY KEY CLUSTERED ([SiparisKalemID] ASC),
    CONSTRAINT [FK_SiparisKalemleri_Siparisler] FOREIGN KEY ([SiparisID])
        REFERENCES [Siparis].[Siparisler] ([SiparisID])
);
GO

-- 3.4. SiparisDurumGecmisi
IF OBJECT_ID('[Siparis].[SiparisDurumGecmisi]', 'U') IS NULL
CREATE TABLE [Siparis].[SiparisDurumGecmisi] (
    [SiparisDurumGecmisID]  BIGINT IDENTITY(1,1) NOT NULL,
    [SiparisID]             BIGINT        NOT NULL,
    [EskiSiparisDurumID]    INT           NULL,
    [YeniSiparisDurumID]    INT           NOT NULL,
    [DegistirenKullaniciID] BIGINT        NULL,
    [DegisimTarihi]         DATETIME2(3)  NOT NULL CONSTRAINT [DF_SiparisDurumGecmisi_Tarih] DEFAULT (SYSDATETIME()),
    [Aciklama]              NVARCHAR(500) NULL,
    CONSTRAINT [PK_Siparis_SiparisDurumGecmisi] PRIMARY KEY CLUSTERED ([SiparisDurumGecmisID] ASC),
    CONSTRAINT [FK_SiparisDurumGecmisi_Siparisler] FOREIGN KEY ([SiparisID])
        REFERENCES [Siparis].[Siparisler] ([SiparisID]),
    CONSTRAINT [FK_SiparisDurumGecmisi_EskiDurum] FOREIGN KEY ([EskiSiparisDurumID])
        REFERENCES [Siparis].[SiparisDurumlari] ([SiparisDurumID]),
    CONSTRAINT [FK_SiparisDurumGecmisi_YeniDurum] FOREIGN KEY ([YeniSiparisDurumID])
        REFERENCES [Siparis].[SiparisDurumlari] ([SiparisDurumID]),
    CONSTRAINT [FK_SiparisDurumGecmisi_Kullanicilar] FOREIGN KEY ([DegistirenKullaniciID])
        REFERENCES [Kimlik].[Kullanicilar] ([KullaniciID])
);
GO

-- ============================================================================
-- 4. [Odeme] ŞEMASI TABLOLARI (Payment & Refund Context)
-- ============================================================================

-- 4.1. OdemeYontemleri
IF OBJECT_ID('[Odeme].[OdemeYontemleri]', 'U') IS NULL
CREATE TABLE [Odeme].[OdemeYontemleri] (
    [OdemeYontemID]   INT IDENTITY(1,1) NOT NULL,
    [YontemKodu]      NVARCHAR(50)  NOT NULL,
    [YontemAdi]       NVARCHAR(100) NOT NULL,
    [AktifMi]         BIT           NOT NULL CONSTRAINT [DF_OdemeYontemleri_AktifMi] DEFAULT (1),
    CONSTRAINT [PK_Odeme_OdemeYontemleri] PRIMARY KEY CLUSTERED ([OdemeYontemID] ASC),
    CONSTRAINT [UQ_Odeme_OdemeYontemleri_YontemKodu] UNIQUE ([YontemKodu])
);
GO

-- 4.2. OdemeDurumlari
IF OBJECT_ID('[Odeme].[OdemeDurumlari]', 'U') IS NULL
CREATE TABLE [Odeme].[OdemeDurumlari] (
    [OdemeDurumID]    INT IDENTITY(1,1) NOT NULL,
    [DurumKodu]       NVARCHAR(50)  NOT NULL,
    [DurumAdi]        NVARCHAR(100) NOT NULL,
    CONSTRAINT [PK_Odeme_OdemeDurumlari] PRIMARY KEY CLUSTERED ([OdemeDurumID] ASC),
    CONSTRAINT [UQ_Odeme_OdemeDurumlari_DurumKodu] UNIQUE ([DurumKodu])
);
GO

-- 4.3. OdemeIslemleri
IF OBJECT_ID('[Odeme].[OdemeIslemleri]', 'U') IS NULL
CREATE TABLE [Odeme].[OdemeIslemleri] (
    [OdemeID]         BIGINT IDENTITY(1,1) NOT NULL,
    [SiparisID]       BIGINT         NOT NULL,
    [OdemeYontemID]   INT            NOT NULL,
    [OdemeDurumID]    INT            NOT NULL,
    [Tutar]           DECIMAL(18,2)  NOT NULL CONSTRAINT [CK_OdemeIslemleri_Tutar] CHECK ([Tutar] >= 0),
    [ParaBirimi]      NVARCHAR(10)   NOT NULL CONSTRAINT [DF_OdemeIslemleri_ParaBirimi] DEFAULT (N'TRY'),
    [SaglayiciRefNo]  NVARCHAR(100)  NULL,
    [HataMesaji]      NVARCHAR(500)  NULL,
    [IslemTarihi]     DATETIME2(3)   NOT NULL CONSTRAINT [DF_OdemeIslemleri_IslemTarihi] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_Odeme_OdemeIslemleri] PRIMARY KEY CLUSTERED ([OdemeID] ASC),
    CONSTRAINT [FK_OdemeIslemleri_Siparisler] FOREIGN KEY ([SiparisID])
        REFERENCES [Siparis].[Siparisler] ([SiparisID]),
    CONSTRAINT [FK_OdemeIslemleri_OdemeYontemleri] FOREIGN KEY ([OdemeYontemID])
        REFERENCES [Odeme].[OdemeYontemleri] ([OdemeYontemID]),
    CONSTRAINT [FK_OdemeIslemleri_OdemeDurumlari] FOREIGN KEY ([OdemeDurumID])
        REFERENCES [Odeme].[OdemeDurumlari] ([OdemeDurumID])
);
GO

-- 4.4. IadeIslemleri
IF OBJECT_ID('[Odeme].[IadeIslemleri]', 'U') IS NULL
CREATE TABLE [Odeme].[IadeIslemleri] (
    [IadeID]          BIGINT IDENTITY(1,1) NOT NULL,
    [OdemeID]         BIGINT         NOT NULL,
    [IadeTutari]      DECIMAL(18,2)  NOT NULL CONSTRAINT [CK_IadeIslemleri_IadeTutari] CHECK ([IadeTutari] > 0),
    [IadeDurumu]      NVARCHAR(50)   NOT NULL,
    [IadeNedeni]      NVARCHAR(500)  NULL,
    [IadeTarihi]      DATETIME2(3)   NOT NULL CONSTRAINT [DF_IadeIslemleri_IadeTarihi] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_Odeme_IadeIslemleri] PRIMARY KEY CLUSTERED ([IadeID] ASC),
    CONSTRAINT [FK_IadeIslemleri_OdemeIslemleri] FOREIGN KEY ([OdemeID])
        REFERENCES [Odeme].[OdemeIslemleri] ([OdemeID])
);
GO

-- ============================================================================
-- 5. [Kargo] ŞEMASI TABLOLARI (Shipping & Logistics Context)
-- ============================================================================

-- 5.1. KargoDurumlari
IF OBJECT_ID('[Kargo].[KargoDurumlari]', 'U') IS NULL
CREATE TABLE [Kargo].[KargoDurumlari] (
    [KargoDurumID]    INT IDENTITY(1,1) NOT NULL,
    [DurumKodu]       NVARCHAR(50)  NOT NULL,
    [DurumAdi]        NVARCHAR(100) NOT NULL,
    CONSTRAINT [PK_Kargo_KargoDurumlari] PRIMARY KEY CLUSTERED ([KargoDurumID] ASC),
    CONSTRAINT [UQ_Kargo_KargoDurumlari_DurumKodu] UNIQUE ([DurumKodu])
);
GO

-- 5.2. KargoFirmalari
IF OBJECT_ID('[Kargo].[KargoFirmalari]', 'U') IS NULL
CREATE TABLE [Kargo].[KargoFirmalari] (
    [KargoFirmaID]    INT IDENTITY(1,1) NOT NULL,
    [FirmaKodu]       NVARCHAR(50)  NOT NULL,
    [FirmaAdi]        NVARCHAR(150) NOT NULL,
    [AktifMi]         BIT           NOT NULL CONSTRAINT [DF_KargoFirmalari_AktifMi] DEFAULT (1),
    CONSTRAINT [PK_Kargo_KargoFirmalari] PRIMARY KEY CLUSTERED ([KargoFirmaID] ASC),
    CONSTRAINT [UQ_Kargo_KargoFirmalari_FirmaKodu] UNIQUE ([FirmaKodu])
);
GO

-- 5.3. KargoGonderileri
IF OBJECT_ID('[Kargo].[KargoGonderileri]', 'U') IS NULL
CREATE TABLE [Kargo].[KargoGonderileri] (
    [KargoGonderiID]      BIGINT IDENTITY(1,1) NOT NULL,
    [SiparisID]           BIGINT         NOT NULL,
    [KargoFirmaID]        INT            NOT NULL,
    [KargoDurumID]        INT            NOT NULL,
    [TakipNo]             NVARCHAR(100)  NOT NULL,
    [GonderiUcreti]       DECIMAL(18,2)  NOT NULL CONSTRAINT [DF_KargoGonderileri_Ucret] DEFAULT (0),
    [KargoyaVerilisTarihi] DATETIME2(3)  NOT NULL CONSTRAINT [DF_KargoGonderileri_Verilis] DEFAULT (SYSDATETIME()),
    [TeslimTarihi]        DATETIME2(3)   NULL,
    CONSTRAINT [PK_Kargo_KargoGonderileri] PRIMARY KEY CLUSTERED ([KargoGonderiID] ASC),
    CONSTRAINT [UQ_Kargo_KargoGonderileri_TakipNo] UNIQUE ([TakipNo]),
    CONSTRAINT [FK_KargoGonderileri_Siparisler] FOREIGN KEY ([SiparisID])
        REFERENCES [Siparis].[Siparisler] ([SiparisID]),
    CONSTRAINT [FK_KargoGonderileri_KargoFirmalari] FOREIGN KEY ([KargoFirmaID])
        REFERENCES [Kargo].[KargoFirmalari] ([KargoFirmaID]),
    CONSTRAINT [FK_KargoGonderileri_KargoDurumlari] FOREIGN KEY ([KargoDurumID])
        REFERENCES [Kargo].[KargoDurumlari] ([KargoDurumID])
);
GO

-- 5.4. KargoHareketleri
IF OBJECT_ID('[Kargo].[KargoHareketleri]', 'U') IS NULL
CREATE TABLE [Kargo].[KargoHareketleri] (
    [KargoHareketID]  BIGINT IDENTITY(1,1) NOT NULL,
    [KargoGonderiID]  BIGINT         NOT NULL,
    [KargoDurumID]    INT            NOT NULL,
    [Lokasyon]        NVARCHAR(150)  NOT NULL,
    [Aciklama]        NVARCHAR(500)  NULL,
    [HareketTarihi]   DATETIME2(3)   NOT NULL CONSTRAINT [DF_KargoHareketleri_Tarih] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_Kargo_KargoHareketleri] PRIMARY KEY CLUSTERED ([KargoHareketID] ASC),
    CONSTRAINT [FK_KargoHareketleri_KargoGonderileri] FOREIGN KEY ([KargoGonderiID])
        REFERENCES [Kargo].[KargoGonderileri] ([KargoGonderiID]),
    CONSTRAINT [FK_KargoHareketleri_KargoDurumlari] FOREIGN KEY ([KargoDurumID])
        REFERENCES [Kargo].[KargoDurumlari] ([KargoDurumID])
);
GO

-- ============================================================================
-- 6. [Denetim] ŞEMASI TABLOLARI (Centralized Audit & Observability Context)
-- ============================================================================

-- 6.1. OlayTurleri
IF OBJECT_ID('[Denetim].[OlayTurleri]', 'U') IS NULL
CREATE TABLE [Denetim].[OlayTurleri] (
    [OlayTurID]       INT IDENTITY(1,1) NOT NULL,
    [OlayKodu]        NVARCHAR(100) NOT NULL,
    [OlayAdi]         NVARCHAR(150) NOT NULL,
    [Kategori]        NVARCHAR(100) NOT NULL,
    CONSTRAINT [PK_Denetim_OlayTurleri] PRIMARY KEY CLUSTERED ([OlayTurID] ASC),
    CONSTRAINT [UQ_Denetim_OlayTurleri_OlayKodu] UNIQUE ([OlayKodu])
);
GO

-- 6.2. Seviyeler (INFO, WARN, ERROR, CRITICAL, SECURITY)
IF OBJECT_ID('[Denetim].[Seviyeler]', 'U') IS NULL
CREATE TABLE [Denetim].[Seviyeler] (
    [SeviyeID]        INT IDENTITY(1,1) NOT NULL,
    [SeviyeKodu]      NVARCHAR(50)  NOT NULL,
    [SeviyeAdi]       NVARCHAR(100) NOT NULL,
    [OncelikSirasi]   INT           NOT NULL,
    CONSTRAINT [PK_Denetim_Seviyeler] PRIMARY KEY CLUSTERED ([SeviyeID] ASC),
    CONSTRAINT [UQ_Denetim_Seviyeler_SeviyeKodu] UNIQUE ([SeviyeKodu])
);
GO

-- 6.3. DenetimKayitlari (Merkezi Audit Log Tablosu)
IF OBJECT_ID('[Denetim].[DenetimKayitlari]', 'U') IS NULL
CREATE TABLE [Denetim].[DenetimKayitlari] (
    [DenetimID]       BIGINT IDENTITY(1,1) NOT NULL,
    [ServisID]        INT            NOT NULL,
    [OlayTurID]       INT            NOT NULL,
    [SeviyeID]        INT            NOT NULL,
    [KullaniciID]     BIGINT         NULL,
    [VarlikTipi]      NVARCHAR(100)  NOT NULL, -- Örn: 'Siparis', 'Odeme', 'Kargo'
    [VarlikID]        NVARCHAR(100)  NULL,     -- İlgili kaydın ID'si veya SiparisNo
    [KorelasyonID]    NVARCHAR(100)  NOT NULL, -- Distributed Tracing Correlation ID
    [IpAdresi]        NVARCHAR(50)   NULL,
    [BasariliMi]      BIT            NOT NULL CONSTRAINT [DF_DenetimKayitlari_BasariliMi] DEFAULT (1),
    [Mesaj]           NVARCHAR(1000) NOT NULL,
    [DetayJson]       NVARCHAR(MAX)  NULL,     -- Eski/Yeni değerler veya payload
    [OlusturmaTarihi] DATETIME2(3)   NOT NULL CONSTRAINT [DF_DenetimKayitlari_Tarih] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_Denetim_DenetimKayitlari] PRIMARY KEY CLUSTERED ([DenetimID] ASC),
    CONSTRAINT [FK_DenetimKayitlari_Servisler] FOREIGN KEY ([ServisID])
        REFERENCES [Kimlik].[Servisler] ([ServisID]),
    CONSTRAINT [FK_DenetimKayitlari_OlayTurleri] FOREIGN KEY ([OlayTurID])
        REFERENCES [Denetim].[OlayTurleri] ([OlayTurID]),
    CONSTRAINT [FK_DenetimKayitlari_Seviyeler] FOREIGN KEY ([SeviyeID])
        REFERENCES [Denetim].[Seviyeler] ([SeviyeID]),
    CONSTRAINT [FK_DenetimKayitlari_Kullanicilar] FOREIGN KEY ([KullaniciID])
        REFERENCES [Kimlik].[Kullanicilar] ([KullaniciID])
);
GO
