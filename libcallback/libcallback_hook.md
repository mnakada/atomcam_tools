# libcallback

iCamera_appの起動時にLD_PRELOADで読み込ませることでdynamic linkされる前にlibcallbackのhook関数が読み込まれlinkされる。

これによって内部で使用しているlibararyの関数を置き換えることができるが、libararyに出ていない関数は置き換えられないのでできることに限界はある。



### command.c

コマンドを受け付けるためのIF。

port 4000でlocalhostのみに限定してsocketで通信を待ち受けている。

各種コマンドを解釈後、それぞれのコマンド処理を呼び出し、応答を返す。



### alarm_config.c

##### commandIF

```
usage : alarmConfig <alarmType> alarmInterval [<interval>]
```

WyzeCamのみ有効。

alarmType(0~14) 毎のalarmIntervalの設定値を設定／取得する。

引数が無い場合は現在の設定値を返す。

intervalに30秒未満は設定できない、defaultが300秒なので30~300の範囲での設定が可能。

##### hook point

```c
/system/lib/libc.so.0 : void *memset(void *s, int c, size_t n)
```

alarmConfigのテーブルアドレスを取得するため、テーブル初期化しているところをhook。



### alarm_interval.c

##### commandIF

```
usage : alarm [<interval>]
```

user_configのalarmIntervalの設定値を設定／取得する。

引数が無い場合は現在の設定値を返す。

intervalに30秒未満は設定できない、defaultが300秒なので30~300の範囲での設定が可能。



### audio_callback.c

##### commandIF

```
audio [<ch>] [on|off]
```

audio chのALSA loopbackへの出力の制御。

引数が無い場合は現在の設定値を返す。



##### hook point

```c
/system/lib/liblocalsdk.so : int local_sdk_audio_set_pcm_frame_callback(int ch, void *callback)
```

audioのPCMデータを横取りするため、callback設定関数で設定されるcallback関数を置き換える処理。

置き換えたcallback関数でALSA loopbackデバイスにデータを横流しして、iCamera_appの本来のcallbackに戻る処理をする。



### audio_callback.c

##### commandIF

```
audio hpf [on|off]
audio agc [<gainLevel> <maxGain>]
audio ns [off|<level 0-3>]
audio aec [on|off]
audio vol [<volume -30-120>]
audio gain [<gain 0-31>]
audio alc [<alc 0-7>]
```

各種soundの設定。

基本的には引数をつけなければ現在の設定値を返す。

パラメータの意味するところはよくわからないものもある。

audio hpfはHighPassFilterのon/off。

audio agcはAutoGainControlの設定。

audio nsはNoiseSuppressionの設定。

audio aecはエコーキャンセルのon/off。

audio volはボリューム設定。

audio gainは入力ゲイン調整の設定。

audio alcはよくわからない。



### audio_play.c

```
aplay <wav file> [<volume -30-120:default 40>]
```

指定されたwavファイルをスピーカーから再生する。

wavファイルは8Ksampleのデータのみ対応。



### curl.c

#####  commandIF

```
curl debug [on|off]
curl upload [disable|enable]
```

iCamera_appがサーバーにalarm videoをpostするのを制御する。

引数が無い場合は現在の設定値を返す。

curl debugはiCamera_appがcurlで通信している内容を表示する機能のon/offの設定。

curl uploadはiCamera_appがalarm videoをuploadする事を許可するかどうかの設定。

##### hook point

```C
/thirdlib/libcurl.so : CURLcode curl_easy_perform(struct SessionHandle *data)
```

動体検知の周期を短縮した時にサーバーに頻繁にuploadしないように５分間以内の場合の棄却処理。

サーバーへの検知動画のuploadを停止した場合の棄却処理を行う。

棄却処理は単純に捨ててしまうとエラーになってしまうため、それらしい応答を返してうまく処理する必要がある。



### freopen.c

##### hook point

```c
/lib/libc.so.0 : FILE *freopen(const char *pathname, const char *mode, FILE *stream)
```

stdoutの情報からhookを掛けるため、iCamera_appがstdoutの出力を止める処理をしているところを回避。



### gmtime_r.c

##### hook point

```C
/lib/libc.so.0 : struct tm *gmtime_r(const time_t *timep, struct tm *result)
```

AtomCamSwingでカメラを動かすと動体検知が反応するため、動かしている間は存在しない曜日を返すことでAIプロセスを無効にする。

ここはiCamera_appの実装に依存しているので、コードが変わると効かなくなる可能性がある。



### jpeg.c

#####  commandIF

```
jpeg [<ch:default 0>] [-n]
```

指定されたvideo chのjpegデータを返す。

-nを指定しない場合、httpのres headerをつけて返す。

-nを指定した場合、生のjpegデータを返す。



### mmc_format.c

##### hook point

```C
/system/lib/liblocalsdk.so : int local_sdk_device_mmc_format()	
```

SD-Cardをformatしないように何もせずに戻る。



### mmc_mount.c

##### hook point

```C
/system/lib/liblocalsdk.so : int local_sdk_device_open(int id, char *buf)
```

既にtoolsでmountされているのにiCamera_appがSD-Cardを二重にmountしてきてFileSystemがおかしくなるので、/media/mmcをmountさせないようにする。



### motor.c

##### commandIF

```
move [<pan 0-355> <tilt 0-180>] [<speed 0-9:default 9>] [<priority 0-3:default 2>]
```

AtomCamSwingでpan/tiltの向きを変更／取得する。

引数が無い場合は現在の位置とhflip, vflipを返す。

pan, tiltを指定した場合、その方向まで向きを変える。

移動している間は次の移動コマンドはエラーになる。

移動し終わるとpan, tilt, flip, vflipの値を返す。



### mp4write.c

##### commandIF

```
mp4write [sd|ram sd|ram]
```

record、alarmのvideoの一時書き込み場所をSD-CardにするかRAMDiskにするかを指定する。

defaultはRAMDisk。

引数のない場合は現在の設定値を返す。

1番めの引数はrecord(１分ごとの定期的なvideo)についての設定。

2番目の引数はalarm(動体検知でのvideo)についての設定。

##### hook point

```C
/system/lib/libmp4rw.so : int mp4write_start_handler(void *handler, char *file, struct Mp4StartConfig *config)
```

alarmかrecordのファイルを/tmp/のRAMDiskに作成してからSD-Cardに移動するのがiCamera_appの標準動作。

これを直接SD-Cardの/media/mmc/tmp/に記録して、同じファイルシステム内で移動するこで負荷を低減させる処理。



### night_light.c

##### commandIF

```
night [on|off|auto]
```

night lightのon/off/自動の切り替え設定。



### opendir.c

##### hook point

```C
/lib/libc.so.0 : DIR *opendir(const char *pathname)
```

iCamera_appのtimelapseの記録イベントを検知してstdoutにwebhook用のメッセージを出力する。

iCamera_appのtimelapseのWebHookを使わないなら不要。



### remove.c

##### hook point

```C
/lib/libc.so.0 : int remove(const char *pathname)
```

iCamera_appのtimelapseの完了イベントを検知してstdoutにwebhook用のメッセージを出力する。

iCamera_appのtimelapseのWebHookを使わないなら不要。



### setlinebuf.c

iCamera_appのstdout出力がバファリングされるため、lineごとに出力するように設定。

イベント検知のために使用。



### timelapse.c

##### commandIF

```
timelapse [<filename> <interval> <numOfTimes> <fps>]
timelapse stop
timelapse restart
timelapse close
timelapse mp4 <filename>
```

timelapse videoを録画する。

引数無しは現在の記録状態を返す。

最終的にinterval間隔でnumOfTimes回のフレームをfpsのフレームレートで再生されるfilenameで指定したmp4ファイルを作成するが、開始時は同名の拡張子が_mp4, stszの名前の中間ファイルを生成する。

stopは記録を停止する。

restartはstopした記録を再開する。

closeは記録を停止してmp4ファイルを生成する。

mp4は停止していて中間ファイルが残った状態のものをmp4ファイルに変換する。



### usb_power.c

iCamera_appからのUSB VBUS制御を無視する。



### user_config.c

##### commandIF

```
config <name> [<value>]
```

iCamera_app内部のuser_configの値の取得と設定。

valueを指定しなければそのnameの値を取得する。

valueを指定した場合はそのnameの値にvalueを設定する。

ただし、ファイルへの書き出しはされないため別途ファイルに書く必要がある。

変更している値の意味を理解した上で使用する事。

##### hook point

```C
/lib/libc.so.0 : int strncmp(const char *s1, const char *s2, size_t size)
```

iCamera_appの内部変数のget/setをするために内部変数テーブルのポインタを取得する。

Get/SetUserConfig()でget/setするが、setで/atom/config/.user_configファイルは変更されないので恒久化するには別途更新する必要がある。



### video_callback.c

##### commandIF

```
video [<ch:default 0>] [on|off]
```

v4l2loopbackの各chのvideoのcaptureのon/off。

引数無し、chのみ指定の場合は現在の設定値を返す。

##### hook point

```C
/system/lib/liblocalsdk.so : int local_sdk_video_set_encode_frame_callback(int sch, void *callback) 
```

VideoのH264/265 frameを横取りするため、callback設定関数で設定されるcallback関数を置き換える処理。

置き換えたcallback関数でv4l2loopbackデバイスにデータを横流しして、iCamera_appの本来のcallbackに戻る処理をする。



### video_control.c

##### commandIF

```
video flip [normal/flip/mirror/flip_mirror]
video cont 0 - 255(center:128)
video bri 0 - 255(center:128)
video sat 0 - 255(center:128)
video sharp 0 - 255(center:128)
video sinter 0 - 255(center:128)
video temper 0 - 255(center:128)
video aecomp 0 - 255
video aeitmax 0-
video dpc 0 - 255
video drc 0 - 255
video hilight 0 - 10
video again 0 -
video dgain 0 -
video expr manual|auto <time>
video bitrate <ch> 10-3000(kbps)|auto
video fps <ch> 1-30(fps)|auto
```

videoの各種パラメータ設定。よくわからないものもある。

引数無しの場合は現在の設定値を表示する。

video flipは画面の上下左右の反転。

video contはコントラスト設定。

video briはブライトネス設定。

video satはサチュレーション設定。

video sharpはシャープネス設定。

video aecompは自動露出設定。

video aeitmaxは自動露出関連、よくわからない。

video dpc,drc,hilight,again, dgainこのあたりもよくわからない。

video exprは露出設定のauto/manualの切り替えだけど、manualだと安定しない。

video bitrate, fpsはH264/H265のvbrのbitrateとフレームレート設定。

##### hook point

```c
/system/lib/liblocalsdk.so : int local_sdk_video_set_kbps(int ch, int kbps)
```

```c
/system/lib/liblocalsdk.so : int local_sdk_video_set_fps(int ch, int kbps)
```

```c
/system/lib/libimp.so : int IMP_Encoder_CreateChn(int ch, unsigned char *attr)
```

Videoの BitRate, FrameRate, GOPの設定をユーザー設定値に変更する処理。

IMP_Encoder_CreateChnで最初に設定されたGOPとfpsは最大値に設定されるため、以降でこの値以上の値を設定することはできない。

また、GOPはfpsで割り切れる必要がある。

### wait_motion.c

##### commandIF

```
waitMotion [<timeout>] 
```

動体検知の状態が変化するのを待つ。

timeoutを指定しないと待ち続ける。

検知した場合、```detect <left> <right> <top> <bottom> <pan> <tilt>```の値を返す。

検知が外れた場合、```clear```を返す。

##### hook point

```
/system/lib/liblocalsdk.so : int local_sdk_video_osd_update_rect(int ch, int display, struct RectInfoSt *rectInfo)
```

AtomCamSwingでiCamera_appの動体検知の枠描画から追尾目標を計算して返す処理。