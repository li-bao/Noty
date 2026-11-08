# Noty — AES-256-GCM 加密引擎技術手冊 (AES256_IMPLEMENTATION.md)

> **實作類別**：`AES256VaultEngine.swift` & `VaultEncryptionService.swift`  
> **技術標準**：Apple CryptoKit, CommonCrypto, NIST SP 800-38D (GCM Mode), PKCS#5 v2.0 (PBKDF2)

---

## 1. 核心參數與密碼學規範

- **對稱演算法**：AES-256-GCM (Galois/Counter Mode)
- **金鑰長度**：256 bits (32 bytes)
- **認證標籤 (Authentication Tag)**：128 bits (16 bytes)
- **初始化向量／Nonce 長度**：96 bits (12 bytes)
- **金鑰推導演算法**：PBKDF2-HMAC-SHA256
- **KDF 迭代次數**：600,000 次（兼顧 Apple Silicon M4 晶片效能與抗暴力破解強度）
- **Salt 長度**：32 bytes（由 `SecRandomCopyBytes` 產生）
- **分塊串流尺寸**：4 MiB (4,194,304 bytes)

---

## 2. 大型檔案分塊串流加密管線

針對數百 MB 至數 GB 的 4K 影片與高解析照片，系統絕不將整個檔案載入記憶體，而是透過 4 MiB 分塊流水線處理：

### 每個 Chunk 的認證加密：
1. **Nonce 構造**：
   - 前 4 位元組：Salt 的前 4 位元組切片。
   - 後 8 位元組：`UInt64(chunkIndex).bigEndian`。
   - 確保同一金鑰下 Nonce 嚴格單調遞增，絕不重複。
2. **關聯資料 (AAD)**：
   - 綁定 `chunkIndex.bigEndian` (8 bytes) 與 `fileSize.bigEndian` (8 bytes)。
   - 確保分塊若遭調換順序或檔案遭截斷，GCM 標籤校驗立即拋出 `authenticationFailed`。
3. **分塊封裝結構**：
   `[4 bytes Ciphertext Length] + [Ciphertext (≤ 4 MiB)] + [16 bytes Tag]`

---

## 3. SwiftData 欄位級敏感資訊保護

- **前綴標識**：`notyvlt:aes256:`
- **編碼格式**：Base64 封裝之 GCM SealedBox（包含 Nonce + 密文 + Tag）。
- **解密防禦**：
  - 當保險庫處於 Unlocked 狀態，在記憶體中即時還原顯示。
  - 當保險庫處於 Locked 狀態，傳回 `🔒 [此筆私人內容已加密保全，請解鎖保險庫查看]` 遮罩，防止資料庫遭實體存取洩漏。
