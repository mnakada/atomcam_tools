# SD-Cardイメージのbuild方法

## 必要なbuild環境

- Window / MacOS / Linux

- githubへのアクセスできる環境

- Dockerの実行環境

<br>

※ 以下MacOS Sonomaで確認しています。

<br>

## build方法

適当なdirectoryで下記を実行します。

MacOSの場合はDocker起動にlimaを使います。

事前にlima, docker CLI, docker-composeをinstallしておいてください。

```shell
# git clone atomcam_tools
# cd atomcam_tools
# make lima  <---- MacOSのみ
# make
```

環境に依存しますが１時間程度でatomcam_tools.zipが出来上がります。

zipの中身は

- authorized_keys
- hostname
- factory_t31_ZMC6tiIDQN
- rootfs_hack.squashfs

で、atomcam_tools/target 以下に出来ているものと同じです。

remote loginするなら、sshのpublic.keyをauthorized_keysに追加してください。

```shell
# cat ~/.ssh/id_rsa.pub >> ./target/authorized_keys
```

デバイス名を変更するなら、hostnameを修正してください。(default : atomcam)

```shell
# echo "hogehoge" > ./target/hostname
```

上記４つのファイルをSD-CardにコピーしてAtomCamに入れて起動します。

初回起動時はswap fileの作成とsshのhost-keyを作成するのに少し時間がかかるので40秒程度かかります。

build環境は一度buildするとdocker上にコンテナが起動した状態になっています。

```shell
# make login
```

でコンテナに入れます。
dockerコンテナが落ちてるときは

```shell
# make lima   <----- MacOSの場合
# docker-compose up -d    <------ linuxの場合
```

で起動してください。

<br>

## Target(ATOMCam内部)の環境

ここで作ったイメージでATOMCamを起動すると、glibcで生成されたmipsel版のlinux環境が起動します。

この環境の中で/atom以下に本来のATOMCamのシステムを起動してchroot環境に閉じ込めています。

システム構成は

- SoC: Ingenic T31 SoC

- CPU: MIPS32R5 I\$32K/D\$32K/L2\$128K
- kernel: linux 3.10.14 mipsel

です。

<br>

### 起動シーケンス

##### u-boot -> kernel内蔵のinitramfs上の/init

*initramfsの中身はinitramfs_skeleton/です。*

initramfsはkernel 起動時のcmdlineで/initを実行するようにしています。

toolsのupdateがある場合はそのための処理を実行します。

その後、SD-Card上のrootfs_hack.squashfsをrootにswitch_rootしてremountの処理を行い、/sbin/init(busybox)を起動します。

##### rootfs_hack.squashfs

*rootfs_hack.squashfsはconfigs/atomcam_defconfigの設定でbuildされたイメージにoverlay_rootfsを重ねたものになります。*

/sbin/initがinittabに従って/etc/init.d/rcSを起動して、rcSで/etc/init.d/S*を順番に実行します。
/etc/init.dを最後まで実行すると、serialを繋いでいればgettyでlogin promptが出ます。AtomCamの後ろ側のLEDが青点滅ー＞青点灯になるとsshでloginできる状態になります。

##### /etc/init.d/S31fwupdate

ATOMCamのFW updateのシーケンスが実行中の場合、処理を代行します。

##### /etc/init.d/S34mount

overlayfsが使えないので、bind mountでシステムのファイル／フォルダーの配置を入れ替えています。

##### /etc/init.d/S38atomcam

/atom/以下に本来のATOMCamのシステムと幾つかのmount-pointを共通でアクセスできるようにmountします。

その後、chrootで/atomの/tmp/system/bin/atom_init.shを呼び出します。

 ​  ここまではglibcの世界で動作しています。

##### (/atom)/tmp/system/bin/atom_init.sh

本来のATOMCamの初期化シーケンスを実行します。ここからuClibcの世界に入ります。
iCamera_appの実行時にlibcallback.soを噛ませて各種patchをあてて処理を追加しています。さらにwebHookのためにlogを名前付きFIFOファイル (/var/run/atomapp) に出力させています。

これを実行するとwatchdogが起動するため、assisとiCamera_appは止められなくなります。

recognition等の機能はiCamera_appにあるわけではなく、cloudから読み込まれて実行されているようです。



###  各種script

##### (/atom)/bin/mv, (/atom)/bin/rm

ATOMCamのiCloud_appが動体検知をcloudに送信後に削除する時のrmコマンド、１分ごとのSD-Cardへの記録ファイルを/tmpから移動するmvコマンドを置き換えてNASへの記録やwebHookのeventを送信するためのscriptです。

##### /scripts/cmd

iCamera_app内部パラメータや動作を変更するためのコマンドを実行するwrapperコマンドです。

##### /scripts/cruise.sh

AtomSwingでのクルーズ動作を実行するためのscriptです。

##### /scripts/hack_ini_reconfig.sh

Ver.upでhack_iniの互換性がない場合に引き継ぎ処理をするためのscriptです。

##### /scripts/health_check.sh

定期的にネットワークの健全性のチェックを行うscriptです。

##### /scripts/lighttpd.sh

WebUIのlighttpdの起動処理と認証の切り替え等の処理を行うscriptです。

##### /scripts/memory_check.sh

定期的にメモリーの状態をlogに記録するscriptです。

##### /scripts/motor_init

AtomSwingでモーターの初期位置動作をするscriptです。

##### /scripts/network_init.sh

networkの接続をするための初期化scriptです。

##### /scripts/reboot.sh

WebUIの定期reboot設定をcrontabで指定時間に実行するためのscriptです。

syncしてrebootを実行します。

##### /scripts/remove_old.sh

指定時間経過した録画データを削除するためのscriptです。

##### /scripts/rtspserver.sh

init.d/S58rtspserverとWebUIのRTSPのon/offから呼ばれます。

v4l2rtspserverをon/offします。

##### /scripts/samba.sh

設定に従ってSambaの起動／終了をするscriptです。

##### /scripts/set_crontab.sh

reboot.shやtimelapse.shを起動する時刻をcrontabに設定するためのscriptです。

##### /scripts/set_icamera_config.sh

iCamera_app起動直後に設定しておくべき設定値を処理するためのscriptです。

##### /scripts/timelapse.sh

timelapseの開始処理、終了時のファイル処理のscriptです。

##### /scripts/webcmd.sh

/var/www/cgi-bin/exec.cgiからnamed-FIFO経由でコマンドを実行します。

cgiの実行はwww-dataアカウントでの実行なのでシステム制御系のコマンドは直接実行できないので、コマンドを受けて実行して問題ないものだけ実行する構造にしています。

##### /scripts/webhook.sh

iCamera_appのlogを受けてwebHookのイベントを拾っています。

iCamera_appの実行環境では制限があるため、名前付きFIFO経由でlogを受けて必要に応じてcurlでpostしています。

##### /var/www/cgi-bin/cmd.cgi

WebUIからのコマンドをnamed-pipe経由でwebcmd.shに投げています。

##### /var/www/cgi-bin/get_jpeg.cgi

WebUIで表示するjpeg画像を取得しています。

##### /var/www/cgi-bin/hack_ini.cgi

WebUIで使用している設定値の取得、設定をします。

##### /var/www/cgi-bin/hello.cgi

MobileAppからのアクセス時の要求に応答するためのcgiです。

##### 

## WebUI

web/以下にWebUIのソースコードがあります。

WebUIはVue.jsとElementUIで記述しています。

Target環境はmipselなのでnode.jsの最近のバージョンは未対応になります。

そのため、frontend側のみbuildして、backend側はlighttpdとcgiで対応し、frontendからaxios経由でアクセスする構造にしています。

WebUIの画面はweb/source/vue/Setting.vueに記述しています。



## Docker環境
Docker環境では/srcがatomcam_tools/にmapされています。

以下、基本的にDocker内のコマンドは下記のDirectoryから実行します。

```shell
root@ac0375635c01:/atomtools# cd /atomtools/build/buildroot-2016.02
```

rootfsはglibc環境でDocker内のgccを使用します。
build時にgccも生成されます。
gccのprefixは
**/atomtools/build/buildroot-2016.02/output/host/usr/bin/mipsel-ingenic-linux-gnu-**
です。

ATOMCam本来のシステムのカメラアプリiCamera_appはuClibcの環境でbuildされています。

そのためiCamera_appのhack用のlibcallback.soのbuildにはuClibc環境が必要なので別途cross tools-ng-1.26.0を導入しています。

gccのprefixは

**/atomtools/build/cross/mips-uclibc/bin/mipsel-ingenic-linux-uclibc-**

です。



### 各種変更時のbuild方法

 initramfs, kernelのconfigを変更した場合

```shell
root@ac0375635c01:/atomtools# make linux-rebuild
root@ac0375635c01:/atomtools# make
```

でbuildされてatomcam_tools/targetにコピーされます。



rootfs内のファイルやbusyboxのmenuconfigを修正した場合
```shell
root@ac0375635c01:/atomtools# make
```

でbuildされてatomcam_tools/targetにコピーされます。



rootfsに含まれるpackageの変更した場合

```shell
root@ac0375635c01:/atomtools# make menuconfig
root@ac0375635c01:/atomtools# make
```

でbuildされてatomcam_tools/targetにコピーされます。



個別のpackegeのrebuildの場合

```shell
root@ac0375635c01:/atomtools# make <package>-rebuild
root@ac0375635c01:/atomtools# make
```

です。



busyboxのコマンド等の設定変更の場合

```shell
root@ac0375635c01:/atomtools# make busybox-menuconfig
root@ac0375635c01:/atomtools# make
```

でrootfsがbuildされます。



kernelの設定変更の場合

```shell
root@ac0375635c01:/atomtools# make linux-menuconfig
root@ac0375635c01:/atomtools# make linux-rebuild
root@ac0375635c01:/atomtools# make
```

でbuildされてatomcam_tools/targetにコピーされます。



