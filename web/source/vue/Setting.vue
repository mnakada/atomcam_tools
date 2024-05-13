<template>
  <div>
    <div class="title" :class="'title_' + distributor">
      <div>
        {{ distributor }}Cam Hack
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

    <div>
      <ElTabs tabPosition="left" @tab-click="HandleTabsClick">

        <!-- Camera Tab -->
        <ElTabPane class="well-transparent container-no-submit" :label="$t('camera.tab')">
          <div class="image-frame">
            <div class="image-frame-inner1">
              <ElSlider v-if="isSwing && posValid" class="tilt-slider" v-model="tilt" :min="0" :max="180" vertical :show-input-controls="false" height="100%" @change="Move" @input="Move" />
              <img class="still-image" :src="stillImage">
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
        </ElTabPane>

        <!-- SD-Card Tab -->
        <ElTabPane class="well-transparent container-no-submit" :label="$t('SDCard.tab')">
          <iframe ref="sdcardFrame" class="sdcard-frame" src="/sdcard" />
        </ElTabPane>

        <!-- Record Setting Tab -->
        <ElTabPane class="well-transparent container" :label="$t('record.tab')">
          <h3 v-t="'record.periodicRec.title'" />
          <SettingSwitch i18n="record.SDCard" v-model="config.PERIODICREC_SDCARD" />
          <div v-if="config.PERIODICREC_SDCARD === 'on'">
            <SettingSwitch i18n="record.SDCard.automaticDeletion" :titleOffset="2" v-model="config.PERIODICREC_SDCARD_REMOVE" />
            <SettingInputNumber v-if="config.PERIODICREC_SDCARD_REMOVE === 'on'" i18n="record.SDCard.daysToKeep" :titleOffset="2" :span="3" v-model="config.PERIODICREC_SDCARD_REMOVE_DAYS" :min="1" />
          </div>
          <SettingSwitch i18n="record.NAS" v-model="config.PERIODICREC_CIFS" />
          <div v-if="config.PERIODICREC_CIFS === 'on'">
            <SettingInput i18n="record.NAS.savePath" :titleOffset="2" :span="10" type="text" v-model="config.PERIODICREC_CIFS_PATH" @input="FixPath('PERIODICREC_CIFS_PATH')" />
            <SettingSwitch i18n="record.NAS.automaticDeletion" :titleOffset="2" v-model="config.PERIODICREC_CIFS_REMOVE" />
            <SettingInputNumber v-if="config.PERIODICREC_CIFS_REMOVE === 'on'" i18n="record.NAS.daysToKeep" :titleOffset="2" :span="3" v-model="config.PERIODICREC_CIFS_REMOVE_DAYS" :min="1" />
          </div>
          <div v-if="config.PERIODICREC_SDCARD === 'on' || config.PERIODICREC_CIFS === 'on'">
            <SettingSwitch i18n="record.recordingSchedule" v-model="config.PERIODICREC_SCHEDULE" @change="(config.PERIODICREC_SCHEDULE === 'on') && !periodicRecSchedule.length && AddSchedule('periodicRecSchedule')" />
            <div v-if="config.PERIODICREC_SCHEDULE === 'on'">
              <SettingSchedule v-for="(timeTable, idx) of periodicRecSchedule" :key="'timetable'+idx" :timeRange="true" v-model="periodicRecSchedule[idx]" @add="AddSchedule('periodicRecSchedule')" @remove="DeleteSchedule('periodicRecSchedule', idx, 'PERIODICREC_SCHEDULE')" />
            </div>
          </div>

          <h3 v-t="'record.alarmRec.title'" />
          <SettingSwitch i18n="record.SDCard" v-model="config.ALARMREC_SDCARD" />
          <div v-if="config.ALARMREC_SDCARD === 'on'">
            <SettingInput i18n="record.SDCard.savePath" :titleOffset="2" :span="10" type="text" v-model="config.ALARMREC_SDCARD_PATH" @input="FixPath('ALARMREC_SDCARD_PATH')" />
            <SettingSwitch i18n="record.SDCard.automaticDeletion" :titleOffset="2" v-model="config.ALARMREC_SDCARD_REMOVE" />
            <SettingInputNumber v-if="config.ALARMREC_SDCARD_REMOVE === 'on'" i18n="record.SDCard.daysToKeep" :titleOffset="2" :span="3" v-model="config.ALARMREC_SDCARD_REMOVE_DAYS" :min="1" />
          </div>
          <SettingSwitch i18n="record.NAS" v-model="config.ALARMREC_CIFS" />
          <div v-if="config.ALARMREC_CIFS === 'on'">
            <SettingInput i18n="record.NAS.savePath" :titleOffset="2" :span="10" type="text" v-model="config.ALARMREC_CIFS_PATH" @input="FixPath('ALARMREC_CIFS_PATH')" />
            <SettingSwitch i18n="record.NAS.automaticDeletion" :titleOffset="2" v-model="config.ALARMREC_CIFS_REMOVE" />
            <SettingInputNumber v-if="config.ALARMREC_CIFS_REMOVE === 'on'" i18n="record.NAS.daysToKeep" :titleOffset="2" :span="3" v-model="config.ALARMREC_CIFS_REMOVE_DAYS" :min="1" />
          </div>
          <div v-if="config.ALARMREC_SDCARD === 'on' || config.ALARMREC_CIFS === 'on'">
            <SettingSwitch i18n="record.recordingSchedule" v-model="config.ALARMREC_SCHEDULE" @change="(config.ALARMREC_SCHEDULE === 'on') && !alarmRecSchedule.length && AddSchedule('alarmRecSchedule')" />
            <div v-if="config.ALARMREC_SCHEDULE === 'on'">
              <SettingSchedule v-for="(timeTable, idx) of alarmRecSchedule" :key="'timetable'+idx" :timeRange="true" v-model="alarmRecSchedule[idx]" @add="AddSchedule('alarmRecSchedule')" @remove="DeleteSchedule('alarmRecSchedule', idx, 'ALARMREC_SCHEDULE')" />
            </div>
          </div>
        </ElTabPane>

        <!-- Timelapse Tab -->
        <ElTabPane class="well-transparent container" :label="$t('timelapse.tab')">
          <h3 v-t="'timelapse.title'" />
          <SettingSwitch i18n="record.SDCard" v-model="config.TIMELAPSE_SDCARD" />
          <div v-if="config.TIMELAPSE_SDCARD === 'on'">
            <SettingInput i18n="record.SDCard.savePath" :titleOffset="2" :span="10" type="text" v-model="config.TIMELAPSE_SDCARD_PATH" @input="FixPath('TIMELAPSE_SDCARD_PATH')" />
            <SettingSwitch i18n="record.SDCard.automaticDeletion" :titleOffset="2" v-model="config.TIMELAPSE_SDCARD_REMOVE" />
            <SettingInputNumber v-if="config.TIMELAPSE_SDCARD_REMOVE === 'on'" i18n="record.SDCard.daysToKeep" :titleOffset="2" :span="3" v-model="config.TIMELAPSE_SDCARD_REMOVE_DAYS" :min="1" />
          </div>
          <SettingSwitch i18n="record.NAS" v-model="config.TIMELAPSE_CIFS" />
          <div v-if="config.TIMELAPSE_CIFS === 'on'">
            <SettingInput i18n="record.NAS.savePath" :titleOffset="2" :span="10" type="text" v-model="config.TIMELAPSE_CIFS_PATH" @input="FixPath('TIMELAPSE_CIFS_PATH')" />
            <SettingSwitch i18n="record.NAS.automaticDeletion" :titleOffset="2" v-model="config.TIMELAPSE_CIFS_REMOVE" />
            <SettingInputNumber v-if="config.TIMELAPSE_CIFS_REMOVE === 'on'" i18n="record.NAS.daysToKeep" :titleOffset="2" :span="3" v-model="config.TIMELAPSE_CIFS_REMOVE_DAYS" :min="1" />
          </div>
          <div v-if="config.TIMELAPSE_SDCARD === 'on' || config.TIMELAPSE_CIFS === 'on'">
            <SettingSchedule v-model="timelapse" :timelapse="true" i18n="timelapse.setting" />
            <SettingComment i18n="timelapse.note" />
            <SettingInputNumber i18n="timelapse.fps" :span="3" v-model="config.TIMELAPSE_FPS" :min="1" :max="60" />
            <SettingProgress v-if="timelapseInfo.busy" i18n="timelapse.start" :percentage="timelapseInfo.count * 100 / timelapseInfo.max" :label="timelapseInfo.count.toString() + '/' + timelapseInfo.max.toString()" />
            <SettingDangerButton v-if="timelapseInfo.busy" i18n="timelapse.stop" icon="el-icon-refresh-left" @click="TimelapseAbort">
              <span v-if="timelapseInfo.abort" v-t="timelapse.stop.comment" />
            </SettingDangerButton>
          </div>
        </ElTabPane>

        <!-- Media Setting Tab -->
        <ElTabPane class="well-transparent container" :label="$t('media.tab')">
          <h3 v-t="'SDCardSettings.title'" />
          <SettingSwitch i18n="SDCardSettings.smbAccess" v-model="config.STORAGE_SDCARD_PUBLISH" />
          <SettingSwitch i18n="SDCardSettings.directWrite" v-model="config.STORAGE_SDCARD_DIRECT_WRITE" />
          <SettingDangerButton i18n="SDCardSettings.eraseSDCard" icon="el-icon-folder-delete" @click="DoErase" />

          <h3 v-t="'NASSettings.title'" />
          <SettingInput i18n="NASSettings.networkPath" :span="10" type="text" v-model="config.STORAGE_CIFSSERVER" @input="FixPath('STORAGE_CIFSSERVER')" />
          <SettingInput i18n="NASSettings.account" type="text" v-model="config.STORAGE_CIFSUSER" />
          <SettingInput i18n="NASSettings.password" type="password" v-model="config.STORAGE_CIFSPASSWD" show-password />
        </ElTabPane>

        <!-- Streaming Setting Tab -->
        <ElTabPane class="well-transparent container" :label="$t('RTSP.tab')">
          <h3 v-t="'RTSP.title'" />
          <SettingSwitch i18n="RTSP.main" v-model="config.RTSP_VIDEO0" />
          <SettingSwitch v-if="config.RTSP_VIDEO0 === 'on'" i18n="RTSP.main.audio" :titleOffset="2" v-model="config.RTSP_AUDIO0" />
          <SettingInput v-if="config.RTSP_VIDEO0 === 'on'" i18n="RTSP.main.URL" :titleOffset="2" :span="10" type="readonly" v-model="RtspUrl0" />
          <div v-if="distributor === 'ATOM'">
            <SettingSwitch i18n="RTSP.mainHEVC" v-model="config.RTSP_VIDEO2" />
            <SettingSwitch v-if="config.RTSP_VIDEO2 === 'on'" i18n="RTSP.mainHEVC.audio" :titleOffset="2" v-model="config.RTSP_AUDIO2" />
            <SettingInput v-if="config.RTSP_VIDEO2 === 'on'" i18n="RTSP.mainHEVC.URL" :titleOffset="2" :span="10" type="readonly" v-model="RtspUrl2" />
          </div>
          <SettingSwitch i18n="RTSP.sub" v-model="config.RTSP_VIDEO1" />
          <SettingSwitch v-if="config.RTSP_VIDEO1 === 'on'" i18n="RTSP.sub.audio" :titleOffset="2" v-model="config.RTSP_AUDIO1" />
          <SettingInput v-if="config.RTSP_VIDEO1 === 'on'" i18n="RTSP.sub.URL" :titleOffset="2" :span="10" type="readonly" v-model="RtspUrl1" />
          <div v-if="(config.RTSP_VIDEO0 === 'on') || (config.RTSP_VIDEO1 === 'on') || (config.RTSP_VIDEO2 === 'on')">
            <SettingSwitch i18n="RTSP.http" v-model="config.RTSP_OVER_HTTP" />
            <SettingSwitch i18n="RTSP.auth" v-model="config.RTSP_AUTH" />
            <SettingInput v-if="config.RTSP_AUTH === 'on'" i18n="RTSP.account" type="text" :titleOffset="2" v-model="config.RTSP_USER" />
            <SettingInput v-if="config.RTSP_AUTH === 'on'" i18n="RTSP.password" type="password" :titleOffset="2" v-model="config.RTSP_PASSWD" show-password />
          </div>
        </ElTabPane>

        <!-- Event Webhook Tab -->
        <ElTabPane class="well-transparent container" :label="$t('event.tab')">
          <h3 v-t="'event.webhook.title'" />
          <SettingInput i18n="event.webhook.URL" :span="10" type="text" v-model="config.WEBHOOK_URL" />
          <SettingSwitch i18n="event.webhook.insecure" :titleOffset="2" v-model="config.WEBHOOK_INSECURE" />
          <SettingSwitch i18n="event.webhook.alarm" v-model="config.WEBHOOK_ALARM_EVENT" />
          <SettingSwitch v-if="(distributor === 'ATOM')" i18n="event.webhook.information" v-model="config.WEBHOOK_ALARM_INFO" />
          <SettingSwitch i18n="event.webhook.recordingEnd" v-model="config.WEBHOOK_ALARM_VIDEO_FINISH" />
          <SettingSwitch i18n="event.webhook.recordingTransfer" tooltip="" v-model="config.WEBHOOK_ALERM_VIDEO" />
          <SettingSwitch i18n="event.webhook.screenshotEnd" v-model="config.WEBHOOK_ALARM_PICT_FINISH" />
          <SettingSwitch i18n="event.webhook.screenshotTransfer" v-model="config.WEBHOOK_ALERM_PICT" />
          <SettingSwitch i18n="event.webhook.recordingSave" v-model="config.WEBHOOK_RECORD_EVENT" />
          <SettingSwitch i18n="event.webhook.startTimelapse" v-model="config.WEBHOOK_TIMELAPSE_START" />
          <SettingSwitch i18n="event.webhook.recordTimelapse" v-model="config.WEBHOOK_TIMELAPSE_EVENT" />
          <SettingSwitch i18n="event.webhook.endTimeLapse" v-model="config.WEBHOOK_TIMELAPSE_FINISH" />
        </ElTabPane>

        <!-- Cruise Setting Tab -->
        <ElTabPane v-if="isSwing && posValid" class="well-transparent container" :label="$t('cruise.tab')">
          <h3 v-t="'cruise.title'" />
          <SettingButton i18n="cruise.initialPosition" :span="4" @click="MoveInit" />
          <div @click="ClearCruiseSelect">
            <SettingSwitch i18n="cruise.cameraMotion" v-model="config.CRUISE" @change="(config.CRUISE === 'on') && !cruiseList.length && AddCruise()" @click.native.stop />
            <div v-if="config.CRUISE === 'on'">
              <div class="image-frame image-frame-cruise">
                <div class="image-frame-inner1">
                  <ElSlider class="tilt-slider" v-model="tilt" :min="0" :max="180" vertical :show-input-controls="false" height="100%" @change="Move" @input="Move" />
                  <img class="still-image" :src="stillImage">
                </div>
                <div class="image-frame-inner2">
                  <ElSlider class="pan-slider" v-model="pan" :min="0" :max="355" :show-input-controls="false" @change="Move" @input="Move" />
                </div>
              </div>
              <div class="cruise-padding" />
              <SettingCruise v-for="(cruise, idx) of cruiseList" :key="'timetable'+idx" v-model="cruiseList[idx]" :pan="pan" :tilt="tilt" :selected="cruiseSelect === idx" @add="AddCruise" @remove="DeleteCruise(idx)" @pan="pan=$event" @tilt="tilt=$event" @click="CruiseSelect(idx)" />
            </div>
          </div>
        </ElTabPane>

        <!-- System Setting Tab -->
        <ElTabPane class="well-transparent container" :label="$t('systemSettings.tab')">
          <h3 v-t="'deviceSettings.title'" />
          <SettingInput i18n="deviceSettings.deviceName" type="text" v-model="config.HOSTNAME" />
          <SettingSwitch i18n="deviceSettings.loginAuthentication" v-model="loginAuth" />
          <SettingInput v-if="loginAuth==='on'" i18n="deviceSettings.account" type="text" v-model="account" />
          <SettingInput v-if="loginAuth==='on'" i18n="deviceSettings.password" type="password" v-model="password" />

          <h3 v-t="'motionDetect.title'" />
          <SettingSwitch i18n="motionDetect.sensorPeriod" v-model="config.MINIMIZE_ALARM_CYCLE" />
          <SettingSwitch i18n="motionDetect.uploadStop" v-model="config.AWS_VIDEO_DISABLE" />

          <h3 v-t="'videoSpec.title'" />
          <SettingInputNumber i18n="videoSpec.frameRate" :withSwitch="true" :defaultValue="20" :span="3" v-model="config.FRAMERATE" :min="1" :max="30" />
          <SettingInputNumber i18n="videoSpec.bitrateMain" :withSwitch="true" :span="3" v-model="config.BITRATE_MAIN_AVC" :min="300" :max="2000" />
          <SettingInputNumber v-if="distributor === 'ATOM'" i18n="videoSpec.bitrateMainHEVC" :withSwitch="true" :span="3" v-model="config.BITRATE_MAIN_HEVC" :min="300" :max="2000" />
          <SettingInputNumber i18n="videoSpec.bitrateSub" :withSwitch="true" :span="3" v-model="config.BITRATE_SUB_HEVC" :min="100" :max="500" />
        </ElTabPane>

        <!-- Maintenance Tab -->
        <ElTabPane class="well-transparent container" :label="$t('maintenance.tab')">
          <h3 v-t="'monitoring.title'" />
          <SettingSwitch i18n="monitoring.network" v-model="config.MONITORING_NETWORK" />
          <SettingSwitch v-if="config.MONITORING_NETWORK === 'on'" i18n="monitoring.reboot" v-model="config.MONITORING_REBOOT" :titleOffset="2" />
          <SettingSwitch i18n="monitoring.ping" v-model="config.HEALTHCHECK" />
          <SettingInput v-if="config.HEALTHCHECK === 'on'" i18n="monitoring.URL" :titleOffset="2" :span="10" type="text" v-model="config.HEALTHCHECK_PING_URL" />

          <h3 v-t="'update.title'" />
          <SettingDangerButton i18n="update.toolsUpdate" icon="el-icon-refresh" :button="config.CUSTOM_ZIP === 'on' ? 'Custom Update' : 'Update'" :disabled="!updatable" @click="DoUpdate">
            <span class="latest" :class="{ 'latest-updatable': updatable }">
              Latest Version : Ver.{{ latestVer }}
            </span>
          </SettingDangerButton>
          <SettingSwitch i18n="update.customZip" v-model="config.CUSTOM_ZIP" />
          <SettingInput v-if="config.CUSTOM_ZIP === 'on'" i18n="update.customZip.URL" :titleOffset="2" :span="10" type="text" v-model="config.CUSTOM_ZIP_URL" placeholder="https://github.com/mnakada/atomcam_tools/releases/latest/download/atomcam_tools.zip" />

          <h3 v-t="'reboot.title'" />
          <SettingSwitch i18n="reboot.periodicRestart" v-model="config.REBOOT" />
          <SettingSchedule v-if="config.REBOOT === 'on'" v-model="reboot" />
          <SettingDangerButton i18n="reboot.reboot" icon="el-icon-refresh-left" @click="DoReboot" />
        </ElTabPane>
      </ElTabs>
    </div>

    <div v-if="selectedTab >= 2" class="submit">
      <ElButton @click="Submit" type="primary" v-t="'submit'" />
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
  import { Drawer, Slider, ButtonGroup, Tabs, TabPane } from 'element-ui';
  import SettingSwitch from './SettingSwitch.vue';
  import SettingInput from './SettingInput.vue';
  import SettingInputNumber from './SettingInputNumber.vue';
  import SettingButton from './SettingButton.vue';
  import SettingComment from './SettingComment.vue';
  import SettingDangerButton from './SettingDangerButton.vue';
  import SettingSchedule from './SettingSchedule.vue';
  import SettingProgress from './SettingProgress.vue';
  import SettingCruise from './SettingCruise.vue';

  import 'element-ui/lib/theme-chalk/drawer.css';
  import 'element-ui/lib/theme-chalk/slider.css';
  import 'element-ui/lib/theme-chalk/button-group.css';
  import 'element-ui/lib/theme-chalk/tabs.css';
  import 'element-ui/lib/theme-chalk/tab-pane.css';

  export default {
    name: 'ATOMCamSetting',
    components: {
      ElDrawer: Drawer,
      ElSlider: Slider,
      ElButtonGroup: ButtonGroup,
      ElTabs: Tabs,
      ElTabPane: TabPane,
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
          CONFIG_VER: '1.0.0',
          appver: '', // ATOMCam app_ver (/atom/config/app.ver)
          ATOMHACKVER: '', // AtomHack Ver (/etc/atomhack.ver)
          PRODUCT_MODEL: '', // ATOMCam Model (/atom/configs/.product_config)
          HOSTNAME: 'atomcam', // ATOMHack hostname (/media/mmc/hostname)
          DIGEST: '',
          REBOOT: 'off',
          REBOOT_SCHEDULE: '0 2 * * 7', // -> /var/spool/crontabs/root
          RTSP_VIDEO0: 'off',
          RTSP_AUDIO0: 'off',
          RTSP_VIDEO1: 'off',
          RTSP_AUDIO1: 'off',
          RTSP_VIDEO2: 'off',
          RTSP_AUDIO2: 'off',
          RTSP_OVER_HTTP: 'off',
          RTSP_AUTH: 'off',
          RTSP_USER: '',
          RTSP_PASSWD: '',
          PERIODICREC_SDCARD: 'on',
          PERIODICREC_SDCARD_REMOVE: 'off',
          PERIODICREC_SDCARD_REMOVE_DAYS: 30,
          PERIODICREC_CIFS: 'off',
          PERIODICREC_CIFS_PATH: '%Y%m%d/%H%M%S',
          PERIODICREC_CIFS_REMOVE: 'off',
          PERIODICREC_CIFS_REMOVE_DAYS: 30,
          PERIODICREC_SCHEDULE: 'off',
          PERIODICREC_SCHEDULE_LIST: '',
          ALARMREC_SDCARD: 'on',
          ALARMREC_SDCARD_PATH: '%Y%m%d/%H%M%S',
          ALARMREC_SDCARD_REMOVE: 'off',
          ALARMREC_SDCARD_REMOVE_DAYS: 30,
          ALARMREC_CIFS: 'off',
          ALARMREC_CIFS_PATH: '%Y%m%d/%H%M%S',
          ALARMREC_CIFS_REMOVE: 'off',
          ALARMREC_CIFS_REMOVE_DAYS: 30,
          ALARMREC_SCHEDHULE: 'off',
          ALARMREC_SCHEDULE_LIST: '',
          TIMELAPSE_SDCARD: 'off',
          TIMELAPSE_SDCARD_PATH: '%Y%m%d%H%M',
          TIMELAPSE_SDCARD_REMOVE: 'off',
          TIMELAPSE_SDCARD_REMOVE_DAYS: 30,
          TIMELAPSE_CIFS: 'off',
          TIMELAPSE_CIFS_PATH: '%Y%m%d%H%M',
          TIMELAPSE_CIFS_REMOVE: 'off',
          TIMELAPSE_CIFS_REMOVE_DAYS: 30,
          TIMELAPSE_SCHEDULE: '0 4 * * 0:1:2:3:4:5:6', // -> /var/spool/crontabs/root
          TIMELAPSE_INTERVAL: 60,
          TIMELAPSE_COUNT: 960,
          TIMELAPSE_FPS: 20,
          STORAGE_SDCARD_PUBLISH: 'off',
          STORAGE_SDCARD_DIRECT_WRITE: 'off',
          STORAGE_CIFSSERVER: '',
          STORAGE_CIFSUSER: '',
          STORAGE_CIFSPASSWD: '',
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
        alarmRecSchedule: [],
        periodicRecSchedule: [],
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
        stillInterval: 500,
        latestVer: '',
        executing: false,
        rebooting: false,
        stillImage: null,
        pan: 0,
        tilt: 0,
        posValid: false,
        selectedTab: 0,
      };
    },
    computed: {
      distributor() {
        return this.config.PRODUCT_MODEL.replace(/_.*$/, '');
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
        const auth = (this.config.RTSP_AUTH === 'on') && (this.config.RTSP_USER !== '') && (this.config.RTSP_PASSWD !== '') ? `${this.config.RTSP_USER}:${this.config.RTSP_PASSWD}@` : '';
        return `rtsp://${auth}${window.location.host}:${port}/${video}_unicast`;
      },
      RtspUrl1() {
        const port = (this.config.RTSP_OVER_HTTP  === 'on') ? 8080 : 8554;
        const auth = (this.config.RTSP_AUTH === 'on') && (this.config.RTSP_USER !== '') && (this.config.RTSP_PASSWD !== '') ? `${this.config.RTSP_USER}:${this.config.RTSP_PASSWD}@` : '';
        return `rtsp://${auth}${window.location.host}:${port}/video1_unicast`;
      },
      RtspUrl2() {
        const port = (this.config.RTSP_OVER_HTTP  === 'on') ? 8080 : 8554;
        const auth = (this.config.RTSP_AUTH === 'on') && (this.config.RTSP_USER !== '') && (this.config.RTSP_PASSWD !== '') ? `${this.config.RTSP_USER}:${this.config.RTSP_PASSWD}@` : '';
        return `rtsp://${auth}${window.location.host}:${port}/video2_unicast`;
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

      for(let schedule in ['periodicRec', 'alarmRec']) {
        const confKey = schedule.toUpperCase() + '_SCHEDULE_LIST';
        const innerKey = schedule + 'Schedule';
        if(this.config[confKey]) {
          let index = -1;

          this.$set(this, innerKey, this.config[confKey].split(';').reduce((d, l) => {
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
          }, []));
        }
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
      HandleTabsClick(tab) {
        this.selectedTab = parseInt(tab.index);
      },
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
      AddSchedule(schedule) {
        this[schedule].push({
          allDay: true,
          startTime: '00:00',
          endTime: '23:59',
          dayOfWeekSelect: [0, 1, 2, 3, 4, 5, 6],
        });
      },
      DeleteSchedule(schedule, i, confKey) {
        this[schedule].splice(i, 1);
        if(!this[schedule].length) this.$set(this.config, confKey, 'off');
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

        for(let schedule in ['periodicRec', 'alarmRec']) {
          const confKey = schedule.toUpperCase() + '_SCHEDULE_LIST';
          const innerKey = schedule + 'Schedule';
          let str = '';
          for(const i in this[innerKey]) {
            const timeTable = this[innerKey][i];
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
          this.$set(this.config, confKey, str);
        }

        if(this.config.PERIODICREC_SDCARD !== 'on' && this.config.ALARMREC_SDCARD !== 'on' && this.config.TIMELAPSE_SDCARD !== 'on') this.config.STORAGE_SDCARD_PUBLISH = 'off';

        this.config.LOCALE = this.$i18n.locale;
        this.config.TIMELAPSE_INTERVAL = this.timelapse.interval;
        this.config.TIMELAPSE_COUNT = this.timelapse.count;
        this.config.TIMELAPSE_SCHEDULE = parseInt(this.timelapse.startTime.slice(-2)) + ' ' +
          parseInt(this.timelapse.startTime.slice(0, 2)) + ' * * ' +
          this.timelapse.dayOfWeekSelect.sort((a, b) => a - b).reduce((v, d) => v + (v.length ? ':' : '') + ((d + 1) % 7).toString(), '');

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

        this.config.REBOOT_SCHEDULE = parseInt(this.reboot.startTime.slice(-2)) + ' ' +
          parseInt(this.reboot.startTime.slice(0, 2)) + ' * * ' +
          this.reboot.dayOfWeekSelect.sort((a, b) => a - b).reduce((v, d) => v + (v.length ? ':' : '') + ((d + 1) % 7).toString(), '');

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
        if((this.config.STORAGE_SDCARD !== this.oldConfig.STORAGE_SDCARD) ||
           (this.config.STORAGE_SDCARD_DIRECT_WRITE !== this.oldConfig.STORAGE_SDCARD_DIRECT_WRITE)) {
          let periodic = 'ram';
          let alarm = 'ram';
          if(this.config.STORAGE_SDCARD_DIRECT_WRITE === 'on') {
            if((this.config.STORAGE_SDCARD === 'on') || (this.config.STORAGE_SDCARD === 'record')) periodic = 'sd';
            if((this.config.STORAGE_SDCARD === 'on') || (this.config.STORAGE_SDCARD === 'alarm')) alarm = 'sd';
          }
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
             (this.config.RTSP_MAIN_FORMAT_HEVC !== this.oldConfig.RTSP_MAIN_FORMAT_HEVC) ||
             (this.config.RTSP_AUTH !== this.oldConfig.RTSP_AUTH) ||
             (this.config.RTSP_USER !== this.oldConfig.RTSP_USER) ||
             (this.config.RTSP_PASSWD !== this.oldConfig.RTSP_PASSWD)) {
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
    height:60px;
  }

  .title_ATOM {
    color: white;
    background-color: #bc423a;
  }

  .title_WYZE {
    color: white;
    background-color: #1abadd;
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
    height: calc(100dvh - 200px);
    margin: 10px 20px 5px 20px;
    overflow-x: hidden;
    overflow-y: scroll;
  }

  .container-no-submit {
    height: calc(100vh - 85px);
    height: calc(100dvh - 85px);
    margin: 5px;
    padding: 5px;
    display: flex;
    justify-content: flex-end;
  }

  .image-frame {
    z-index: 100;
    display: flex;
    flex-direction: column;
    width: calc(min(100%, (100vh - 140px) * 1920 / 1080));
    width: calc(min(100%, (100dvh - 140px) * 1920 / 1080));
    padding-bottom: 100%;
  }

  .image-frame-cruise {
    width: 30vw;
    width: 30dvw;
    position:fixed;
    right: 30px;
    top: 100px;
    padding: 0;
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
    width: calc(100% - 38px);
    object-fit: contain;
  }

  .pan-slider {
    background-color: white;
    width: calc(100% - 38px);
  }

  .tilt-slider {
    background-color: white;
    align-items: stretch;
  }

  .sdcard-frame {
    width: 100%;
    border: none;
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

  .cruise-padding {
    padding-bottom: 150px;
  }
</style>
