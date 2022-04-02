<template>
  <div>
    <div class="title">
      <div>
        ATOMCam Hack
        <span class="version">
          Ver.{{ config.ATOMHACKVER }}
        </span>
      </div>
      <span class="atomcam">
        {{ config.PRODUCT_MODEL }}
        Ver.{{ config.appver }}
      </span>
      <span class="timestamp">
        {{ intervalValue.TIMESTAMP }}
      </span>
      <a href="https://github.com/mnakada/atomcam_tools#atomcam_tools" target="_blank" rel="noopener">
        <i class="el-icon-info help" />
      </a>
    </div>
    <div class="well-transparent container">
      <div class="image-frame" :style="imageFrameStyle">
        <div class="image-frame-inner1">
          <ElSlider v-if="isSwing" class="tilt-slider" v-model="tilt" :min="0" :max="180" vertical :show-input-controls="false" height="100%" @change="Move" @input="Move" />
          <ElTooltip :tabindex="-1" placement="top" :content="stillFullView?'clickで縮小します':'clickで拡大します'" effect="light" :open-delay="500">
            <img class="still-image" :src="stillImage" @click="stillFullView=!stillFullView">
          </ElTooltip>
        </div>
        <div v-if="isSwing" class="image-frame-inner2">
          <ElSlider class="pan-slider" v-model="pan" :min="0" :max="355" :show-input-controls="false" @change="Move" @input="Move" />
        </div>
      </div>

      <h3>基本設定</h3>
      <SettingInput title="デバイス名" tooltip="NASの保存フォルダ名やリモートアクセスのための名前を設定します" type="text" v-model="config.HOSTNAME" />
      <SettingSwitch title="ログイン認証" tooltip="このページへのアクセスのためのログイン認証を有効にします" v-model="loginAuth" />
      <SettingInput v-if="loginAuth==='on'" title="アカウント" tooltip="ログインのためのユーザーアカウントを設定します" type="text" v-model="account" />
      <SettingInput v-if="loginAuth==='on'" title="パスワード" tooltip="ログインのためのパスワードを設定します" type="password" v-model="password" />

      <h3>録画</h3>
      <SettingSwitch title="検出通知のローカル録画" tooltip="モーション／サウンド検出したときの12秒の映像をローカルにも録画します" v-model="config.RECORDING_ALARM" />
      <SettingSwitch title="ローカル録画スケジュール" tooltip="SD-Card/NASに録画される時間帯を設定します" v-model="config.RECORDING_LOCAL_SCHEDULE" :text="['スケジュール ','常時録画 ']" @change="(config.RECORDING_LOCAL_SCHEDULE === 'on') && !schedule.length && AddSchedule()" />
      <div v-if="config.RECORDING_LOCAL_SCHEDULE === 'on'">
        <SettingSchedule v-for="(timeTable, idx) of schedule" :key="'timetable'+idx" :timeRange="true" v-model="schedule[idx]" @add="AddSchedule" @remove="DeleteSchedule(idx)" />
      </div>

      <h3>記録メディア</h3>
      <SettingSwitch title="SD-Card録画" tooltip="SD-Cardのrecordフォルダへの記録をします" v-model="storage_sdcard_record" :onOff="false" />
      <SettingSwitch title="SD-Cardモーション検知録画" tooltip="SD-Cardのalarm_recordフォルダへの記録をします" v-model="storage_sdcard_alarm" :onOff="false" />
      <SettingSwitch v-if="storage_sdcard" title="ネットワークアクセス" :titleOffset="2" tooltip="ATOMCamのSD-CardをCIFS(smb) serverとしてLAN内に公開します" v-model="config.STORAGE_SDCARD_PUBLISH" />
      <SettingInput v-if="storage_sdcard" title="保存するPATH" :titleOffset="2" :span="10" tooltip="録画するPATHをstrftimeの書式指定で記述します。最後に拡張子が付加されます。alarm_recordのみに有効" type="text" v-model="config.STORAGE_SDCARD_PATH" @input="FixPath('STORAGE_SDCARD_PATH')" />
      <SettingSwitch v-if="storage_sdcard" title="ファイルの自動削除" :titleOffset="2" tooltip="SD-Cardに録画したファイルを自動的に削除します" v-model="config.STORAGE_SDCARD_REMOVE" />
      <SettingInput v-if="storage_sdcard && config.STORAGE_SDCARD_REMOVE === 'on'" title="保存日数" :titleOffset="2" :span="3" tooltip="指定日数後に削除します" type="number" v-model="config.STORAGE_SDCARD_REMOVE_DAYS" :min="1" />
      <SettingButton v-if="storage_sdcard" title="ファイル一覧" :titleOffset="2" :span="3" tooltip="SD-Card内のファイルを表示します">
        <a href="/sdcard" target="_blank" class="el-button el-button--primary el-button--mini link-button">SD Card</a>
      </SettingButton>

      <SettingSwitch title="NAS録画" tooltip="NAS(CIFS Server)のrecordフォルダへの記録をします" v-model="storage_cifs_record" :onOff="false" />
      <SettingSwitch title="NASモーション検知録画" tooltip="NAS(CIFS Server)のalarm_recordフォルダへの記録をします" v-model="storage_cifs_alarm" :onOff="false" />
      <SettingInput v-if="storage_cifs" title="ネットワークPATH" :titleOffset="2" :span="10" tooltip="NASのパスを設定。(//server/folder/の形式で指定)" type="text" v-model="config.STORAGE_CIFSSERVER" @input="FixPath('STORAGE_CIFSSERVER')" />
      <SettingInput v-if="storage_cifs" title="アカウント" :titleOffset="2" tooltip="NASのユーザー名を設定します" type="text" v-model="config.STORAGE_CIFSUSER" />
      <SettingInput v-if="storage_cifs" title="パスワード" :titleOffset="2" tooltip="NASのパスワードを設定します" type="password" v-model="config.STORAGE_CIFSPASSWD" show-password />
      <SettingInput v-if="storage_cifs" title="保存するPATH" :titleOffset="2" :span="10" tooltip="ネットワークPATH以降の録画するPATHをstrftimeの書式指定で記述します。最後に拡張子が付加されます" type="text" v-model="config.STORAGE_CIFS_PATH" @input="FixPath('STORAGE_CIFS_PATH')" />
      <SettingSwitch v-if="storage_cifs" title="ファイルの自動削除" :titleOffset="2" tooltip="CIFS Serverに録画したファイルを自動的に削除します" v-model="config.STORAGE_CIFS_REMOVE" />
      <SettingInput v-if="storage_cifs && config.STORAGE_CIFS_REMOVE === 'on'" title="保存日数" :titleOffset="2" :span="3" tooltip="指定日数後に削除します" type="number" v-model="config.STORAGE_CIFS_REMOVE_DAYS" :min="1" />

      <h3>ストリーミング</h3>
      <SettingSwitch title="RTSP" tooltip="RTSPサーバーを起動します" v-model="config.RTSPSERVER" />
      <SettingSwitch v-if="config.RTSPSERVER === 'on'" title="音声" :titleOffset="2" tooltip="RTSPの音声を設定します" v-model="config.RTSP_AUDIO" />
      <SettingSwitch v-if="config.RTSPSERVER === 'on'" title="RTSP over HTTP" :titleOffset="2" tooltip="RTSPをHTTP経由で配信します" v-model="config.RTSP_OVER_HTTP" />
      <SettingInput v-if="config.RTSPSERVER === 'on'" title="RTSP URL" :titleOffset="2" :span="10" tooltip="VLC playerなどにURLをcopy&pasteしてください" type="readonly" v-model="RtspUrl" :min="1" />

      <h3>イベント通知</h3>
      <SettingSwitch title="WebHook" tooltip="WebHookを設定します" v-model="config.WEBHOOK" />
      <SettingInput v-if="config.WEBHOOK === 'on'" title="通知URL" :titleOffset="2" :span="10" tooltip="WebHookのイベント発生時にpostするURL" type="text" v-model="config.WEBHOOK_URL" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" title="動体検知" :titleOffset="2" tooltip="Alarm発生を通知します" v-model="config.WEBHOOK_ALARM_EVENT" comment="type: alarmEvent" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" title="動体認識情報" :titleOffset="2" tooltip="Alarm発生時に認識情報を通知します" v-model="config.WEBHOOK_ALARM_INFO" comment="type: recognitionNotify" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" title="動体検知録画終了" :titleOffset="2" tooltip="Alarm発生時に録画保存を通知します" v-model="config.WEBHOOK_ALARM_VIDEO_FINISH" comment="type: uploadVideoFinish" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" title="動体検知録画転送" :titleOffset="2" tooltip="Alarm発生時に録画ファイルを転送します" v-model="config.WEBHOOK_ALERM_VIDEO" comment="mime: video/mp4" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" title="動体検知静止画保存" :titleOffset="2" tooltip="Alarm発生時に静止画保存を通知します" v-model="config.WEBHOOK_ALARM_PICT_FINISH" comment="type: uploadPictureFinish" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" title="動体検知静止画転送" :titleOffset="2" tooltip="Alarm発生時に静止画ファイルを転送します" v-model="config.WEBHOOK_ALERM_PICT" comment="mime: image/jpeg" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" title="定常録画保存" :titleOffset="2" tooltip="録画保存を通知します" v-model="config.WEBHOOK_RECORD_EVENT" comment="type: recordEvent" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" title="タイムラプス記録" :titleOffset="2" tooltip="タイムラプスイベントを通知します" v-model="config.WEBHOOK_TIMELAPSE_EVENT" comment="type: timelapseEvent" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" title="タイムラプス録画完了" :titleOffset="2" tooltip="タイムラプス録画完了を通知します" v-model="config.WEBHOOK_TIMELAPSE_FINISH" comment="type: timelapseFinish" />

      <h3>動体検知</h3>
      <SettingSwitch title="動体検知周期の短縮" tooltip="Alarmの無検知時間5分を30秒に短縮します" v-model="config.MINIMIZE_ALARM_CYCLE" comment="※ 変更すると設定ボタンで再起動します" />

      <div v-if="isSwing" @click="ClearCruiseSelect">
        <h3>クルーズ</h3>
        <SettingSwitch title="クルーズ動作" tooltip="クルーズ軌道を設定し、巡回動作をします" v-model="config.CRUISE" @change="(config.CRUISE === 'on') && !cruiseList.length && AddCruise()" @click.native.stop />
        <div>
          <SettingCruise v-for="(cruise, idx) of cruiseList" :key="'timetable'+idx" v-model="cruiseList[idx]" :pan="pan" :tilt="tilt" :selected="cruiseSelect === idx" @add="AddCruise" @remove="DeleteCruise(idx)" @pan="pan=$event" @tilt="tilt=$event" @click="CruiseSelect(idx)" />
        </div>
      </div>

      <h3>モニタリング</h3>
      <SettingSwitch title="Ping" tooltip="Ping URL every minute" v-model="config.HEALTHCHECK" />
      <SettingInput v-if="config.HEALTHCHECK === 'on'" title="通知URL" :titleOffset="2" :span="10" tooltip="" type="text" v-model="config.HEALTHCHECK_PING_URL" />

      <h3>メンテナンス</h3>
      <SettingButton v-if="isSwing" title="Swing座標初期化" :titleOffset="2" :span="4" tooltip="Swingの座標を両側の端点当てで修正します" label="初期化" @click="MoveInit" />
      <SettingSwitch title="定期リスタート" tooltip="定期的に再起動する設定をします" v-model="config.REBOOT" />
      <SettingSchedule v-if="config.REBOOT === 'on'" v-model="reboot" @add="AddSchedule" @remove="DeleteSchedule(idx)" />
      <SettingDangerButton title="リブート" tooltip="再起動します" icon="el-icon-refresh-left" label="Reboot" @click="DoReboot" />
      <SettingDangerButton title="SD-Card消去" tooltip="SD-Cardの録画フォルダを消去します" icon="el-icon-folder-delete" label="Erase" @click="DoErase" />
      <SettingDangerButton title="Update" tooltip="このtoolのupdateをします" icon="el-icon-refresh" label="Update" :disabled="!updatable" @click="DoUpdate">
        <span class="latest" :class="{ 'latest-updatable': updatable }">
          Latest Version : Ver.{{ latestVer }}
        </span>
      </SettingDangerButton>
    </div>
    <ElRow class="submit">
      <ElCol :offset="20" :span="4">
        <ElButton @click="Submit" type="primary" :disabled="stillFullView">設定</ElButton>
      </ElCol>
    </ElRow>
    <ElDrawer title="設定中" :visible.sync="executing" direction="btt" :show-close="false" :wrapperClosable="false">
      <h4 class="comment">設定変更中。暫くお待ち下さい。</h4>
    </ElDrawer>
    <ElDrawer title="再起動中" :visible.sync="rebooting" direction="btt" :show-close="false" :wrapperClosable="false">
      <h4 class="comment">起動するまで暫くお待ち下さい。(約{{ rebootTime }}秒)</h4>
    </ElDrawer>
  </div>
</template>

<script>
  import axios from 'axios';
  import md5 from 'js-md5';
  import { Tooltip, Drawer, Slider } from 'element-ui';
  import SettingSwitch from './SettingSwitch.vue';
  import SettingInput from './SettingInput.vue';
  import SettingButton from './SettingButton.vue';
  import SettingDangerButton from './SettingDangerButton.vue';
  import SettingSchedule from './SettingSchedule.vue';
  import SettingCruise from './SettingCruise.vue';

  import 'element-ui/lib/theme-chalk/tooltip.css';
  import 'element-ui/lib/theme-chalk/drawer.css';
  import 'element-ui/lib/theme-chalk/slider.css';

  export default {
    name: 'ATOMCamSetting',
    components: {
      ElTooltip: Tooltip,
      ElDrawer: Drawer,
      ElSlider: Slider,
      SettingSwitch,
      SettingInput,
      SettingButton,
      SettingDangerButton,
      SettingSchedule,
      SettingCruise,
    },
    data() {
      return {
        config: {
          appver: '', // ATOMCam app_ver (/atom/config/app.ver)
          ATOMHACKVER: '', // AtomHack Ver (/etc/atomhack.ver)
          PRODUCT_MODEL: '', // ATOMCam Model (/atom/configs/.product_config)
          HOSTNAME: 'atomcam', // ATOMHack hostname (/media/mmc/hostname)
          DIGEST: '',
          REBOOT: 'off',
          REBOOT_SCHEDULE: '0 2 * * 7', // -> /var/spool/crontabs/root
          RECORDING_ALARM: 'on',
          RECORDING_LOCAL_SCHEDULE: 'off',
          RECORDING_LOCAL_SCHEDULE_LIST: '', // -> /media/mmc/local_schedule
          RTSPSERVER: 'off',
          RTSP_OVER_HTTP: 'off',
          RTSP_AUDIO: 'off',
          STORAGE_SDCARD: 'on', // on(alarm & record), alarm, record, off
          STORAGE_SDCARD_PUBLISH: 'off',
          STORAGE_SDCARD_PATH: '%Y%m%d/%H%M%S',
          STORAGE_SDCARD_REMOVE: 'off',
          STORAGE_SDCARD_REMOVE_DAYS: 30,
          STORAGE_CIFS: 'off', // on(alarm & record), alarm, record, off
          STORAGE_CIFS_PATH: '%Y%m%d/%H%M%S',
          STORAGE_CIFS_REMOVE: 'off',
          STORAGE_CIFS_REMOVE_DAYS: 30,
          STORAGE_CIFSSERVER: '',
          STORAGE_CIFSUSER: '',
          STORAGE_CIFSPASSWD: '',
          WEBHOOK: 'off',
          WEBHOOK_URL: '',
          WEBHOOK_ALARM_EVENT: 'off',
          WEBHOOK_ALARM_INFO: 'off',
          WEBHOOK_ALARM_VIDEO_FINISH: 'off',
          WEBHOOK_ALERM_VIDEO: 'off',
          WEBHOOK_ALARM_PICT_FINISH: 'off',
          WEBHOOK_ALERM_PICT: 'off',
          WEBHOOK_RECORD_EVENT: 'off',
          WEBHOOK_TIMELAPSE_EVENT: 'off',
          WEBHOOK_TIMELAPSE_FINISH: 'off',
          CRUISE: 'off',
          CRUISE_LIST: '',
          MINIMIZE_ALARM_CYCLE: 'off',
          HEALTHCHECK: 'off',
          HEALTHCHECK_PING_URL: '',
        },
        loginAuth: 'off',
        loginAuth2: 'off',
        relm: 'atomcam',
        account: '',
        password: '',
        intervalValue: {
          TIMESTAMP: '',
        },
        storage_sdcard_record: true,
        storage_sdcard_alarm: true,
        storage_cifs_record: false,
        storage_cifs_alarm: false,
        schedule: [],
        cruiseList: [],
        cruiseSelect: -1,
        reboot: {
          startTime: '02:00',
          endTime: '02:00',
          dayOfWeekSelect: ['日'],
        },
        rebootTime: 80,
        latestVer: '',
        executing: false,
        rebooting: false,
        stillImage: null,
        stillFullView: false,
        weekDays: ['月','火', '水', '木', '金', '土', '日'],
        pan: 0,
        tilt: 0,
        posValid: false,
      };
    },
    computed: {
      stillInterval() {
        return this.stillFullView ? 500 : 1000;
      },
      imageFrameStyle() {
        return this.stillFullView ? { right: '10px', width: '98%' } : { right: '30px', width: '30%' };
      },
      storage_sdcard() {
        return this.storage_sdcard_record || this.storage_sdcard_alarm;
      },
      storage_cifs() {
        return this.storage_cifs_record || this.storage_cifs_alarm;
      },
      updatable() {
        const ver = this.config.ATOMHACKVER.split('.');
        if(ver.length !== 3) return false;
        const latest = this.latestVer.split('.');
        if(latest.length !== 3) return false;
        if(parseInt(ver[0]) < parseInt(latest[0])) return true;
        if(parseInt(ver[0]) > parseInt(latest[0])) return false;
        if(parseInt(ver[1]) < parseInt(latest[1])) return true;
        if(parseInt(ver[1]) > parseInt(latest[1])) return false;
        if(parseInt(ver[2]) < parseInt(latest[2])) return true;
        return false;
      },
      isSwing() {
        return !this.rebooting && this.posValid && (this.config.PRODUCT_MODEL === 'ATOM_CAKP1JZJP');
      },
      RtspUrl() {
        const port = (this.config.RTSP_OVER_HTTP  === 'on') ? 8080 : 8554;
        return `rtsp://${window.location.host}:${port}/unicast`;
      },
    },
    async mounted() {
      const res = await axios.get('./cgi-bin/hack_ini.cgi').catch(err => {
        // eslint-disable-next-line no-console
        console.log(err);
        return '';
      });

      this.oldConfig = res.data.split('\n').reduce((d, l) => {
        const name = l.split(/[ \t=]/)[0].trim();
        if(d[name] != null) d[name] = l.replace(new RegExp(name + '[ \t=]*'), '').trim();
        return d;
      }, Object.assign({}, this.config));
      this.config = Object.assign({}, this.oldConfig);
      // eslint-disable-next-line no-console
      console.log(this.config);

      if(this.config.DIGEST.length) {
        this.loginAuth = 'on';
        this.account = this.config.DIGEST.replace(/:.*$/, '');
      }

      if(this.config.STORAGE_SDCARD === 'on') {
        this.storage_sdcard_record = true;
        this.storage_sdcard_alarm = true;
      } else if(this.config.STORAGE_SDCARD === 'record') {
        this.storage_sdcard_record = true;
        this.storage_sdcard_alarm = false;
      } else if(this.config.STORAGE_SDCARD === 'alarm') {
        this.storage_sdcard_record = false;
        this.storage_sdcard_alarm = true;
      } else {
        this.storage_sdcard_record = false;
        this.storage_sdcard_alarm = false;
      }

      if(this.config.STORAGE_CIFS === 'on') {
        this.storage_cifs_record = true;
        this.storage_cifs_alarm = true;
      } else if(this.config.STORAGE_CIFS === 'record') {
        this.storage_cifs_record = true;
        this.storage_cifs_alarm = false;
      } else if(this.config.STORAGE_CIFS === 'alarm') {
        this.storage_cifs_record = false;
        this.storage_cifs_alarm = true;
      } else {
        this.storage_cifs_record = false;
        this.storage_cifs_alarm = false;
      }

      if(this.config.RECORDING_LOCAL_SCHEDULE_LIST) {
        let index = -1;
        this.schedule = this.config.RECORDING_LOCAL_SCHEDULE_LIST.split(';').reduce((d, l) => {
          if(l.search(/\[index_.*\]/) >= 0) {
            index = l.replace(/^.*_(\d*).*$/, '$1') - 1;
            d[index] = {};
            return d;
          }
          const ll = l.split(/=/);
          if(ll[0] === 'Rule') {
            d[index].dayOfWeekSelect = [];
            this.weekDays.forEach((l, i) => (ll[1] & (2 << i)) && d[index].dayOfWeekSelect.push(l));
          }
          if(ll[0] === 'ContinueTime') d[index].continueTimeNum = parseInt(ll[1]);
          if(ll[0] === 'StartTime') d[index].startTimeNum = parseInt(ll[1]);
          if((d[index].continueTimeNum != null) && (d[index].startTimeNum != null)) {
            d[index].startTime = parseInt(d[index].startTimeNum / 60).toString().padStart(2, '0') + ':' + (d[index].startTimeNum % 60).toString().padStart(2, '0');
            const endTime = d[index].startTimeNum + d[index].continueTimeNum - 1;
            d[index].endTime = parseInt(endTime / 60).toString().padStart(2, '0') + ':' + (endTime % 60).toString().padStart(2, '0');
            delete(d[index].continueTimeNum);
            delete(d[index].startTimeNum);
          }
          return d;
        }, []);
      }

      this.cruiseList = (this.config.CRUISE_LIST || '').split(';').reduce((array, cmd) => {
        const args = cmd.trim().split(' ');
        if(args[0] === 'move') {
          array.push({
            pan: parseInt(args[1]),
            tilt: parseInt(args[2]),
          });
          return array;
        }
        const last = array[array.length - 1];
        if(!last) return array;
        if(['detect', 'follow', 'sleep'].indexOf(args[0]) < 0) return array;
        last.wait = parseInt(args[1]);
        last.timeout = parseInt(args[2]);
        last.detect = true;
        last.follow = true;
        if(args[0] === 'follow') return array;
        last.follow = false;
        if(args[0] === 'detect') return array;
        last.detect = false;
        return array;
      }, []);

      const status = (await axios.get('./cgi-bin/cmd.cgi').catch(err => {
        // eslint-disable-next-line no-console
        console.log(err);
        return { data: '' };
      })).data.split('\n').reduce((s, d) => {
        s[d.replace(/=.*$/, '').trim()] = d.replace(/^.*=/, '').trim();
        return s;
      }, {});

      this.latestVer = status.LATESTVER;
      const pos = status.MOTORPOS.split(' ');
      this.pan = Math.round(parseFloat(pos[0]));
      this.tilt = Math.round(parseFloat(pos[1]));
      this.posValid = true;

      if(this.config.REBOOT_SCHEDULE) {
        const str = this.config.REBOOT_SCHEDULE.split(' ');
        const days = (str[4] || '').split(':');
        this.reboot.startTime = `${str[1].padStart(2, '0')}:${str[0].padStart(2, '0')}`;
        this.reboot.dayOfWeekSelect = days.map(d => this.weekDays[(parseInt(d) + 6) % 7]);
      }

      setInterval(async () => {
        const res = await axios.get('./cgi-bin/cmd.cgi?name=time').catch(err => {
          // eslint-disable-next-line no-console
          console.log(err);
          return '';
        });
        if(res === '') return;
        if(this.rebootStart && (new Date() > this.rebootStart)) {
          this.rebooting = false;
          this.rebootStart = null;
          location.reload();
        }
        this.intervalValue = res.data.split('\n').reduce((d, l) => {
          const name = l.split(/[ \t=]/)[0].trim();
          if(name) d[name] = l.replace(new RegExp(name + '[ \t=]*'), '').trim();
          return d;
        }, {});
      }, 1000);
      this.StillImageInterval();
      if(this.isSwing) this.GetPosInterval();
    },
    methods: {
      async Move() {
        if(!this.posValid) return;
        this.moving = true;
        await this.Exec(`move ${this.pan} ${this.tilt}`, 'socket');
        this.moving = false;
        this.moved = true;
        this.StillImageInterval();
        if(this.moveTimeout) clearTimeout(this.moveTimeout);
        this.moveTimeout = setTimeout(() => {
          this.moveTimeout = null;
          this.Exec('posrec');
        }, 3000);
      },
      async GetPosInterval() {
        if(!this.moving) {
          const status = (await axios.get('./cgi-bin/cmd.cgi?name=move').catch(err => {
            // eslint-disable-next-line no-console
            console.log(err);
            return { data: '' };
          })).data.split('\n').reduce((s, d) => {
            s[d.replace(/=.*$/, '').trim()] = d.replace(/^.*=/, '').trim();
            return s;
          }, {});
          if(status.MOTORPOS) {
            const pos = status.MOTORPOS.split(' ');
            const pan = Math.round(parseFloat(pos[0]));
            const tilt = Math.round(parseFloat(pos[1]));
            if(this.moved) {
              this.moved = false;
              if((pan !== this.pan) || (tilt !== this.tilt)) this.Move();
            } else {
              this.pan = pan;
              this.tilt = tilt;
            }
          }
        }
        if(this.getposTimeout) clearTimeout(this.getposTimeout);
        this.getposTimeout = setTimeout(this.GetPosInterval.bind(this), 1000);
      },
      async StillImageInterval() {
        const image = await axios.get('./cgi-bin/get_jpeg.cgi', { responseType: 'arraybuffer' }).catch(err => {
          // eslint-disable-next-line no-console
          console.log(err);
        });
        if(image && image.data) this.stillImage = window.URL.createObjectURL(new Blob([image.data]));
        if(this.imageTimeout) clearTimeout(this.imageTimeout);
        this.imageTimeout = setTimeout(this.StillImageInterval.bind(this), this.stillInterval);
      },
      AddSchedule() {
        this.schedule.push({
          allDay: true,
          startTime: '00:00',
          endTime: '23:59',
          dayOfWeekSelect: this.weekDays.concat(),
        });
      },
      DeleteSchedule(i) {
        this.schedule.splice(i, 1);
        if(!this.schedule.length) this.config.RECORDING_LOCAL_SCHEDULE = false;
      },
      AddCruise() {
        this.cruiseList.push({
          pan: this.pan,
          tilt: this.tilt,
          wait: 10,
          timeout: 10,
          detect: false,
          follow: false,
        });
        this.cruiseSelect = this.cruiseList.length - 1;
      },
      DeleteCruise(i) {
        this.cruiseList.splice(i, 1);
        if(!this.cruiseList.length) this.config.CRUISE = false;
        if(this.cruiseSelect === i) this.cruiseSelect = -1;
      },
      CruiseSelect(idx) {
        this.cruiseSelect = idx;
        this.pan = this.cruiseList[idx].pan;
        this.tilt = this.cruiseList[idx].tilt;
      },
      ClearCruiseSelect() {
        this.cruiseSelect = -1;
      },
      FixPath(label) {
        this.config[label] = this.config[label].replace(/\\/g, '/');
      },
      MoveInit() {
        this.Exec('moveinit');
      },
      DoReboot() {
        this.rebootTime = 80;
        this.rebooting = true;
        this.rebootStart = new Date();
        this.rebootStart.setSeconds(this.rebootStart.getSeconds() + 30);
        this.Exec('reboot');
      },
      DoErase() {
        this.executing = true;
        this.Exec('sderase');
        this.executing = false;
      },
      async DoUpdate() {
        this.rebootTime = 180;
        this.rebooting = true;
        this.rebootStart = new Date();
        this.rebootStart.setSeconds(this.rebootStart.getSeconds() + 180);
        await this.Exec('update');
        this.rebootStart = new Date();
        this.rebootStart.setSeconds(this.rebootStart.getSeconds() + 30);
      },
      async Submit() {
        if((this.loginAuth === 'on') && this.account.length) {
          if(this.password.length) {
            this.config.DIGEST = `${this.account}:${this.relm}:` + md5(`${this.account}:${this.relm}:${this.password}`);
          }
        } else {
          this.config.DIGEST='';
        }

        let str = '';
        for(const i in this.schedule) {
          const timeTable = this.schedule[i];
          str += `[index_${(i - 0 + 1).toString().padStart(2, '0')}];`;
          const val = this.weekDays.reduce((v, l, j) => v |= timeTable.dayOfWeekSelect.indexOf(l) >= 0 ? 2 << j : 0, 0);
          str += `Rule=${val};`;
          const stime = parseInt(timeTable.startTime.slice(0, 2)) * 60 + parseInt(timeTable.startTime.slice(-2));
          const etime = parseInt(timeTable.endTime.slice(0, 2)) * 60 + parseInt(timeTable.endTime.slice(-2)) + 1;
          str += `ContinueTime=${etime - stime};`;
          str += `StartTime=${stime};`;
          str += `Status=1;`;
          str += `DelFlags=1;`;
        }
        this.config.RECORDING_LOCAL_SCHEDULE_LIST = str;

        if(this.storage_sdcard_record && this.storage_sdcard_alarm) {
          this.config.STORAGE_SDCARD = 'on';
        } else if(this.storage_sdcard_record) {
          this.config.STORAGE_SDCARD = 'record';
        } else if(this.storage_sdcard_alarm) {
          this.config.STORAGE_SDCARD = 'alarm';
        } else {
          this.config.STORAGE_SDCARD = 'off';
        }
        if(!this.storage_sdcard) this.config.STORAGE_SDCARD_PUBLISH = "off";

        if(this.storage_cifs_record && this.storage_cifs_alarm) {
          this.config.STORAGE_CIFS = 'on';
        } else if(this.storage_cifs_record) {
          this.config.STORAGE_CIFS = 'record';
        } else if(this.storage_cifs_alarm) {
          this.config.STORAGE_CIFS = 'alarm';
        } else {
          this.config.STORAGE_CIFS = 'off';
        }

        this.config.CRUISE_LIST = this.cruiseList.reduce((str, cruise) => {
          str += `move ${cruise.pan} ${cruise.tilt};`;
          const waitMode = cruise.detect ? (cruise.follow ? 'follow' : 'detect') : 'sleep';
          str += `${waitMode} ${cruise.wait} ${cruise.timeout};`;
          return str;
        }, '');
        this.ClearCruiseSelect();

        str = parseInt(this.reboot.startTime.slice(-2)) + ' ';
        str += parseInt(this.reboot.startTime.slice(0, 2)) + ' * * ';
        str += this.weekDays.flatMap((v, i) => this.reboot.dayOfWeekSelect.indexOf(v) < 0 ? [] : [(i + 1) % 7]).sort((a, b) => a - b).reduce((s, d) => s += (s.length ? ':' : '') + d.toString() , '');
        this.config.REBOOT_SCHEDULE = str;

        await axios.post('./cgi-bin/hack_ini.cgi', this.config).catch(err => {
          // eslint-disable-next-line no-console
          console.log(err);
        });

        const execCmds = [];
        let href = null;
        if(this.config.REBOOT_SCHEDULE !== this.oldConfig.REBOOT_SCHEDULE) {
          execCmds.push(`scheduleReboot ${this.config.REBOOT_SCHEDULE}`);
        }
        if(this.config.HOSTNAME !== this.oldConfig.HOSTNAME) {
          execCmds.push(`hostname ${this.config.HOSTNAME}`);
          if(window.location.host === `${this.oldConfig.HOSTNAME}.local`) {
            href = `http://${this.config.HOSTNAME}.local`;
          }
        }
        if(this.config.MINIMIZE_ALARM_CYCLE !== this.oldConfig.MINIMIZE_ALARM_CYCLE) {
          execCmds.push(`reboot`);
          this.rebooting = true;
          this.rebootStart = new Date();
          this.rebootStart.setSeconds(this.rebootStart.getSeconds() + 30);
        } else {
          if((this.config.RTSPSERVER !== this.oldConfig.RTSPSERVER) && (this.config.RTSPSERVER === "off")) {
            execCmds.push(`rtspserver ${this.config.RTSPSERVER}`);
          }
          if(this.config.STORAGE_SDCARD_PUBLISH !== this.oldConfig.STORAGE_SDCARD_PUBLISH) {
            execCmds.push(`samba ${this.config.STORAGE_SDCARD_PUBLISH}`);
          }
          if(((this.config.RTSPSERVER !== this.oldConfig.RTSPSERVER) ||
              (this.config.RTSP_AUDIO !== this.oldConfig.RTSP_AUDIO) ||
              (this.config.RTSP_OVER_HTTP !== this.oldConfig.RTSP_OVER_HTTP)) &&
              (this.config.RTSPSERVER === "on")) {
            if(this.config.RTSP_OVER_HTTP !== this.oldConfig.RTSP_OVER_HTTP) {
              execCmds.push('rtspserver restart');
            } else {
              execCmds.push('rtspserver on');
            }
          }
          if(Object.keys(this.config).some(prop => (prop.search(/WEBHOOK/) === 0) && (this.config[prop] !== this.oldConfig[prop]))) {
            execCmds.push('setwebhook');
          }
          if((this.config.CRUISE !== this.oldConfig.CRUISE) ||
             (this.config.CRUISE_LIST !== this.oldConfig.CRUISE_LIST)) {
               execCmds.push('cruise restart');
          }
          if((this.config.HEALTHCHECK !== this.oldConfig.HEALTHCHECK)) {
            execCmds.push(`healthcheck ${this.config.HEALTHCHECK}`);
          }
        }
        if(this.config.DIGEST !== this.oldConfig.DIGEST) execCmds.push('lighttpd');

        this.oldConfig = Object.assign({}, this.config);
        if(execCmds.length) {
          this.executing = true;
          this.$nextTick(async () => {
            for(const cmd of execCmds) {
              if(cmd === 'reboot') {
                this.DoReboot();
                break;
              }
              await this.Exec(cmd);
            }
            if(execCmds.indexOf('lighttpd') >= 0) {
              setTimeout(() => this.executing = false, 3000);
            } else {
              this.executing = false;
            }
            if(href) window.location.href = href;
          });
        }
      },
      async Exec(cmd, port) {
        return await axios.post(`./cgi-bin/cmd.cgi?port=${port}`, { exec: cmd }).catch(err => {
          // eslint-disable-next-line no-console
          console.log(err);
        });
      },
    },
  };
</script>

<style scoped>
  .title {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    font-size: 2.5rem;
    padding: 0 15px 5px 30px;
    color: white;
    background-color: #bc423a;
    height:60px;
  }

  .version {
    font-size: 1.5rem;
  }

  .atomcam {
    font-size: 1.5rem;
    flex-grow: 1;
    text-align: right;
    padding-right: 16px;
  }

  .timestamp {
    font-size: 1.5rem;
    flex-basis: 15rem;
  }

  .help {
    font-size: 30px;
    float:right;
    color: snow;
  }

  .container {
    height: calc(100vh - 160px);
    margin: 10px 20px 5px 20px;
    overflow-x: hidden;
    overflow-y: scroll;
  }

  .image-frame {
    z-index: 100;
    display: flex;
    position: fixed;
    flex-direction: column;
  }

  .image-frame-inner1 {
    justify-content: flex-end;
    display: flex;
  }

  .image-frame-inner2 {
    justify-content: flex-end;
    display: flex;
  }

  .still-image {
    width: calc(100% - 36px);
  }

  .pan-slider {
    background-color: white;
    width: calc(100% - 36px);
  }

  .tilt-slider {
    background-color: white;
    align-items: stretch;
  }

  .environment {
    margin: 5px 30px 2px 30px;
  }
  .link-button {
    text-decoration: none;
  }
  .submit {
    margin: 20px 0 20px 0;
  }
  .comment {
    width: 100%;
    margin: 30px;
    text-align: center;
  }
  .latest {
    font-size: 1.2em;
    font-weight: 300;
  }
  .latest-updatable {
    color: 'red';
    font-size: 1.2em;
    font-weight: 600;
  }
</style>
