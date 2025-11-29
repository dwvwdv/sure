# pubspec.lock 設置說明

## 重要：需要生成並提交 pubspec.lock

`pubspec.lock` 已從 `.gitignore` 中移除，以確保所有環境使用相同版本的依賴項。

### 下一步操作

請在有 Flutter 環境的機器上執行以下命令：

```bash
# 1. 拉取最新更改
git pull origin claude/audit-security-dependencies-01WQki9gGK8aZsfmPhs4viPc

# 2. 生成 pubspec.lock
flutter pub get

# 3. 驗證文件已生成
ls -la pubspec.lock

# 4. 提交 pubspec.lock
git add pubspec.lock
git commit -m "Add pubspec.lock for reproducible builds"
git push origin claude/audit-security-dependencies-01WQki9gGK8aZsfmPhs4viPc
```

### 為什麼需要 pubspec.lock？

- ✅ 確保所有開發者使用相同版本的依賴
- ✅ 確保 CI/CD 構建的可重現性
- ✅ 防止意外引入包含漏洞的新版本
- ✅ 符合 Flutter 最佳實踐

### 完成後

生成並提交 pubspec.lock 後，可以刪除此說明文件：

```bash
git rm SETUP_PUBSPEC_LOCK.md
git commit -m "Remove setup instructions after pubspec.lock is committed"
```
