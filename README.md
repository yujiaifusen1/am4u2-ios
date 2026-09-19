# AM4U2 — 网页打包 iOS 壳应用

把 `https://am-4u2.pages.dev/` 包成一个原生 WKWebView 应用，产出**未签名的 .ipa**，再用侧载工具装到 iPhone 上。

改站点地址：`Sources/App.swift` 第 5 行的 `kHomeURL`。
改包名/应用名：`project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER` 和 `CFBundleDisplayName`。

---

## 方案 A：有 Mac（最快）

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project AM4U2.xcodeproj -scheme AM4U2 -configuration Release \
  -sdk iphoneos -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build

mkdir -p Payload && cp -R build/Build/Products/Release-iphoneos/AM4U2.app Payload/
zip -qr AM4U2-unsigned.ipa Payload
```

或者 `xcodegen generate` 之后直接用 Xcode 打开，选自己的 Apple ID 做签名，连线真机 Run 更省事。

## 方案 B：没有 Mac，用 GitHub Actions（免费）

1. 把这个文件夹推到一个 GitHub 仓库（公开仓库 macOS Runner 免费）。
2. 仓库 Actions 页面跑 **Build unsigned IPA**，或直接 push 触发。
3. 跑完在 Artifacts 里下载 `AM4U2-unsigned-ipa`。

---

## 装到手机上

拿到的是**未签名 ipa**，必须签名后才能装：

| 工具 | 说明 |
|---|---|
| Sideloadly / AltStore | 用自己的 Apple ID 免费签，免费账号 7 天过期，要定期重签 |
| 爱思助手 | Windows 上一键签名安装，同样 7 天 |
| TrollStore（巨魔） | 系统版本在支持范围内的话可永久安装，无需重签 |
| 企业证书 / 开发者账号 | 有证书就直接签，有效期长 |

**关于上架 App Store**：纯网页壳应用基本过不了审（Guideline 4.2 最低功能要求），这套工程是给侧载用的，不是给上架用的。

---

## 一个零成本的替代方案

如果只是想在桌面有个图标、全屏打开：Safari 打开网站 → 分享 → **添加到主屏幕**。不用签名、不会 7 天过期。站点如果带 manifest，体验跟壳应用几乎一样。

---

## 已经处理好的细节

- 视频内联播放 + 画中画 + 后台音频
- 下拉刷新、左滑返回手势
- `target="_blank"` 链接不会被吞
- 网页里的 alert / confirm 能正常弹窗
- 非 http scheme（外部播放器、微信等）转交系统打开
- Cookie / localStorage 持久化，登录态不丢
- 允许 http 明文请求（部分播放源需要）

图标没有放，未签名构建不需要。要图标的话把 `AppIcon.appiconset` 丢进 `Sources/` 并在 `project.yml` 里加 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`。
