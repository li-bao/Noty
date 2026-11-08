# Noty — 安全與密碼學自動化驗證報告 (SECURITY_TEST_REPORT.md)

> **測試類別**：AES-256-GCM、PBKDF2、Keychain、LFES-12122、保險庫屏障  
> **測試成果**：100% 通過（14 項專屬安全測試全數綠燈）

---

## 1. 密碼學核心驗證清單

| 測試案例 | 驗證目標 | 測試結果 | 耗時 |
|---|---|---|---|
| `testAES256KeyDerivationWithPBKDF2` | 600,000 次 PBKDF2-HMAC-SHA256 推導 256 位元金鑰 | **PASS** | 0.082s |
| `testAES256AuthenticatedEncryptionAndDecryption` | AES-256-GCM 正確金鑰解密與錯誤金鑰拒絕 | **PASS** | 0.003s |
| `testAES256TamperedCiphertextAndTagDetection` | 密文竄改 1 位元組立即拋出 `authenticationFailed` | **PASS** | 0.002s |
| `testAES256StreamingChunkFileEncryptionAndSHA256ExactMatch` | 4.5MB 檔案跨 4 MiB 分塊串流加密，解密後 SHA-256 100% 吻合 | **PASS** | 0.028s |
| `testAES256TruncatedEncryptedFileDetection` | 檔案遭非預期截斷精準偵測拋出 `truncatedFile` | **PASS** | 0.003s |
| `testVaultFieldLevelEncryptionLifecycle` | SwiftData 欄位級敏感資訊加解密與鎖定遮罩 | **PASS** | 0.100s |
| `testLFES12122TestVectorsExactMatch` | 0C 至 3C3+ 全部 7 組原始測試向量精準比對 | **PASS** | 0.000s |
| `testLFES12122ReversibleDecryptionFlow` | 6 步可逆解密流程逆向還原至 `"1"` | **PASS** | 0.000s |
| `testLFES12122PasswordDigitCyclicExtraction` | 密碼位數循環提取依序取用規則 | **PASS** | 0.000s |
| `testLFES12122ArbitraryDataThrowsSpecificationIncomplete` | 泛化未定義 Unicode 資料安全拒絕 | **PASS** | 0.000s |
| `testOllamaVaultLockedPrivacyBarrier` | 保險庫鎖定時徹底阻斷 AI 存取私人日記與媒體 | **PASS** | 0.000s |
| `testKeychainServicePasscodeSecurity` | 獨立密碼存入 Keychain，零明文洩漏 | **PASS** | 0.051s |
| `testSecurityServiceBiometricsCheck` | Touch ID 與 LocalAuthentication 硬體探測 | **PASS** | 0.005s |
| `testSecurityServicePrivacyNoticeDisclosure` | 誠實揭露應用程式鎖定與磁碟加密邊界 | **PASS** | 0.000s |

---

## 2. 結論與安全建議

1. **認證加密防線穩固**：AES-256-GCM 配合 600,000 次 PBKDF2 與單調遞增 Nonce，在 Apple Silicon M4 上解鎖耗時低於 100ms，抗字典破解強度極高。
2. **原創演算法界線分明**：LFES-12122 嚴格保留作者所有原始定義與測試向量，在通用擴充尚未經密碼學審核前，標註為 `Experimental Custom Layer`，確保系統穩定度與防護力兼備。
3. **零明文原則**：所有密碼、Salt 與認證標記皆由 macOS Keychain 保護，絕不落盤 UserDefaults。
