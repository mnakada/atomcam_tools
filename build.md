# SD-Cardイメージのbuild方法

## 必要なbuild環境

- Window / MacOS / Linux

- githubへのアクセスできる環境

- Dockerの実行環境

  

※ 以下MacOS Montereyで確認しています。



## build方法

適当なdirectoryで下記を実行します。

```shell
# git clone atomcam_tools
# cd atomcam_tools
# ./make.sh
```

環境に依存しますが１時間程度でatomcam_tools.zipが出来上がります。

zipの中身は

- authorized_keys
- hostname
- factory_t31_ZMC6tiIDQN
- rootfs_hack.ext2

で、atomcam_tools/ 以下に出来ているものと同じです。

remote loginするなら、sshのpublic.keyをauthorized_keysに追加してください。

```shell
# cat ~/.ssh/id_rsa.pub >> ./authorized_keys
```

デバイス名を変更するなら、hostnameを修正してください。(default : atomcam)

```shell
# echo "hogehoge" > ./hostname
```

上記４つのファイルをSD-CardにコピーしてAtomCamに入れて起動します。

初回起動時はswap fileの作成とsshのhost-keyを作成するのに少し時間がかかるので40秒程度かかります。

build環境は一度buildするとdocker上にコンテナが起動した状態になっています。

```shell
# docker-compose exec builder bash
```

でコンテナに入れます。
dockerコンテナが落ちてるときは

```shell
# docker-compose up -d
```

で起動してください。



## Target(ATOMCam内部)の環境

ここで作ったイメージでATOMCamを起動すると、glibcで生成されたmipsel版のlinux環境が起動します。

この環境の中で/atom以下に本来のATOMCamのシステムを起動してchroot環境に閉じ込めています。

システム構成は

- SoC: Ingenic T31 SoC

- CPU: MIPS32R5 I\$32K/D\$32K/L2\$128K
- kernel: linux 3.10.14 mipsel

です。

WiFiはatom側のシステムが起動しているので、rootfs側は起動していません。



### 起動シーケンス

##### u-boot -> kernel内蔵のinitramfs上の/init_atomcam

​	*initramfsの中身はconfigs/overlay_initramfs/です。。*

　initramfsはkernel 起動時のcmdlineで/initを実行するようにしています。

​	この中でSD-Card上のrootfs_hack.ext2をrootにswitch_rootして、/sbin/init(busybox)を起動します。

##### rootfs_hack.ext2

　*rootfs_hack.ext2はconfigs/rootfs.configの設定でbuildされたイメージにconfigs/overlay_rootfsを重ねたものになります。*

​	/sbin/initがinittabに従って/etc/init.d/rcSを起動して、rcSで/etc/init.d/S*を順番に実行します。

　S35wifiはAtomCamのシステム側で処理しているので実行しないほうが良いのですが、wifiパッケージを入れると起動スクリプトが入るため、config/overlay_rootfsで中身の無いものを上書きして無効にしています。
	/etc/init.dを最後まで実行すると、serialを繋いでいればgettyでlogin promptが出ます。AtomCamの後ろ側のLEDが青点滅ー＞青点灯になるとsshでloginできる状態になります。

​	途中でATOMCamのシステムを起動する環境を整える/etc/init.d/S38atomcamを呼び出しています。

##### S38atomcam

​	/atom/以下に本来のATOMCamのシステムと幾つかのmount-pointを共通でアクセスできるようにmountします。また、hackのために/tmp/system/bin/にscriptをコピーしています。

​	その後、chrootで/atomの/tmp/system/bin/atom_init.shを呼び出します。

 ​  ここまではglibcの世界で動作しています。

##### atom_init.sh

​	本来のATOMCamの初期化シーケンスを実行します。ここからuClibcの世界に入ります。
​	iCamera_appの実行時にlibcallback.soを噛ませて映像の横流しとwebHookのためのctorsへのsetlinebufの設定をしています。さらにwebHookのためにlogを/tmp/log/に出力させています。

​	これを実行するとwatchdogが起動するため、assisとiCamera_appは止められなくなります。

　iCamera_appは起動すると/configsの設定情報を読み込んで、wifiの起動、時刻の設定が行なっています。

　ただし、外部コマンドは直接iCamera_appで実行されるのではなくassisにメッセージ通信経由で投げてassisが実行しています。

　また、recognition等の機能はiCamera_appにあるわけではなく、cloudから読み込まれて実行されているようです。



###  各種script

##### /scripts/mv.sh, /scripts/rm.sh

​	ATOMCamのiCloud_appが動体検知をcloudに送信後に削除する時のrmコマンド、１分ごとのSD-Cardへの記録ファイルを/tmpから移動するmvコマンドを置き換えてNASへの記録やwebHookのeventを送信するためのscriptです。起動時に/tmp/system/bin/rm, mvにコピーしています。

​	iCound_appからmessage経由で外部コマンドを実行するassisの起動時のPATHの先頭に/tmp/system/binを挿入することでrm, mvコマンドを置き換えています。

##### /scripts/reboot.sh

​	WebUIの定期reboot設定をcrontabで指定時間に実行するためのscriptです。

​	syncしてrebootを実行します。

##### /scripts/rtspserver.sh

​	init.d/S58rtspserverとWebUIのRTSPのon/offから呼ばれます。

​	v4l2rtspserverをon/offします。

##### /scripts/webcmd.sh

​	/var/www/cgi-bin/exec.cgiからnamed-FIFO経由でコマンドを実行します。

​	cgiの実行はwww-dataアカウントでの実行なのでシステム制御系のコマンドは直接実行できないので、コマンドを受けて実行して問題ないものだけ実行する構造にしています。

##### /scripts/webhook.sh

​	iCamera_appのlogを受けてwebHookのイベントを拾っています。

　iCamera_appの実行環境は制限があるため、logを一旦/tmp/log/atomcam.logに記録して、そのlogをここで受けてパースしてcurlでpostしています。

　iCamera_appの出力をそのまま/tmp/log/atomcam.logにpipeで出力するとbufferされて遅延するため、libcallback.soにConstructorのhookを入れてsetlinebufでlineごとのbufferingに変更しています。

##### /var/www/cgi-bin/exec.cgi

​	WebUIからのコマンドをnamed-pipe経由でwebcmd.shに投げています。

##### /var/www/cgi-bin/get_jpeg.cgi

​	WebUIで表示するjpeg画像を取得しています。

##### /var/www/cgi-bin/get_time.cgi

​	WebUIで表示するATOMCamの時刻を1秒ごとに取得しています。

##### /var/www/cgi-bin/hack_ini.cgi

​	WebUIで使用している設定値の取得、設定をします。



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
root@ac0375635c01:/openmiko# cd /openmiko/build/buildroot-2016.02
```

rootfsはglibc環境でDocker内のgccを使用します。
build時にgccも生成されます。
gccのprefixは
**/openmiko/build/buildroot-2016.02/output/host/usr/bin/mipsel-ingenic-linux-gnu-**
です。

ATOMCam本来のシステムのカメラアプリiCamera_appはuClibcの環境でbuildされています。

そのためiCamera_appのhack用のlibcallback.soのbuildにはuClibc環境が必要なので別途cloneしている
**/openmiko/build/mips-gcc472-glibc216-64bit/bin/mips-linux-uclibc-gnu-**
を使用しています。



### 各種変更時のbuild方法

 initramfs, kernelのconfigを変更した場合

```shell
root@ac0375635c01:/openmiko# make linux-rebuild
root@ac0375635c01:/openmiko# cp output/images/uImage.lzma /src
```

でbuildされてatomcam_tools/にコピーされます。



rootfs内のファイルやbusyboxのmenuconfigを修正した場合
```shell
root@ac0375635c01:/openmiko# make
root@ac0375635c01:/openmiko# cp output/images/rootfs.ext2 /src
```

でbuildされてatomcam_tools/にコピーされます。

それぞれfactory_t31_ZMC6tiIDQN, rootfs_hack.ext2の名前でSDCardにコピーしてください。



rootfsに含まれるpackageの変更した場合

```shell
root@ac0375635c01:/openmiko# make menuconfig
root@ac0375635c01:/openmiko# make
```

でrootfsがbuildされます。



個別のpackegeのrebuildの場合

```shell
root@ac0375635c01:/openmiko# make <package>-rebuild
```

です。



busyboxのコマンド等の設定変更の場合

```shell
root@ac0375635c01:/openmiko# make busybox-menuconfig
root@ac0375635c01:/openmiko# make
```

でrootfsがbuildされます。



kernelの設定変更の場合

```shell
root@ac0375635c01:/openmiko# make linux-menuconfig
root@ac0375635c01:/openmiko# make linux-rebuild
```

でuImage.lzmaが生成されます。



