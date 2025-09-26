# 🛠️ SD-Cardイメージの作成方法

> 🚀 atomcam_toolsの開発・ビルド環境構築ガイド

## 📋 必要な環境

### 💻 対応OS
- 🪟 Windows
- 🍎 macOS  
- 🐧 Linux

### 🔧 必要なツール
- 🌐 GitHubアクセス環境
- 🐳 Docker実行環境
- 📱 Lima（macOSの場合）

> ✅ **動作確認済み環境**: macOS Sonoma

## 🚀 クイックスタート

### 📥 基本ビルド手順

適当なディレクトリで以下のコマンドを実行：

```bash
# 📂 リポジトリのクローン
git clone https://github.com/mnakada/atomcam_tools
cd atomcam_tools

# 🐳 Docker環境準備（macOSのみ）
make lima

# 🔨 ビルド実行
make
```

⏱️ **所要時間**: 約1時間で`atomcam_tools/atomcam_tools.zip`が生成されます

### 📦 生成されるファイル

ビルド完了後、以下のファイルが`atomcam_tools.zip`に含まれます：

| ファイル名 | 説明 |
|---|---|
| 🔑 `authorized_keys` | SSH公開鍵認証用 |
| 🏷️ `hostname` | デバイス名設定 |
| 🏭 `factory_t31_ZMC6tiIDQN` | ファクトリーブートファイル |
| 💾 `rootfs_hack.squashfs` | カスタムルートファイルシステム |

## ⚙️ カスタマイズ設定

### 🔐 SSH設定（リモートログイン用）

公開鍵を追加してリモートアクセスを有効化：

```bash
cat ~/.ssh/id_rsa.pub >> ./target/authorized_keys
```

### 🏷️ デバイス名変更

デフォルトの`atomcam`から変更する場合：

```bash
echo "新しいホスト名" > ./target/hostname
```

### 💿 SD-Cardへの配置

**上記4つのファイルをSD-Cardルートにコピー**し、AtomCamに挿入して起動

> ⏰ **初回起動時の注意**: スワップファイル作成とSSHホストキー生成のため約40秒かかります

## 🐳 Docker環境操作

### 🔧 開発環境管理

```bash
# 🖥️ コンテナへログイン
make login

# 🚀 手動でDocker起動
make lima               # macOS
docker-compose up -d    # Linux
```

ビルド環境はイメージ作成後、Docker上にコンテナが起動状態になります。

## 🏗️ システム構成

### 💻 ハードウェア仕様

| 項目 | 仕様 |
|---|---|
| 🔧 **SoC** | Ingenic T31 SoC |
| ⚡ **CPU** | MIPS32R5 I$32K/D$32K/L2$128K |
| 🐧 **Kernel** | Linux 3.10.14 MIPSEL |

### 🏛️ AtomCam内部環境

このイメージでAtomCamを起動すると：

- 🔧 **glibcベース**: MIPSEL版Linux環境が起動
- 📁 **chroot構成**: `/atom`ディレクトリ以下に本来のAtomCamシステム
- 🏗️ **監獄化**: chrootで本来システムを隔離

## 🔄 起動シーケンス

### 1️⃣ U-Boot
- 📂 カーネル内蔵initramfsの`/init`ディレクトリに配置

### 2️⃣ Initramfs  
- 📁 内容: `initramfs_skeleton/`ディレクトリに格納
- 🚀 カーネル起動時に`/init`実行を設定

### 3️⃣ ツール更新
- 🔄 必要に応じて更新処理実行

### 4️⃣ ルートファイルシステム切り替え
- 💾 SD-Card上の`rootfs_hack.squashfs`をルートにswitch_root
- 🔄 remount処理実行
- 🚀 `/sbin/init（busybox）`起動

## 📁 rootfs_hack.squashfs 詳細

### 🏗️ 構成
`configs/atomcam_defconfig`設定でビルドされたイメージに`overlay_rootfs`を重ねて構成

### 🔄 起動プロセス

1. **🚀 初期化**
   - `/sbin/init`が`inittab`に従って`/etc/init.d/rcS`起動

2. **📜 スクリプト実行**  
   - `rcS`が`/etc/init.d/S*`を順番に実行

3. **🎯 完了サイン**
   - **シリアル接続**: gettyでログインプロンプト表示
   - **AtomCam**: 背面LED青点滅→青点灯でSSHログイン可能

## 🔧 重要な初期化スクリプト

### 🔄 `/etc/init.d/S16fwupdate`
- 🔧 AtomCamファームウェアアップデートシーケンスの代行処理

### 📁 `/etc/init.d/S20mountfs`
- 🔗 overlayfs未対応のため、bind mountでファイル/フォルダー配置を入れ替え

### 🏠 `/etc/init.d/S61atomcam`
- 📂 `/atom/`以下に本来のATOMCamシステムをmount
- 🔗 共通アクセス可能なmount-point設定
- 🏗️ chrootで`/atom`の`/tmp/system/bin/atom_init.sh`呼び出し

> 🌐 **ここまではglibcの世界で動作**

### 🎯 `/atom/tmp/system/bin/atom_init.sh`
- 🔧 本来のAtomCam初期化シーケンス実行
- 📚 **ここからuClibcの環境**
- 🔗 iCamera_app実行時に`libcallback.so`介在でパッチ適用
- 📝 WebHook用ログを名前付きFIFOファイル（`/var/run/atomapp`）出力
- ⚠️ **注意**: ウォッチドッグ起動のため、assist・iCamera_appは停止不可
- ☁️ **機能**: 認識機能等はクラウドから動的読み込み実行

---

## 📜 システムスクリプト詳細

### 🔧 コマンド置き換えスクリプト

#### 📁 `/atom/bin/mv`, `/atom/bin/rm`
- 🎯 **目的**: AtomCamのiCloud_app動作を拡張
- 🗑️ **rm**: 動体検知クラウド送信後の削除処理
- 📁 **mv**: 1分毎のSD-Card記録ファイル移動処理
- 🔗 **機能**: NAS記録・WebHookイベント送信

### 🎛️ システム制御スクリプト

#### 🖥️ `/scripts/cmd`
- 🎚️ iCamera_app内部パラメータ・動作変更のラッパーコマンド

#### 🛣️ `/scripts/cruise.sh` 
- 🔄 AtomSwingクルーズ動作実行

#### 🔧 `/scripts/hack_ini_reconfig.sh`
- 🔄 バージョンアップ時のhack_ini互換性処理

#### 🏥 `/scripts/health_check.sh`
- 📡 定期的ネットワーク健全性チェック

#### 🌐 `/scripts/lighttpd.sh`
- 🖥️ WebUI lighttpd起動処理・認証切り替え

#### 🧠 `/scripts/memory_check.sh`
- 📊 定期的メモリー状態ログ記録

#### 🎮 `/scripts/motor_init`
- 🔄 AtomSwingモーター初期位置動作

#### 🌐 `/scripts/network_init.sh`
- 📡 ネットワーク接続初期化

#### 🔄 `/scripts/reboot.sh`
- ⏰ WebUI定期リブート設定のcrontab実行
- 🔄 同期リブート実行

#### 🗑️ `/scripts/remove_old.sh`
- 📅 指定時間経過録画データ削除

#### 📺 `/scripts/rtspserver.sh`
- 🎥 v4l2rtspserver on/off制御
- 🔗 init.d/S58rtspserver・WebUI RTSPから呼び出し

#### 📂 `/scripts/samba.sh`
- 🌐 **Samba起動/終了**制御

#### ⏰ `/scripts/set_crontab.sh`
- 📅 `reboot.sh`・`timelapse.sh`のcrontab時刻設定

#### ⚙️ `/scripts/set_icamera_config.sh`
- 🎛️ `iCamera_app`起動直後の必須設定値処理

#### 🎬 `/scripts/timelapse.sh`
- ⏱️ タイムラプス開始処理・終了時ファイル処理

#### 🖥️ `/scripts/webcmd.sh`
- 🔗 `/var/www/cgi-bin/exec.cgi`から名前付きFIFO経由コマンド実行
- 👤 **www-data**アカウント制限対応の安全実行構造

#### 🔔 `/scripts/webhook.sh`
- 📝 iCamera_appログ受信・WebHookイベント処理
- 🚰 名前付きFIFO経由ログ受信・curl POST送信

### 🌐 WebUI CGIスクリプト

#### 🖥️ `/var/www/cgi-bin/cmd.cgi`
- 🔗 WebUIコマンドを名前付きパイプ経由でwebcmd.shに転送

#### 📷 `/var/www/cgi-bin/get_jpeg.cgi`
- 🖼️ WebUI表示用JPEG画像取得

#### ⚙️ `/var/www/cgi-bin/hack_ini.cgi`
- 📝 WebUI設定値の取得・設定処理

#### 📱 `/var/www/cgi-bin/hello.cgi`
- 📲 モバイルアプリアクセス要求応答

#### 🎥 `/var/www/cgi-bin/video_isp.cgi`
- 🎛️ カメラ設定詳細項目操作

#### 🖼️ `/var/www/cgi-bin/watermark.cgi`
- 🏷️ システム設定ロゴ設定処理

---

## 💻 WebUI開発環境

### 🎨 技術スタック
- **📁 ソースディレクトリ**: `web/`
- **🖼️ フロントエンド**: Vue.js + ElementUI
- **⚙️ バックエンド**: lighttpd + CGI
- **🔗 通信**: axios経由API通信

### 🏗️ アーキテクチャ
- **🎯 ターゲット**: MIPSEL（Node.js最新版未対応）
- **🔧 構成**: フロントエンドのみビルド、バックエンドはlighttpd+CGI
- **📄 メインコンポーネント**: `web/source/vue/Setting.vue`

---

## 🐳 Docker開発環境

### 📂 ディレクトリマッピング
- **🔗 マッピング**: `/src` ↔ `atomcam_tools/`

### 🖥️ 基本作業ディレクトリ
```bash
root@ac0375635c01:/atomtools# cd /atomtools/build/buildroot-2016.02
```

### 🔧 コンパイラ環境

#### 🌐 glibc環境（rootfs用）
- **📦 環境**: glibcでDocker内gcc使用
- **🔧 gccプレフィックス**: 
  ```
  /atomtools/build/buildroot-2016.02/output/host/usr/bin/mipsel-ingenic-linux-gnu-
  ```

#### 📚 uClibc環境（iCamera_app用）
- **🎯 用途**: iCamera_appハック用libcallback.soビルド
- **🔧 ツールチェーン**: cross tools-ng-1.26.0
- **🔧 gccプレフィックス**:
  ```
  /atomtools/build/cross/mips-uclibc/bin/mipsel-ingenic-linux-uclibc-
  ```

---

## 🔨 各種変更時のビルド方法

### 🐧 initramfs・kernelのconfig変更

```bash
make linux-rebuild
make
```
📁 ビルド結果は`atomcam_tools/target`にコピーされます

### 📦 rootfs内ファイル・busybox menuconfig修正

```bash
make
```
📁 ビルド結果は`atomcam_tools/target`にコピーされます

### 📋 rootfs含有パッケージ変更

```bash
make menuconfig
make
```
📁 ビルド結果は`atomcam_tools/target`にコピーされます

### 🔧 個別パッケージリビルド

```bash
make <package>-rebuild
make
```

### 🛠️ busyboxコマンド設定変更

```bash
make busybox-menuconfig
make
```
🔧 rootfsがビルドされます

### ⚙️ kernel設定変更

```bash
make linux-menuconfig
make linux-rebuild
make
```
📁 ビルド結果は`atomcam_tools/target`にコピーされます

---

## 📞 開発サポート

### 🐛 問題解決
- **Issues**: [GitHub Issues](https://github.com/mnakada/atomcam_tools/issues)
- **ドキュメント**: [README.md](./README.md)

### 🔧 開発のヒント
- 🐳 Docker環境での開発が推奨
- 🔄 変更は段階的にテスト
- 📝 ビルドログを確認して問題を特定

---
