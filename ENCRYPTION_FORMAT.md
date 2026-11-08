# Noty — 保險庫容器二進位格式規範書 (ENCRYPTION_FORMAT.md)

> **容器副檔名**：`.notyvault`  
> **Magic 標頭**：`NOTYVLT1` (8 位元組 ASCII)  
> **版本號**：1 (`UInt32` 大端序)

---

## 1. 檔案總體結構

```
+--------------------------------------------------------------+
| 1. Container Header (經 AES-256-GCM 獨立認證加密保護)           |
+--------------------------------------------------------------+
| 2. Chunk 0 Payload: [Length] + [Ciphertext] + [16 bytes Tag] |
+--------------------------------------------------------------+
| 3. Chunk 1 Payload: [Length] + [Ciphertext] + [16 bytes Tag] |
+--------------------------------------------------------------+
| ...                                                          |
+--------------------------------------------------------------+
| N. Chunk N Payload: [Length] + [Ciphertext] + [16 bytes Tag] |
+--------------------------------------------------------------+
```

---

## 2. 標頭結構 (Header Layout)

檔案前 4 位元組指示已加密 Header Payload 之長度：
- `Header Payload Length`: `UInt32` (大端序)
- `Header Sealed Box`: 包含 Nonce (12 bytes) + 密文 (Header 內部結構) + GCM Tag (16 bytes)，使用 `NOTY_HEADER_AAD` 進行認證。

### 解密後之 Header 內部結構（至少 64 位元組）：
| 位移 (Offset) | 長度 (Bytes) | 欄位名稱 | 說明 |
|---|---|---|---|
| 0 | 8 | Magic | 固定為 ASCII `"NOTYVLT1"` |
| 8 | 4 | Version | 容器格式版本，目前為 `1` |
| 12 | 32 | Salt | 32 位元組密碼學安全隨機 Salt |
| 44 | 4 | Chunk Size | 分塊大小，預設為 `4,194,304` (4 MiB) |
| 48 | 8 | Total Chunks | 總分塊數量 (`UInt64` 大端序) |
| 56 | 8 | Original File Size | 解密後原始檔案大小 (`UInt64` 大端序) |

---

## 3. 分塊資料結構 (Chunk Payload Layout)

從 Header 結束處開始，依序排列各分塊：

```
+-------------------------------------------------------+
| Ciphertext Length (4 Bytes, UInt32 Big-Endian)        |
+-------------------------------------------------------+
| Ciphertext Data (長度由上方欄位指定，至多 4,194,304 Bytes)   |
+-------------------------------------------------------+
| Authentication Tag (16 Bytes, GCM Auth Tag)          |
+-------------------------------------------------------+
```

### 完整性校驗規則：
- 解密各 Chunk 時，傳遞 AAD 為 `[chunkIndex (8B)] + [originalFileSize (8B)]`。
- Nonce 為 `[salt.prefix(4)] + [chunkIndex (8B)]`。
- 任一 Byte 遭竄改、或分塊順序被置換，解密流程皆會立即拋出 `VaultError.authenticationFailed`。
