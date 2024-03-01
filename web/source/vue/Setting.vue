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
      <div class="title-right">
        <div class="locale-selector">
          <select v-model="$i18n.locale">
            <option value="ja">日本語</option>
            <option value="en">English</option>
          </select>
        </div>
        <a href="https://github.com/mnakada/atomcam_tools#atomcam_tools" target="_blank" rel="noopener">
          <i class="el-icon-info help" />
        </a>
      </div>
    </div>
    <div class="well-transparent container">
      <div class="image-frame" :style="imageFrameStyle">
        <div class="image-frame-inner1">
          <ElSlider v-if="isSwing && posValid" class="tilt-slider" v-model="tilt" :min="0" :max="180" vertical :show-input-controls="false" height="100%" @change="Move" @input="Move" />
          <ElTooltip v-if="!rebooting" :tabindex="-1" placement="top" :content="stillFullView?$t('imageFrame.clickToShrink'):$t('imageFrame.clickToExpand')" effect="light" :open-delay="500">
            <img class="still-image" :src="stillImage" @click="stillFullView=!stillFullView">
          </ElTooltip>
        </div>
        <div v-if="isSwing && posValid" class="image-frame-inner2">
          <ElSlider class="pan-slider" v-model="pan" :min="0" :max="355" :show-input-controls="false" @change="Move" @input="Move" />
        </div>
        <div v-if="!rebooting" class="image-frame-inner3">
          <i class="el-icon-moon ir-led" />
          <ElButtonGroup>
            <ElButton size="mini" type="primary" @click="NightLight('on')">
              on
            </ElButton>
            <ElButton size="mini" type="primary" @click="NightLight('auto')">
              auto
            </ElButton>
            <ElButton size="mini" type="primary" @click="NightLight('off')">
              off
            </ElButton>
          </ElButtonGroup>
        </div>
      </div>

      <h3 v-t="'basicSettings.title'" />
      <SettingInput i18n="basicSettings.deviceName" type="text" v-model="config.HOSTNAME" />
      <SettingSwitch i18n="basicSettings.loginAuthentication" v-model="loginAuth" />
      <SettingInput v-if="loginAuth==='on'" i18n="basicSettings.account" type="text" v-model="account" />
      <SettingInput v-if="loginAuth==='on'" i18n="basicSettings.password" type="password" v-model="password" />

      <h3 v-t="'recording.title'" />
      <SettingSwitch i18n="recording.localRecordingSchedule" v-model="config.RECORDING_LOCAL_SCHEDULE" @change="(config.RECORDING_LOCAL_SCHEDULE === 'on') && !schedule.length && AddSchedule()" />
      <div v-if="config.RECORDING_LOCAL_SCHEDULE === 'on'">
        <SettingSchedule v-for="(timeTable, idx) of schedule" :key="'timetable'+idx" :timeRange="true" v-model="schedule[idx]" @add="AddSchedule" @remove="DeleteSchedule(idx)" />
      </div>
      <SettingSwitch i18n="recording.SDCard" v-model="storage_sdcard_record" :onOff="false" />
      <SettingSwitch i18n="recording.SDCard.motionRecording" v-model="storage_sdcard_alarm" :onOff="false" />
      <SettingSwitch v-if="storage_sdcard" i18n="recording.SDCard.networkAccess" :titleOffset="2" v-model="config.STORAGE_SDCARD_PUBLISH" />
      <SettingInput v-if="storage_sdcard" i18n="recording.SDCard.savePath" :titleOffset="2" :span="10" type="text" v-model="config.STORAGE_SDCARD_PATH" @input="FixPath('STORAGE_SDCARD_PATH')" />
      <SettingSwitch v-if="storage_sdcard" i18n="recording.SDCard.automaticDeletion" :titleOffset="2" v-model="config.STORAGE_SDCARD_REMOVE" />
      <SettingInputNumber v-if="storage_sdcard && config.STORAGE_SDCARD_REMOVE === 'on'" i18n="recording.SDCard.daysToKeep" :titleOffset="2" :span="3" v-model="config.STORAGE_SDCARD_REMOVE_DAYS" :min="1" />
      <SettingButton v-if="storage_sdcard" i18n="recording.SDCard.seeAllFiles" :span="4">
        <a href="/sdcard" target="_blank" class="el-button el-button--primary el-button--mini link-button">SD Card</a>
      </SettingButton>

      <SettingSwitch i18n="recording.NAS" v-model="storage_cifs_record" :onOff="false" />
      <SettingSwitch i18n="recording.NAS.motionRecording" v-model="storage_cifs_alarm" :onOff="false" />
      <SettingInput v-if="storage_cifs" i18n="recording.NAS.networkPath" :titleOffset="2" :span="10" type="text" v-model="config.STORAGE_CIFSSERVER" @input="FixPath('STORAGE_CIFSSERVER')" />
      <SettingInput v-if="storage_cifs" i18n="recording.NAS.account" :titleOffset="2" type="text" v-model="config.STORAGE_CIFSUSER" />
      <SettingInput v-if="storage_cifs" i18n="recording.NAS.password" :titleOffset="2" type="password" v-model="config.STORAGE_CIFSPASSWD" show-password />
      <SettingInput v-if="storage_cifs" i18n="recording.NAS.savePath" :titleOffset="2" :span="10" type="text" v-model="config.STORAGE_CIFS_PATH" @input="FixPath('STORAGE_CIFS_PATH')" />
      <SettingSwitch v-if="storage_cifs" i18n="recording.NAS.automaticDeletion" :titleOffset="2" v-model="config.STORAGE_CIFS_REMOVE" />
      <SettingInputNumber v-if="storage_cifs && config.STORAGE_CIFS_REMOVE === 'on'" i18n="recording.NAS.daysToKeep" :titleOffset="2" :span="3" v-model="config.STORAGE_CIFS_REMOVE_DAYS" :min="1" />

      <SettingSwitch i18n="recording.timelapse" v-model="config.TIMELAPSE" />
      <SettingInput v-if="config.TIMELAPSE === 'on'" i18n="recording.timelapse.savePath" :titleOffset="2" :span="10" type="text" v-model="config.TIMELAPSE_PATH" @input="FixPath('TIMELAPSE_PATH')" />
      <SettingInputNumber v-if="config.TIMELAPSE === 'on'" i18n="recording.timelapse.fps" :titleOffset="2" :span="3" v-model="config.TIMELAPSE_FPS" :min="1" :max="60" />
      <SettingSchedule v-if="config.TIMELAPSE === 'on'" v-model="timelapse" :timelapse="true" />
      <SettingComment v-if="config.TIMELAPSE === 'on'" i18n="recording.timelapse.note" />
      <SettingProgress v-if="timelapseInfo.busy" i18n="recording.timelapse.start" :titleOffset="2" :percentage="timelapseInfo.count * 100 / timelapseInfo.max" :label="timelapseInfo.count.toString() + '/' + timelapseInfo.max.toString()" />
      <SettingDangerButton v-if="timelapseInfo.busy" i18n="recording.timelapse.stop" :titleOffset="2" icon="el-icon-refresh-left" @click="TimelapseAbort">
        <span v-if="timelapseInfo.abort" v-t="recording.timelapse.stop.comment" />
      </SettingDangerButton>

      <h3 v-t="'RTSP.title'" />
      <SettingSwitch i18n="RTSP.main" v-model="config.RTSP_VIDEO0" />
      <SettingSwitch v-if="config.RTSP_VIDEO0 === 'on'" i18n="RTSP.main.audio" :titleOffset="2" v-model="config.RTSP_AUDIO0" />
      <SettingInput v-if="config.RTSP_VIDEO0 === 'on'" i18n="RTSP.main.URL" :titleOffset="2" :span="10" type="readonly" v-model="RtspUrl0" />
      <SettingSwitch v-if="config.RTSP_VIDEO0 === 'on'" i18n="RTSP.main.format" :titleOffset="2" v-model="config.RTSP_MAIN_FORMAT_HEVC" />
      <SettingSwitch i18n="RTSP.sub" v-model="config.RTSP_VIDEO1" />
      <SettingSwitch v-if="config.RTSP_VIDEO1 === 'on'" i18n="RTSP.sub.audio" :titleOffset="2" v-model="config.RTSP_AUDIO1" />
      <SettingInput v-if="config.RTSP_VIDEO1 === 'on'" i18n="RTSP.sub.URL" :titleOffset="2" :span="10" type="readonly" v-model="RtspUrl1" />
      <SettingSwitch v-if="(config.RTSP_VIDEO0 === 'on') || (config.RTSP_VIDEO1 === 'on')" i18n="RTSP.http" v-model="config.RTSP_OVER_HTTP" />

      <h3 v-t="'event.title'" />
      <SettingSwitch i18n="event.webhook" v-model="config.WEBHOOK" />
      <SettingInput v-if="config.WEBHOOK === 'on'" i18n="event.webhook.URL" :titleOffset="2" :span="10" type="text" v-model="config.WEBHOOK_URL" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.insecure" :titleOffset="3" v-model="config.WEBHOOK_INSECURE" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.alarm" :titleOffset="2" v-model="config.WEBHOOK_ALARM_EVENT" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.information" :titleOffset="2" v-model="config.WEBHOOK_ALARM_INFO" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.recordingEnd" :titleOffset="2" v-model="config.WEBHOOK_ALARM_VIDEO_FINISH" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.recordingTransfer" :titleOffset="2" tooltip="" v-model="config.WEBHOOK_ALERM_VIDEO" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.screenshotEnd" :titleOffset="2" v-model="config.WEBHOOK_ALARM_PICT_FINISH" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.screenshotTransfer" :titleOffset="2" v-model="config.WEBHOOK_ALERM_PICT" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.recordingSave" :titleOffset="2" v-model="config.WEBHOOK_RECORD_EVENT" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.startTimelapse" :titleOffset="2" v-model="config.WEBHOOK_TIMELAPSE_START" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.recordTimelapse" :titleOffset="2" v-model="config.WEBHOOK_TIMELAPSE_EVENT" />
      <SettingSwitch v-if="config.WEBHOOK === 'on'" i18n="event.webhook.endTimeLapse" :titleOffset="2" v-model="config.WEBHOOK_TIMELAPSE_FINISH" />

      <h3 v-t="'motionDetect.title'" />
      <SettingSwitch i18n="motionDetect.sensorPeriod" v-model="config.MINIMIZE_ALARM_CYCLE" />
      <SettingSwitch i18n="motionDetect.uploadStop" v-model="config.AWS_VIDEO_DISABLE" />

      <div v-if="isSwing" @click="ClearCruiseSelect">
        <h3 v-t="'cruise.title'" />
        <SettingSwitch i18n="cruise.cameraMotion" v-model="config.CRUISE" @change="(config.CRUISE === 'on') && !cruiseList.length && AddCruise()" @click.native.stop />
        <div v-if="config.CRUISE === 'on'">
          <SettingCruise v-for="(cruise, idx) of cruiseList" :key="'timetable'+idx" v-model="cruiseList[idx]" :pan="pan" :tilt="tilt" :selected="cruiseSelect === idx" @add="AddCruise" @remove="DeleteCruise(idx)" @pan="pan=$event" @tilt="tilt=$event" @click="CruiseSelect(idx)" />
        </div>
      </div>

      <h3 v-t="'videoSpec.title'" />
      <SettingInputNumber i18n="videoSpec.frameRate" :withSwitch="true" :defaultValue="20" :span="3" v-model="config.FRAMERATE" :min="1" :max="28" />
      <SettingInputNumber i18n="videoSpec.bitrateMainAVC" :withSwitch="true" :span="3" v-model="config.BITRATE_MAIN_AVC" :min="300" :max="2000" />
      <SettingInputNumber i18n="videoSpec.bitrateMainHEVC" :withSwitch="true" :span="3" v-model="config.BITRATE_MAIN_HEVC" :min="300" :max="2000" />
      <SettingInputNumber i18n="videoSpec.bitrateSubHEVC" :withSwitch="true" :span="3" v-model="config.BITRATE_SUB_HEVC" :min="100" :max="500" />

      <h3 v-t="'monitoring.title'" />
      <SettingSwitch i18n="monitoring.network" v-model="config.MONITORING_NETWORK" />
      <SettingSwitch v-if="config.MONITORING_NETWORK === 'on'" i18n="monitoring.reboot" v-model="config.MONITORING_REBOOT" :titleOffset="2" />
      <SettingSwitch i18n="monitoring.ping" v-model="config.HEALTHCHECK" />
      <SettingInput v-if="config.HEALTHCHECK === 'on'" i18n="monitoring.URL" :titleOffset="2" :span="10" type="text" v-model="config.HEALTHCHECK_PING_URL" />

      <h3 v-t="'maintenance.title'" />
      <SettingButton v-if="isSwing" i18n="maintenance.initialPosition" :span="4" @click="MoveInit" />
      <SettingSwitch i18n="maintenance.periodicRestart" v-model="config.REBOOT" />
      <SettingSchedule v-if="config.REBOOT === 'on'" v-model="reboot" />
      <SettingDangerButton i18n="maintenance.reboot" icon="el-icon-refresh-left" @click="DoReboot" />
      <SettingDangerButton i18n="maintenance.eraseSDCard" icon="el-icon-folder-delete" @click="DoErase" />
      <SettingDangerButton i18n="maintenance.update" icon="el-icon-refresh" :button="config.CUSTOM_ZIP === 'on' ? 'Custom Update' : 'Update'" :disabled="!updatable" @click="DoUpdate">
        <span class="latest" :class="{ 'latest-updatable': updatable }">
          Latest Version : Ver.{{ latestVer }}
        </span>
      </SettingDangerButton>
      <SettingSwitch i18n="maintenance.customZip" v-model="config.CUSTOM_ZIP" />
      <SettingInput v-if="config.CUSTOM_ZIP === 'on'" i18n="maintenance.customZip.URL" :titleOffset="2" :span="10" type="text" v-model="config.CUSTOM_ZIP_URL" placeholder="https://github.com/mnakada/atomcam_tools/releases/latest/download/atomcam_tools.zip" />
      <div class="bottom-padding" />
    </div>
    <div class="submit">
      <ElButton @click="Submit" type="primary" :disabled="stillFullView" v-t="'submit'" />
    </div>
    <ElDrawer :title="$t('updating.title')" :visible.sync="executing" direction="btt" :show-close="false" :wrapperClosable="false">
      <h4 class="comment" v-t="'updating.comment'" />
    </ElDrawer>
    <ElDrawer :title="$t('rebooting.title')" :visible.sync="rebooting" direction="btt" :show-close="false" :wrapperClosable="false">
      <h4 class="comment" v-t="{ path: 'rebooting.comment', args: { rebootTime: rebootTime } }" />
    </ElDrawer>
  </div>
</template>

<script>
  import axios from 'axios';
  import md5 from 'js-md5';
  import { Tooltip, Drawer, Slider, ButtonGroup } from 'element-ui';
  import SettingSwitch from './SettingSwitch.vue';
  import SettingInput from './SettingInput.vue';
  import SettingInputNumber from './SettingInputNumber.vue';
  import SettingButton from './SettingButton.vue';
  import SettingComment from './SettingComment.vue';
  import SettingDangerButton from './SettingDangerButton.vue';
  import SettingSchedule from './SettingSchedule.vue';
  import SettingProgress from './SettingProgress.vue';
  import SettingCruise from './SettingCruise.vue';

  import 'element-ui/lib/theme-chalk/tooltip.css';
  import 'element-ui/lib/theme-chalk/drawer.css';
  import 'element-ui/lib/theme-chalk/slider.css';
  import 'element-ui/lib/theme-chalk/button-group.css';

  export default {
    name: 'ATOMCamSetting',
    components: {
      ElTooltip: Tooltip,
      ElDrawer: Drawer,
      ElSlider: Slider,
      ElButtonGroup: ButtonGroup,
      SettingSwitch,
      SettingInput,
      SettingInputNumber,
      SettingButton,
      SettingComment,
      SettingDangerButton,
      SettingSchedule,
      SettingProgress,
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
          RECORDING_LOCAL_SCHEDULE: 'off',
          RECORDING_LOCAL_SCHEDULE_LIST: '', // -> /media/mmc/local_schedule
          RTSP_VIDEO0: 'off',
          RTSP_AUDIO0: 'off',
          RTSP_MAIN_FORMAT_HEVC: 'off',
          RTSP_VIDEO1: 'off',
          RTSP_AUDIO1: 'off',
          RTSP_OVER_HTTP: 'off',
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
          TIMELAPSE: 'off',
          TIMELAPSE_SCHEDULE: '0 4 * * 0:1:2:3:4:5:6', // -> /var/spool/crontabs/root
          TIMELAPSE_PATH: '%Y%m%d%H%M',
          TIMELAPSE_INTERVAL: 60,
          TIMELAPSE_COUNT: 960,
          TIMELAPSE_FPS: 20,
          WEBHOOK: 'off',
          WEBHOOK_URL: '',
          WEBHOOK_INSECURE: 'off',
          WEBHOOK_ALARM_EVENT: 'off',
          WEBHOOK_ALARM_INFO: 'off',
          WEBHOOK_ALARM_VIDEO_FINISH: 'off',
          WEBHOOK_ALERM_VIDEO: 'off',
          WEBHOOK_ALARM_PICT_FINISH: 'off',
          WEBHOOK_ALERM_PICT: 'off',
          WEBHOOK_RECORD_EVENT: 'off',
          WEBHOOK_TIMELAPSE_START: 'off',
          WEBHOOK_TIMELAPSE_EVENT: 'off',
          WEBHOOK_TIMELAPSE_FINISH: 'off',
          CRUISE: 'off',
          CRUISE_LIST: '',
          MINIMIZE_ALARM_CYCLE: 'off',
          AWS_VIDEO_DISABLE: 'off',
          CUSTOM_ZIP: 'off',
          CUSTOM_ZIP_URL: '',
          MONITORING_NETWORK: 'on',
          MONITORING_REBOOT: 'on',
          HEALTHCHECK: 'off',
          HEALTHCHECK_PING_URL: '',
          LOCALE: navigator.language.indexOf('en') === 0 ? 'en' : 'ja',
          FRAMERATE: 20,
          BITRATE_MAIN_AVC: 960,   // ch0 H264 HD   Record/Alarm, RTSP AVC Main
          BITRATE_SUB_HEVC: -180,  // ch1 H265 360p MobileApp,    RTSP HEVC Sub
          BITRATE_MAIN_HEVC: -800, // ch3 H265 HD   MobileApp,    RTSP HEVC Main
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
        timelapse: {
          dayOfWeekSelect: [0, 1, 2, 3, 4, 5, 6],
          startTime: '04:00',
          interval: 60,
          count: 960,
        },
        timelapseInfo: {
          busy: false,
          abort: false,
        },
        cruiseList: [],
        cruiseSelect: -1,
        reboot: {
          startTime: '02:00',
          endTime: '02:00',
          dayOfWeekSelect: [6],
        },
        rebootTime: 80,
        latestVer: '',
        executing: false,
        rebooting: false,
        stillImage: null,
        stillFullView: false,
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
        return this.stillFullView ? { right: '10px', width: '98vw', height: '55.125vw' } : { right: '30px', width: '30vw', height: '16.875vw' };
      },
      storage_sdcard() {
        return this.storage_sdcard_record || this.storage_sdcard_alarm;
      },
      storage_cifs() {
        return this.storage_cifs_record || this.storage_cifs_alarm;
      },
      updatable() {
        if(this.config.CUSTOM_ZIP === 'on' && this.config.CUSTOM_ZIP_URL !== '') return true;
        const ver = (this.config.ATOMHACKVER || '').replace(/[a-zA-Z]+/, '.').split('.');
        const latest = (this.latestVer || '').replace(/[a-zA-Z]+/, '.').split('.');
        if(ver.length < 3) return false;
        if(latest.length < 3) return false;
        if(parseInt(ver[0]) < parseInt(latest[0])) return true;
        if(parseInt(ver[0]) > parseInt(latest[0])) return false;
        if(parseInt(ver[1]) < parseInt(latest[1])) return true;
        if(parseInt(ver[1]) > parseInt(latest[1])) return false;
        if(parseInt(ver[2]) < parseInt(latest[2])) return true;
        if(parseInt(ver[2]) > parseInt(latest[2])) return false;
        if(ver.length > 3) return true;
        if(latest.length > 3) return true;
        return false;
      },
      isSwing() {
        return !this.rebooting && (this.config.PRODUCT_MODEL === 'ATOM_CAKP1JZJP');
      },
      RtspUrl0() {
        const port = (this.config.RTSP_OVER_HTTP  === 'on') ? 8080 : 8554;
        const video = (this.config.RTSP_MAIN_FORMAT_HEVC === 'on') ? 'video2' : 'video0';
        return `rtsp://${window.location.host}:${port}/${video}_unicast`;
      },
      RtspUrl1() {
        const port = (this.config.RTSP_OVER_HTTP  === 'on') ? 8080 : 8554;
        return `rtsp://${window.location.host}:${port}/video1_unicast`;
      },
    },
    async mounted() {
      const res = await axios.get('./cgi-bin/hack_ini.cgi').catch(err => {
        // eslint-disable-next-line no-console
        console.log('axios.get ./cgi-bin/hack_ini.cgi', err);
        return '';
      });

      this.oldConfig = (res.data || '').split('\n').reduce((d, l) => {
        const name = l.split(/[ \t=]/)[0].trim();
        if(d[name] != null) d[name] = l.replace(new RegExp(name + '[ \t=]*'), '').trim();
        return d;
      }, Object.assign({}, this.config));
      this.config = Object.assign({}, this.oldConfig);
      // eslint-disable-next-line no-console
      console.log('config', this.config);

      if(this.config.LOCALE && (this.$i18n.availableLocales.indexOf(this.config.LOCALE) >= 0)) {
        this.$i18n.locale = this.config.LOCALE;
      } else {
        this.$i18n.locale = navigator.language.indexOf('en') === 0 ? 'en' : 'ja';
      }

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
            for(let i = 0; i < 7; i++) {
              if(ll[1] & (2 << i)) d[index].dayOfWeekSelect.push(i);
            }
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

      if(this.config.TIMELAPSE_SCHEDULE) {
        const str = this.config.TIMELAPSE_SCHEDULE.split(' ');
        const days = (str[4] || '').split(':');
        this.timelapse = {
          startTime: `${str[1].padStart(2, '0')}:${str[0].padStart(2, '0')}`,
          dayOfWeekSelect: days.map(d => (parseInt(d) + 6) % 7),
          interval: this.config.TIMELAPSE_INTERVAL,
          count: this.config.TIMELAPSE_COUNT,
        };
      }

      this.cruiseList = (this.config.CRUISE_LIST || '').split(';').reduce((array, cmd) => {
        const args = cmd.trim().split(' ');
        if(args[0] === 'move') {
          array.push({
            pan: parseInt(args[1]),
            tilt: parseInt(args[2]),
            speed: parseInt(args[3] ?? '9'),
          });
          return array;
        }
        const last = array[array.length - 1];
        if(!last) return array;
        if(['detect', 'follow', 'sleep'].indexOf(args[0]) < 0) return array;
        last.wait = parseInt(args[1]);
        last.timeout = parseInt(args[2]);
        last.followingSpeed = parseInt(args[3] ?? '9');
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
        console.log('axios.get ./cgi-bin/cmd.cgi', err);
        return { data: '' };
      })).data.split('\n').reduce((s, d) => {
        s[d.replace(/=.*$/, '').trim()] = d.replace(/^.*=/, '').trim();
        return s;
      }, {});

      this.latestVer = status.LATESTVER;
      if(status.MOTORPOS) {
        const pos = status.MOTORPOS.split(' ');
        this.pan = Math.round(parseFloat(pos[0]));
        this.tilt = Math.round(parseFloat(pos[1]));
        this.posValid = true;
      }

      if(this.config.REBOOT_SCHEDULE) {
        const str = this.config.REBOOT_SCHEDULE.split(' ');
        const days = (str[4] || '').split(':');
        this.reboot = {
          startTime: `${str[1].padStart(2, '0')}:${str[0].padStart(2, '0')}`,
          dayOfWeekSelect: days.map(d => (parseInt(d) + 6) % 7),
        };
      }

      setInterval(async () => {
        const res = await axios.get('./cgi-bin/cmd.cgi?name=status').catch(err => {
          // eslint-disable-next-line no-console
          console.log('axios.get ./cgi-bin/cmd.cgi?name=status', err);
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
        if(this.intervalValue.MOTORPOS) {
          const pos = this.intervalValue.MOTORPOS.split(' ');
          const pan = Math.round(parseFloat(pos[0]));
          const tilt = Math.round(parseFloat(pos[1]));
          this.posValid = true;
          this.pan = pan;
          this.tilt = tilt;
        }
        if(this.intervalValue.TIMELAPSE) {
          const count = this.intervalValue.TIMELAPSE.replace(/^.*count:/, '').split(/\//);
          if(count.length === 2) {
            this.timelapseInfo.busy = true;
            this.timelapseInfo.count = count[0];
            this.timelapseInfo.max = count[1];
          } else {
            this.timelapseInfo.busy = false;
            this.timelapseInfo.abort = false;
          }
        }
      }, 1000);
      this.StillImageInterval();
    },
    methods: {
      async Move() {
        if(!this.posValid) return;
        await this.Exec(`move ${this.pan} ${this.tilt}`, 'socket');
        this.StillImageInterval();
        if(this.moveTimeout) clearTimeout(this.moveTimeout);
        this.moveTimeout = setTimeout(() => {
          this.moveTimeout = null;
          this.Exec('posrec');
        }, 3000);
      },
      NightLight(mode) {
        this.Exec(`night ${mode}`, 'socket');
      },
      async TimelapseAbort() {
        this.timelapseInfo.abort = true;
        await this.Exec('timelapse close', 'socket');
        this.timelapseInfo.abort = false;
      },
      async StillImageInterval() {
        const image = await axios.get('./cgi-bin/get_jpeg.cgi', { responseType: 'arraybuffer' }).catch(err => {
          // eslint-disable-next-line no-console
          console.log('axios.get ./cgi-bin/get_jpeg.cgi', err);
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
          dayOfWeekSelect: [0, 1, 2, 3, 4, 5, 6],
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
          speed: 9,
          wait: 10,
          timeout: 10,
          followingSpeed: 9,
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
        await this.Submit();
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
          const val = timeTable.dayOfWeekSelect.reduce((v, d) => v | (2 << d), 0);
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
        if(!this.storage_sdcard) this.config.STORAGE_SDCARD_PUBLISH = 'off';

        if(this.storage_cifs_record && this.storage_cifs_alarm) {
          this.config.STORAGE_CIFS = 'on';
        } else if(this.storage_cifs_record) {
          this.config.STORAGE_CIFS = 'record';
        } else if(this.storage_cifs_alarm) {
          this.config.STORAGE_CIFS = 'alarm';
        } else {
          this.config.STORAGE_CIFS = 'off';
        }

        this.config.LOCALE = this.$i18n.locale;
        this.config.TIMELAPSE_INTERVAL = this.timelapse.interval;
        this.config.TIMELAPSE_COUNT = this.timelapse.count;
        str = parseInt(this.timelapse.startTime.slice(-2)) + ' ';
        str += parseInt(this.timelapse.startTime.slice(0, 2)) + ' * * ';
        str += this.timelapse.dayOfWeekSelect.sort((a, b) => a - b).reduce((v, d) => v + (v.length ? ':' : '') + ((d + 1) % 7).toString(), '');
        this.config.TIMELAPSE_SCHEDULE = str;

        this.config.CRUISE_LIST = this.cruiseList.reduce((str, cruise) => {
          str += `move ${cruise.pan} ${cruise.tilt} ${cruise.speed};`;
          const waitMode = cruise.detect ? (cruise.follow ? 'follow' : 'detect') : 'sleep';
          str += `${waitMode} ${cruise.wait}`;
          if(waitMode !== 'sleep')  str += ` ${cruise.timeout}`;
          if(waitMode === 'follow')  str += ` ${cruise.followingSpeed}`;
          str += ';';
          return str;
        }, '');
        this.ClearCruiseSelect();

        str = parseInt(this.reboot.startTime.slice(-2)) + ' ';
        str += parseInt(this.reboot.startTime.slice(0, 2)) + ' * * ';
        str += this.reboot.dayOfWeekSelect.sort((a, b) => a - b).reduce((v, d) => v + (v.length ? ':' : '') + ((d + 1) % 7).toString(), '');
        this.config.REBOOT_SCHEDULE = str;

        await axios.post('./cgi-bin/hack_ini.cgi', this.config).catch(err => {
          // eslint-disable-next-line no-console
          console.log('axios.post ./cgi-bin/hack_ini.cgi', err);
        });
        // eslint-disable-next-line no-console
        console.log('config', this.config);

        const execCmds = [];
        let href = null;
        if((this.config.TIMELAPSE_SCHEDULE !== this.oldConfig.TIMELAPSE_SCHEDULE) ||
           (this.config.REBOOT_SCHEDULE !== this.oldConfig.REBOOT_SCHEDULE)) {
          execCmds.push('setCron');
        }
        if(this.config.STORAGE_SDCARD !== this.oldConfig.STORAGE_SDCARD) {
          let periodic = 'ram';
          if((this.config.STORAGE_SDCARD === 'on') || (this.config.STORAGE_SDCARD === 'record')) periodic = 'sd';
          let alarm = 'ram';
          if((this.config.STORAGE_SDCARD === 'on') || (this.config.STORAGE_SDCARD === 'alarm')) alarm = 'sd';
          execCmds.push(`mp4write ${periodic} ${alarm}`);
        }
        if(parseInt(this.config.FRAMERATE) !== parseInt(this.oldConfig.FRAMERATE)) {
          execCmds.push(`framerate ${this.config.FRAMERATE < 0 ? 'auto' : this.config.FRAMERATE}`);
        }
        if(parseInt(this.config.BITRATE_MAIN_AVC) !== parseInt(this.oldConfig.BITRATE_MAIN_AVC)) {
          execCmds.push(`bitrate 0 ${this.config.BITRATE_MAIN_AVC < 0 ? 'auto' : this.config.BITRATE_MAIN_AVC}`);
        }
        if(parseInt(this.config.BITRATE_SUB_HEVC) !== parseInt(this.oldConfig.BITRATE_SUB_HEVC)) {
          execCmds.push(`bitrate 1 ${this.config.BITRATE_SUB_HEVC < 0 ? 'auto' : this.config.BITRATE_SUB_HEVC}`);
        }
        if(parseInt(this.config.BITRATE_MAIN_HEVC) !== parseInt(this.oldConfig.BITRATE_MAIN_HEVC)) {
          execCmds.push(`bitrate 3 ${this.config.BITRATE_MAIN_HEVC < 0 ? 'auto' : this.config.BITRATE_MAIN_HEVC}`);
        }
        if(this.config.HOSTNAME !== this.oldConfig.HOSTNAME) {
          execCmds.push(`hostname ${this.config.HOSTNAME}`);
          if(window.location.host === `${this.oldConfig.HOSTNAME}.local`) {
            href = `http://${this.config.HOSTNAME}.local`;
          }
        }
        if(this.config.MINIMIZE_ALARM_CYCLE !== this.oldConfig.MINIMIZE_ALARM_CYCLE) {
          execCmds.push(`alarm ${this.config.MINIMIZE_ALARM_CYCLE === 'on' ? '30' : '300'}`);
        }
        if(this.config.AWS_VIDEO_DISABLE !== this.oldConfig.AWS_VIDEO_DISABLE) {
          execCmds.push(`curl upload ${this.config.AWS_VIDEO_DISABLE === 'on' ? 'disable' : 'enable'}`);
        }
        if(((this.config.RTSP_VIDEO0 !== this.oldConfig.RTSP_VIDEO0) ||
            (this.config.RTSP_VIDEO1 !== this.oldConfig.RTSP_VIDEO1)) &&
           (this.config.RTSP_VIDEO0 === 'off') && (this.config.RTSP_VIDEO1 === 'off')) {
          execCmds.push('rtspserver off');
        }
        if(this.config.STORAGE_SDCARD_PUBLISH !== this.oldConfig.STORAGE_SDCARD_PUBLISH) {
          execCmds.push(`samba ${this.config.STORAGE_SDCARD_PUBLISH}`);
        }
        if((this.config.RTSP_VIDEO0 === 'on') || (this.config.RTSP_VIDEO1 === 'on')) {
          if((this.config.RTSP_OVER_HTTP !== this.oldConfig.RTSP_OVER_HTTP) ||
             (this.config.RTSP_MAIN_FORMAT_HEVC !== this.oldConfig.RTSP_MAIN_FORMAT_HEVC)) {
            execCmds.push('rtspserver restart');
          } else if((this.config.RTSP_VIDEO0 !== this.oldConfig.RTSP_VIDEO0) ||
                    (this.config.RTSP_VIDEO1 !== this.oldConfig.RTSP_VIDEO1) ||
                    (this.config.RTSP_AUDIO0 !== this.oldConfig.RTSP_AUDIO0) ||
                    (this.config.RTSP_AUDIO1 !== this.oldConfig.RTSP_AUDIO1)) {
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
        if(this.config.DIGEST !== this.oldConfig.DIGEST) execCmds.push('lighttpd');

        this.oldConfig = Object.assign({}, this.config);
        if(execCmds.length) {
          this.executing = true;
          this.$nextTick(async () => {
            for(const cmd of execCmds) {
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
          console.log(`axios.post ./cgi-bin/cmd.cgi?port=${port}`, err);
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
    padding: 0px 0px 5px 30px;
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

  .locale-selector {
    background-color: #0000;
  }

  .locale-selector select {
    background-color: #0000;
    color: white;
    border: 0px;
  }

  .locale-selector select:focus-visible {
    outline: 0px;
  }

  .locale-selector option {
    background-color: #0000;
    color: white;
  }

  .help {
    font-size: 30px;
    float:right;
    color: snow;
    padding-right: 15px;
  }

  .container {
    height: calc(100vh - 200px);
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

  .image-frame-inner3 {
    justify-content: flex-end;
    display: flex;
    margin: 5px 0 5px 0;
  }

  .ir-led {
    font-size: 24px;
    color: gray;
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
    position: fixed;
    bottom: 75px;
    right: 100px;
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
  .bottom-padding {
    padding-bottom: 150px;
  }
</style>
