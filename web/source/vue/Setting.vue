<template>
  <div @mousemove="MouseMove" @mouseleave="MouseLeave" @mouseup="MouseLeave">
    <div v-if="distributer !== ''" class="title" :class="'title_' + distributor">
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
        {{ timestamp }}
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
      <ElTabs v-model="selectedTab" tabPosition="left" @tab-click="HandleTabsClick">
        <!-- Camera Tab -->
        <ElTabPane name="camera" class="well-transparent container-flex-no-submit" :label="$t('camera.tab')">
          <div v-if="selectedTab === 'camera'" class="image-frame">
            <div class="image-frame-inner1">
              <ElSlider v-if="isSwing && posValid" class="tilt-slider" v-model="tilt" :min="0" :max="180" vertical :show-input-controls="false" height="100%" @change="Move" @input="Move" />
              <img class="still-image" :src="stillImage">
            </div>
            <div v-if="isSwing && posValid" class="image-frame-inner2">
              <ElSlider class="pan-slider" v-model="pan" :min="0" :max="355" :show-input-controls="false" @change="Move" @input="Move" />
            </div>
            <div v-if="!drawerVisible" class="image-frame-inner3">
              <i class="el-icon-moon ir-led" />
              <ElButtonGroup>
                <ElButton size="mini" type="primary" @click="NightVision('on')">
                  on
                </ElButton>
                <ElButton size="mini" type="primary" @click="NightVision('auto')">
                  auto
                </ElButton>
                <ElButton size="mini" type="primary" @click="NightVision('off')">
                  off
                </ElButton>
              </ElButtonGroup>
              <ElButton class="center-mark" size="mini" type="primary" icon="el-icon-aim" @click="CenterMark" />
              <ElButton v-if="distributor !== 'ATOM'" class="video-flip" size="mini" type="primary" icon="el-icon-refresh" @click="VideoFlip" />
            </div>
          </div>
        </ElTabPane>

        <!-- Camera Settings Tab -->

        <ElTabPane name="CameraSettings" v-if="distributor === 'ATOM'" class="well-transparent container-no-submit" :label="$t('CameraSettings.tab')">
          <h3 v-t="'FeatureSettings.title'" />
          <SettingSelect i18n="FeatureSettings.nightVision" v-model="property.nightVision" :label="['on', 'auto', 'off']" @input="CameraSet('nightVision')" />
          <SettingSwitch v-if="property.nightVision==='auto'" i18n="FeatureSettings.nightCutThr" :titleOffset="2" v-model="property.nightCutThr" :label="['dusk', 'dark']" @input="CameraSet('nightCutThr')" />
          <SettingSwitch v-if="property.nightVision==='on' || property.nightVision==='auto'" i18n="FeatureSettings.IrLED" :titleOffset="2" v-model="property.IrLED" @input="CameraSet('IrLED')" />
          <h3 v-t="'AlarmSettings.title'" />
          <SettingSwitch i18n="AlarmSettings.motionDet" v-model="property.motionDet" @input="CameraSet('motionDet')" />
          <SettingSelect v-if="property.motionDet=='on'" i18n="AlarmSettings.Level" :titleOffset="2" v-model="property.motionLevel" :label="['high', 'mid', 'low']" @input="CameraSet('motionLevel')" />
          <SettingSwitch v-if="property.motionDet==='on'" i18n="AlarmSettings.motionArea" :titleOffset="2" v-model="property.motionArea" :label="['all', 'rect']" @input="MotionArea" />
          <SettingSwitch i18n="AlarmSettings.soundDet" v-model="property.soundDet" @input="CameraSet('soundDet')" />
          <SettingSelect v-if="property.soundDet=='on'" i18n="AlarmSettings.Level" :titleOffset="2" v-model="property.soundLevel" :label="['high', 'mid', 'low']" @input="CameraSet('soundLevel')" />
          <SettingSwitch i18n="AlarmSettings.cautionDet" v-model="property.cautionDet" @input="CameraSet('cautionDet')" />
          <SettingSwitch i18n="AlarmSettings.drawBoxSwitch" v-model="property.drawBoxSwitch" @input="CameraSet('drawBoxSwitch')" />
          <SettingSelect i18n="AlarmSettings.recordType" v-model="property.recordType" :label="['cont', 'motion', 'off']" @input="CameraSet('recordType')" />
          <h3 v-t="'OtherSettings.title'" />
          <SettingSwitch i18n="OtherSettings.indicator" v-model="property.indicator" @input="CameraSet('indicator')" />
          <SettingSwitch i18n="OtherSettings.rotate" v-model="property.rotate" @input="CameraSet('rotate')" />
          <SettingSwitch i18n="OtherSettings.audioRec" v-model="property.audioRec" @input="CameraSet('audioRec')" />
          <SettingSwitch i18n="OtherSettings.timestamp" v-model="property.timestamp" @input="CameraSet('timestamp')" />
          <SettingSwitch i18n="OtherSettings.watermark" v-model="property.watermark" @input="CameraSet('watermark')" />
          <h3 v-t="'AdvancedSettings.title'" />
          <SettingSlider i18n="AdvancedSettings.contrast" v-model="ISPSettings.cont" :min="0" :max="255" :defaultValue="128" :stemp="1" @input="ISPSet('cont')" />
          <SettingSlider i18n="AdvancedSettings.brightness" v-model="ISPSettings.bri" :min="0" :max="255" :defaultValue="128" :stemp="1" @input="ISPSet('bri')" />
          <SettingSlider i18n="AdvancedSettings.saturation" v-model="ISPSettings.sat" :min="0" :max="255" :defaultValue="128" :stemp="1" @input="ISPSet('sat')" />
          <SettingSlider i18n="AdvancedSettings.sharpness" v-model="ISPSettings.sharp" :min="0" :max="255" :defaultValue="128" :stemp="1" @input="ISPSet('sharp')" />
          <SettingSlider i18n="AdvancedSettings.sinter" v-model="ISPSettings.sinter" :min="0" :max="255" :defaultValue="128" :stemp="1" @input="ISPSet('sinter')" />
          <SettingSlider i18n="AdvancedSettings.temper" v-model="ISPSettings.temper" :min="0" :max="255" :defaultValue="128" :stemp="1" @input="ISPSet('temper')" />
          <SettingSlider i18n="AdvancedSettings.dpc" v-model="ISPSettings.dpc" :min="0" :max="255" :defaultValue="128" :stemp="1" @input="ISPSet('dpc')" />
          <SettingSlider i18n="AdvancedSettings.drc" v-model="ISPSettings.drc" :min="0" :max="255" :defaultValue="128" :stemp="1" @input="ISPSet('drc')" />
          <SettingSlider i18n="AdvancedSettings.hilight" v-model="ISPSettings.hilight" :min="0" :max="10" :defaultValue="2" :stemp="1" @input="ISPSet('hilight')" />
          <SettingSlider i18n="AdvancedSettings.again" v-model="ISPSettings.again" :min="0" :max="255" :defaultValue="205" :stemp="1" @input="ISPSet('again')" />
          <SettingSlider i18n="AdvancedSettings.dgain" v-model="ISPSettings.dgain" :min="0" :max="255" :defaultValue="64" :stemp="1" @input="ISPSet('dgain')" />
          <SettingSwitch i18n="AdvancedSettings.expmode" v-model="ISPSettings.expmode" :label="['auto', 'manual']" @input="ISPSet('expmode')" />
          <div v-if="ISPSettings.expmode === 'auto'">
            <SettingSlider i18n="AdvancedSettings.aecomp" v-model="ISPSettings.aecomp" :min="0" :max="255" :defaultValue="128" :stemp="1" @input="ISPSet('aecomp')" />
            <SettingSlider i18n="AdvancedSettings.aeitmin" v-model="ISPSettings.aeitmin" :min="1" :max="ISPSettings.aeitmax" :defaultValue="1" :stemp="1" @input="ISPSet('aeitmin')" />
            <SettingSlider i18n="AdvancedSettings.aeitmax" v-model="ISPSettings.aeitmax" :min="ISPSettings.aeitmin" :max="1683" :defaultValue="1200" :stemp="1" @input="ISPSet('aeitmax')" />
          </div>
          <div v-else>
            <SettingSlider i18n="AdvancedSettings.expline" v-model="ISPSettings.expline" :min="1" :max="1683" :defaultValue="1200" :stemp="1" @input="ISPSet('expline')" />
          </div>

          <div v-if="selectedTab === 'CameraSettings'">
            <div class="image-frame image-frame-camera-settings">
              <div class="image-frame-inner1">
                <img class="still-image" :src="stillImage">
              </div>
            </div>
            <div class="image-overlay image-frame-camera-settings">
              <div class="image-frame-inner4">
                <svg class="image-svg">
                  <g v-if="(property.motionArea==='rect') && (motionArea.valid===3)">
                    <rect class="motionAreaRect" :x="motionAreaSVG.sx" :y="motionAreaSVG.sy" :width="motionAreaSVG.dx - motionAreaSVG.sx" :height="motionAreaSVG.dy - motionAreaSVG.sy" />
                    <line class="motionAreaHandle" :x1="motionAreaSVG.sx" :y1="motionAreaSVG.sy" :x2="motionAreaSVG.dx" :y2="motionAreaSVG.sy" @mousedown.prevent.stop="MouseDown(0, 1, $event)" />
                    <line class="motionAreaHandle" :x1="motionAreaSVG.dx" :y1="motionAreaSVG.sy" :x2="motionAreaSVG.dx" :y2="motionAreaSVG.dy" @mousedown.prevent.stop="MouseDown(2, 0, $event)" />
                    <line class="motionAreaHandle" :x1="motionAreaSVG.sx" :y1="motionAreaSVG.dy" :x2="motionAreaSVG.dx" :y2="motionAreaSVG.dy" @mousedown.prevent.stop="MouseDown(0,2, $event)" />
                    <line class="motionAreaHandle" :x1="motionAreaSVG.sx" :y1="motionAreaSVG.sy" :x2="motionAreaSVG.sx" :y2="motionAreaSVG.dy" @mousedown.prevent.stop="MouseDown(1,0, $event)" />
                    <rect class="motionAreaHandle" :x="motionAreaSVG.sx - motionAreaSVG.hx" :y="motionAreaSVG.sy - motionAreaSVG.hy" :width="motionAreaSVG.hx * 2" :height="motionAreaSVG.hy * 2" @mousedown.prevent.stop="MouseDown(1, 1, $event)" />
                    <rect class="motionAreaHandle" :x="motionAreaSVG.dx - motionAreaSVG.hx" :y="motionAreaSVG.sy - motionAreaSVG.hy" :width="motionAreaSVG.hx * 2" :height="motionAreaSVG.hy * 2" @mousedown.prevent.stop="MouseDown(2, 1, $event)" />
                    <rect class="motionAreaHandle" :x="motionAreaSVG.dx - motionAreaSVG.hx" :y="motionAreaSVG.dy - motionAreaSVG.hy" :width="motionAreaSVG.hx * 2" :height="motionAreaSVG.hy * 2" @mousedown.prevent.stop="MouseDown(2, 2, $event)" />
                    <rect class="motionAreaHandle" :x="motionAreaSVG.sx - motionAreaSVG.hx" :y="motionAreaSVG.dy - motionAreaSVG.hy" :width="motionAreaSVG.hx * 2" :height="motionAreaSVG.hy * 2" @mousedown.prevent.stop="MouseDown(1, 2, $event)" />
                  </g>
                </svg>
              </div>
            </div>
          </div>
        </ElTabPane>

        <!-- SD-Card Tab -->
        <ElTabPane name="SDCard" class="well-transparent container-flex-no-submit" :label="$t('SDCard.tab')">
          <iframe ref="sdcardFrame" class="sdcard-frame" src="/sdcard" />
        </ElTabPane>

        <!-- Record Setting Tab -->
        <ElTabPane name="record" class="well-transparent container" :label="$t('record.tab')">
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
            <SettingComment v-if="property.recordType === 'off'" i18n="record.recordTypeWarn" color="red" weight="bold" />
            <SettingSwitch i18n="record.recordingSchedule" v-model="config.PERIODICREC_SCHEDULE" @change="(config.PERIODICREC_SCHEDULE === 'on') && !periodicRecSchedule.length && AddSchedule('periodicRecSchedule')" />
            <div v-if="config.PERIODICREC_SCHEDULE === 'on'">
              <SettingSchedule v-for="(timeTable, idx) of periodicRecSchedule" :key="'timetable'+idx" :timeRange="true" :removeSchedule="true" v-model="periodicRecSchedule[idx]" @add="AddSchedule('periodicRecSchedule')" @remove="DeleteSchedule('periodicRecSchedule', idx, 'PERIODICREC_SCHEDULE')" />
            </div>
            <SettingSwitch i18n="record.skipJpeg" v-model="config.PERIODICREC_SKIP_JPEG" />
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
            <SettingComment v-if="(property.motionDet === 'off') && (property.soundDet === 'off') && (property.cautionDet === 'off')" i18n="record.alarmRecWarn" color="red" weight="bold" />
            <SettingSwitch i18n="record.recordingSchedule" v-model="config.ALARMREC_SCHEDULE" @change="(config.ALARMREC_SCHEDULE === 'on') && !alarmRecSchedule.length && AddSchedule('alarmRecSchedule')" />
            <div v-if="config.ALARMREC_SCHEDULE === 'on'">
              <SettingSchedule v-for="(timeTable, idx) of alarmRecSchedule" :key="'timetable'+idx" :timeRange="true" :removeSchedule="true" v-model="alarmRecSchedule[idx]" @add="AddSchedule('alarmRecSchedule')" @remove="DeleteSchedule('alarmRecSchedule', idx, 'ALARMREC_SCHEDULE')" />
            </div>
          </div>
        </ElTabPane>

        <!-- Timelapse Tab -->
        <ElTabPane name="timelapse" class="well-transparent container" :label="$t('timelapse.tab')">
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
            <SettingSchedule v-for="(timeTable, idx) of timelapseSchedule" :key="'timetable'+idx" :timelapse="true" :removeSchedule="timelapseSchedule.length > 1" :i18n="idx?'':'timelapse.setting'" v-model="timelapseSchedule[idx]" @add="AddTimelapseSchedule()" @remove="DeleteTimelapseSchedule(idx)" />
            <SettingComment i18n="timelapse.note" />
            <SettingInputNumber i18n="timelapse.fps" :span="3" v-model="config.TIMELAPSE_FPS" :min="1" :max="60" />
            <SettingProgress v-if="timelapseInfo.busy" i18n="timelapse.start" :percentage="timelapseInfo.count * 100 / timelapseInfo.max" :label="timelapseInfo.count.toString() + '/' + timelapseInfo.max.toString()" />
            <SettingDangerButton v-if="timelapseInfo.busy" i18n="timelapse.stop" icon="el-icon-refresh-left" @click="TimelapseAbort">
              <span v-if="timelapseInfo.abort" v-t="timelapse.stop.comment" />
            </SettingDangerButton>
          </div>
        </ElTabPane>

        <!-- Media Setting Tab -->
        <ElTabPane name="media" class="well-transparent container" :label="$t('media.tab')">
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
        <ElTabPane name="streaming" class="well-transparent container" :label="$t('RTSP.tab')">
          <h3 v-t="'RTSP.title'" />
          <SettingSwitch i18n="RTSP.main" v-model="config.RTSP_VIDEO0" />
          <SettingSelect v-if="config.RTSP_VIDEO0 === 'on'" i18n="RTSP.main.audio" :titleOffset="2" v-model="config.RTSP_AUDIO0" :label="['off', 'S16_BE', 'AAC', 'OPUS']" />
          <SettingComment v-if="config.RTSP_VIDEO0 === 'on' && (config.RTSP_AUDIO0 !== 'AAC' && config.RTSP_AUDIO0 !=='off') && config.RTMP_ENABLE === 'on'" i18n="RTSP.main.note" color="red" weight="bold" />
          <SettingInput v-if="config.RTSP_VIDEO0 === 'on'" i18n="RTSP.main.URL" :titleOffset="2" :span="10" type="readonly" v-model="RtspUrl0" />
          <div v-if="distributor === 'ATOM'">
            <SettingSwitch i18n="RTSP.mainHEVC" v-model="config.RTSP_VIDEO2" />
            <SettingSelect v-if="config.RTSP_VIDEO2 === 'on'" i18n="RTSP.mainHEVC.audio" :titleOffset="2" v-model="config.RTSP_AUDIO2" :label="['off', 'S16_BE', 'AAC', 'OPUS']" />
            <SettingInput v-if="config.RTSP_VIDEO2 === 'on'" i18n="RTSP.mainHEVC.URL" :titleOffset="2" :span="10" type="readonly" v-model="RtspUrl2" />
          </div>
          <SettingSwitch i18n="RTSP.sub" v-model="config.RTSP_VIDEO1" />
          <SettingSelect v-if="config.RTSP_VIDEO1 === 'on'" i18n="RTSP.sub.audio" :titleOffset="2" v-model="config.RTSP_AUDIO1" :label="['off', 'S16_BE', 'AAC', 'OPUS']" />
          <SettingInput v-if="config.RTSP_VIDEO1 === 'on'" i18n="RTSP.sub.URL" :titleOffset="2" :span="10" type="readonly" v-model="RtspUrl1" />
          <div v-if="(config.RTSP_VIDEO0 === 'on') || (config.RTSP_VIDEO1 === 'on') || (config.RTSP_VIDEO2 === 'on')">
            <SettingSwitch i18n="RTSP.http" v-model="config.RTSP_OVER_HTTP" />
            <SettingSwitch i18n="RTSP.auth" v-model="config.RTSP_AUTH" />
            <SettingInput v-if="config.RTSP_AUTH === 'on'" i18n="RTSP.account" type="text" :titleOffset="2" v-model="config.RTSP_USER" />
            <SettingInput v-if="config.RTSP_AUTH === 'on'" i18n="RTSP.password" type="password" :titleOffset="2" v-model="config.RTSP_PASSWD" show-password />
          </div>

          <h3 v-t="'HomeKit.title'" />
          <SettingSwitch i18n="HomeKit" :value="(config.RTSP_VIDEO0 == 'on') ? config.HOMEKIT_ENABLE : 'off'" @input="config.HOMEKIT_ENABLE=$event" :disabled="config.RTSP_VIDEO0 !== 'on'" />
          <SettingComment v-if="config.RTSP_VIDEO0 === 'on' && config.RTSP_AUDIO0 !== 'OPUS' && config.RTSP_AUDIO0 !== 'off' && config.HOMEKIT_ENABLE === 'on'" i18n="HomeKit.note" color="red" weight="bold" />
          <div v-if="homeKitSetupURI !== '' && homekitPairing !== '' && config.RTSP_VIDEO0 === 'on' && config.HOMEKIT_ENABLE === 'on'">
            <SettingDangerButton v-if="homeKitPairing == 'paired'" i18n="HomeKit.unpair" button="Unpair" icon="el-icon-scissors" :titleOffset="2" @click="UnpairHomeKit" />
            <ElRow v-else>
              <ElCol :offset="9" :span="10">
                <div class="homekit">
                  <QrcodeVue class="homekit-qrcode" :value="homeKitSetupURI" size="150" />
                  <div class="homekit-setupcode">
                    {{ homeKitSetupCode }}
                  </div>
                </div>
              </ElCol>
            </ElRow>
            <ElRow>
              <ElCol :offset="9" :span="10">
                <h4 class="homekit-deviceid">
                  DeviceID : {{ config.HOMEKIT_DEVICE_ID }}
                </h4>
              </ElCol>
            </ElRow>
          </div>

          <h3 v-t="'RTMP.title'" />
          <SettingSwitch i18n="RTMP" :value="(config.RTSP_VIDEO0 == 'on' && (config.RTSP_AUDIO0 == 'AAC' || config.RTSP_AUDIO0 == 'off')) ? config.RTMP_ENABLE : 'off'" @input="config.RTMP_ENABLE=$event" :disabled="config.RTSP_VIDEO0 !== 'on' || (config.RTSP_AUDIO0 !== 'AAC' && config.RTSP_AUDIO0 !== 'off')" />
          <SettingInput v-if="config.RTMP_ENABLE === 'on'" i18n="RTMP.URL" :titleOffset="2" :span="8" v-model="config.RTMP_URL" placeholder="rtmp://<server addr>/<livekey>">
            <ElButton @click="RTMPRestart" type="primary" v-t="'RTMP.Restart'" />
          </SettingInput>

          <h3 v-t="'WebRTC.title'" />
          <SettingSwitch i18n="WebRTC" :value="(config.RTSP_VIDEO0 == 'on') ? config.WEBRTC_ENABLE : 'off'" @input="config.WEBRTC_ENABLE=$event" :disabled="config.RTSP_VIDEO0 !== 'on'" />
          <SettingComment v-if="config.RTSP_VIDEO0 === 'on' && config.RTSP_AUDIO0 !== 'OPUS' && config.RTSP_AUDIO0 !== 'off' && config.WEBRTC_ENABLE === 'on'" i18n="WebRTC.note" color="red" weight="bold" />
          <div v-if="(config.WEBRTC_ENABLE === 'on') && (oldConfig.WEBRTC_ENABLE === 'on')">
            <SettingInput i18n="WebRTC.URL" :titleOffset="2" :span="8" type="readonly" v-model="WebRTCUrl">
              <a :href="WebRTCUrl" target="_blank" class="el-button el-button--primary el-button--mini link-button">Link</a>
            </SettingInput>
          </div>
        </ElTabPane>

        <!-- Event Webhook Tab -->
        <ElTabPane name="event" class="well-transparent container" :label="$t('event.tab')">
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
        <ElTabPane v-if="isSwing && posValid" name="cruise" class="well-transparent container" :label="$t('cruise.tab')">
          <h3 v-t="'cruise.title'" />
          <SettingButton i18n="cruise.initialPosition" :span="4" @click="MoveInit" />
          <div @click="ClearCruiseSelect">
            <SettingSwitch i18n="cruise.cameraMotion" v-model="config.CRUISE" @change="(config.CRUISE === 'on') && !cruiseList.length && AddCruise()" @click.native.stop />
            <div v-if="(selectedTab === 'cruise') && (config.CRUISE === 'on')">
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
        <ElTabPane name="systemSettings" class="well-transparent container" :label="$t('systemSettings.tab')">
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
          <h3 v-t="'watermark.title'" />
          <SettingComment i18n="watermark.image">
            <div class="watermark-drop-area" :class="[{'is-drag': isDrag }]" @dragover.prevent="isDrag=true" @dragleave.prevent="isDrag=false" @drop.prevent="UploadPNG">
              <canvas id="watermark" />
            </div>
          </SettingComment>
        </ElTabPane>

        <!-- Maintenance Tab -->
        <ElTabPane name="maintenance" class="well-transparent container" :label="$t('maintenance.tab')">
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

    <div v-if="selectedTabIndex >= 3" class="submit">
      <ElButton @click="Submit" type="primary" v-t="'submit'" />
    </div>
    <ElDrawer :visible.sync="drawerVisible" direction="btt" :show-close="drawerClosable" :wrapperClosable="drawerClosable" :close-on-press-escape="drawerClosable" @closed="drawerClosable=false">
      <h4 class="comment" v-t="drawerComment" />
      <ElProgress v-if="progress > 0" :show-text="false" :stroke-width="18" :percentage="progress" class="progress progress-striped" />
    </ElDrawer>
  </div>
</template>

<script>
  import axios from 'axios';
  axios.defaults.headers.post['Content-Type'] = 'application/json;charset=utf-8';
  axios.defaults.headers.post['Access-Control-Allow-Origin'] = '*';
  import md5 from 'js-md5';
  import { Drawer, Slider, ButtonGroup, Tabs, TabPane, Progress } from 'element-ui';
  import SettingSwitch from './SettingSwitch.vue';
  import SettingSelect from './SettingSelect.vue';
  import SettingInput from './SettingInput.vue';
  import SettingInputNumber from './SettingInputNumber.vue';
  import SettingButton from './SettingButton.vue';
  import SettingComment from './SettingComment.vue';
  import SettingDangerButton from './SettingDangerButton.vue';
  import SettingSchedule from './SettingSchedule.vue';
  import SettingProgress from './SettingProgress.vue';
  import SettingCruise from './SettingCruise.vue';
  import SettingSlider from './SettingSlider.vue';
  import QrcodeVue from 'qrcode.vue';

  import 'element-ui/lib/theme-chalk/drawer.css';
  import 'element-ui/lib/theme-chalk/slider.css';
  import 'element-ui/lib/theme-chalk/button-group.css';
  import 'element-ui/lib/theme-chalk/tabs.css';
  import 'element-ui/lib/theme-chalk/tab-pane.css';
  import 'element-ui/lib/theme-chalk/progress.css';

  export default {
    name: 'ATOMCamSetting',
    components: {
      ElDrawer: Drawer,
      ElSlider: Slider,
      ElButtonGroup: ButtonGroup,
      ElTabs: Tabs,
      ElTabPane: TabPane,
      ElProgress: Progress,
      SettingSwitch,
      SettingSelect,
      SettingInput,
      SettingInputNumber,
      SettingButton,
      SettingComment,
      SettingDangerButton,
      SettingSchedule,
      SettingProgress,
      SettingCruise,
      SettingSlider,
      QrcodeVue,
    },
    data() {
      return {
        config: {
          CONFIG_VER: '1.0.1',
          appver: '', // ATOMCam app_ver (/atom/config/app.ver)
          ATOMHACKVER: '', // AtomHack Ver (/etc/atomhack.ver)
          PRODUCT_MODEL: '', // ATOMCam Model (/atom/configs/.product_config)
          HOSTNAME: 'atomcam', // ATOMHack hostname (/media/mmc/hostname)
          HWADDR: '', // Ether MacAddr
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
          HOMEKIT_ENABLE: 'off',
          HOMEKIT_SETUP_ID: '',
          HOMEKIT_DEVICE_ID: '',
          HOMEKIT_PIN: '',
          HOMEKIT_SOURCE: '',
          RTMP_ENABLE: 'off',
          RTMP_URL: '',
          WEBRTC_ENABLE: 'off',
          PERIODICREC_SDCARD: 'on',
          PERIODICREC_SDCARD_REMOVE: 'off',
          PERIODICREC_SDCARD_REMOVE_DAYS: 30,
          PERIODICREC_CIFS: 'off',
          PERIODICREC_CIFS_PATH: '%Y%m%d/%H%M%S',
          PERIODICREC_CIFS_REMOVE: 'off',
          PERIODICREC_CIFS_REMOVE_DAYS: 30,
          PERIODICREC_SCHEDULE: 'off',
          PERIODICREC_SCHEDULE_LIST: '',
          PERIODICREC_SKIP_JPEG: 'off',
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
          TIMELAPSE_SCHEDULE: '0 4 * * 0:1:2:3:4:5:6 /scripts/timelapse.sh start 60 960;', // -> /var/spool/crontabs/root
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
        property: {},
        ISPSettings: {
          cont: 128,
          bri: 128,
          sat: 128,
          sharp: 128,
          sinter: 128,
          temper: 128,
          dpc: 128,
          drc: 128,
          hilight: 2,
          again: 205,
          dgain: 64,
          aecomp: 128,
          expmode: 'auto',
          aeitmin: 1,
          aeitmax: 1200,
          expline: 1200,
        },
        loginAuth: 'off',
        loginAuth2: 'off',
        relm: 'atomcam',
        account: '',
        password: '',
        intervalValue: {
          TIMESTAMP: '',
        },
        motionArea: {
          sx: 0,
          sy: 0,
          dx: 99,
          dy: 99,
          scaleX: 0,
          scaleY: 0,
          svgX: 0,
          svgY: 0,
          modeX: 0,
          modeY: 0,
          valid: 0,
        },
        alarmRecSchedule: [],
        periodicRecSchedule: [],
        timelapseSchedule: [{
          dayOfWeekSelect: [0, 1, 2, 3, 4, 5, 6],
          startTime: '04:00',
          interval: 60,
          count: 960,
        }],
        timelapseInfo: {
          busy: false,
          abort: false,
        },
        homeKitPairing: '',
        homeKitSetupURI: '',
        homeKitSetupCode: '',
        rtspRestart: false,
        cruiseList: [],
        cruiseSelect: -1,
        reboot: {
          startTime: '02:00',
          endTime: '02:00',
          dayOfWeekSelect: [6],
        },
        stillInterval: 500,
        latestVer: '',
        drawerVisible: false,
        drawerClosable: false,
        drawerComment: '',
        progress: 0,
        stillImage: null,
        pan: 0,
        tilt: 0,
        posValid: false,
        moveDone: false,
        selectedTab: 'camera',
        selectedTabIndex: 0,
        centerMark: false,
        videoFlip: false,
        isDrag: false,
        watermarkUploaded: false,
      };
    },
    computed: {
      distributor() {
        if(this.config.PRODUCT_MODEL === 'AC1') return 'ATOM';
        return this.config.PRODUCT_MODEL.replace(/_.*$/, '');
      },
      timestamp() {
        if(this.$i18n.locale === 'ja') return this.intervalValue.TIMESTAMP;
        return new Date(this.intervalValue.TIMESTAMP).toLocaleString('en-US', { year:'numeric', month:'short', day:'numeric', hour:'2-digit', minute:'2-digit', second:'2-digit' });
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
        return !this.drawerVisible && (this.config.PRODUCT_MODEL === 'ATOM_CAKP1JZJP');
      },
      RtspUrl0() {
        const port = (this.config.RTSP_OVER_HTTP  === 'on') ? 8080 : 8554;
        const auth = (this.config.RTSP_AUTH === 'on') && (this.config.RTSP_USER !== '') && (this.config.RTSP_PASSWD !== '') ? `${this.config.RTSP_USER}:${this.config.RTSP_PASSWD}@` : '';
        return `rtsp://${auth}${window.location.host}:${port}/video0_unicast`;
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
      WebRTCUrl() {
        const opt = this.config.RTSP_AUDIO0 === 'OPUS' ? '?media=video+audio' : '';
        return `http://${window.location.host}/webrtc.html${opt}`;
      },
      motionAreaSVG() {
        return {
          sx: this.motionArea.sx * this.motionArea.scaleX + 5,
          sy: this.motionArea.sy * this.motionArea.scaleY + 5,
          dx: this.motionArea.dx * this.motionArea.scaleX + 5,
          dy: this.motionArea.dy * this.motionArea.scaleY + 5,
          hx: (this.motionArea.dx - this.motionArea.sx) * this.motionArea.scaleX / 12,
          hy: (this.motionArea.dy - this.motionArea.sy) * this.motionArea.scaleY / 12,
        };
      },
    },
    async mounted() {
      const res = await axios.get(`./cgi-bin/hack_ini.cgi?timestamp=${new Date().valueOf()}`).catch(err => {
        // eslint-disable-next-line no-console
        console.log('axios.get ./cgi-bin/hack_ini.cgi', err);
        return '';
      });

      this.oldConfig = (res?.data ?? '').split('\n').reduce((d, l) => {
        const name = l.split(/[ \t=]/)[0].trim();
        if(d[name] != null) d[name] = l.replace(new RegExp(name + '[ \t=]*'), '').trim();
        return d;
      }, Object.assign({}, this.config));
      this.config = Object.assign({}, this.oldConfig);
      // eslint-disable-next-line no-console
      console.log('config', this.config);

      const res2 = await axios.get(`./cgi-bin/video_isp.cgi?timestamp=$(new Date().valueOf()}`).catch(err => {
        // eslint-disable-next-line no-console
        console.log('axios.get ./cgi-bin/video_isp.cgi', err);
        return '';
      });
      (res2?.data ?? '').split('\n').forEach(l => {
        const name = l.split(/[ \t=]/)[0].trim();
        if(this.ISPSettings[name] != null) {
          if(typeof(this.ISPSettings[name]) === 'number') {
            this.$set(this.ISPSettings, name, parseInt(l.replace(new RegExp(name + '[ \t=]*'), '')));
          } else {
            this.$set(this.ISPSettings, name, l.replace(new RegExp(name + '[ \t=]*'), '').trim());
          }
        }
      });
      // eslint-disable-next-line no-console
      console.log('video isp', this.ISPSettings);

      if(this.config.LOCALE && (this.$i18n.availableLocales.indexOf(this.config.LOCALE) >= 0)) {
        this.$i18n.locale = this.config.LOCALE;
      } else {
        this.$i18n.locale = navigator.language.indexOf('en') === 0 ? 'en' : 'ja';
      }

      if(this.config.DIGEST.length) {
        this.loginAuth = 'on';
        this.account = this.config.DIGEST.replace(/:.*$/, '');
      }

      if(!this.config.HOMEKIT_SETUP_ID.length) {
        let sid = '';
        for(let i = 0; i < 4; i++) {
          sid += String.fromCharCode(Math.floor(Math.random() * 26) + 0x41);
        }
        this.config.HOMEKIT_SETUP_ID = sid;
      }
      if(!this.config.HOMEKIT_PIN.length) {
        this.config.HOMEKIT_PIN = Math.floor(Math.random() * 100000000).toString().padStart(8, '0');
      }
      if(!this.config.HOMEKIT_DEVICE_ID.length) {
        this.config.HOMEKIT_DEVICE_ID = this.config.HWADDR;
      }

      for(let schedule of ['periodicRec', 'alarmRec']) {
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
        this.timelapseSchedule = this.config.TIMELAPSE_SCHEDULE.split(';').flatMap(schedule => {
          if(schedule === '') return [];
          const str = schedule.split(' ');
          const days = (str[4] || '').split(':');
          return [{
            startTime: `${str[1].padStart(2, '0')}:${str[0].padStart(2, '0')}`,
            dayOfWeekSelect: days.map(d => (parseInt(d) + 6) % 7),
            interval: str[7],
            count: str[8],
          }];
        });
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

      this.GetCameraProperty();

      const data = (await axios.get('./cgi-bin/watermark.cgi', { responseType: 'arraybuffer' }).catch(err => {
        // eslint-disable-next-line no-console
        console.log('axios.get ./cgi-bin/watermark.cgi', err);
        return null;
      }))?.data;
      if(data && data.byteLength > 8) {
        const bgra = new Uint8Array(data);
        const height = bgra[0] | (bgra[1] << 8);
        const width = bgra[4] | (bgra[5] << 8);
        if(bgra.byteLength === 8 + width * height * 4) {
          const canvas = document.getElementById("watermark");
          canvas.width = width;
          canvas.height = height;
          canvas.style.width = `${width}px`;
          canvas.style.height = `${height}px`;
          const ctx = canvas.getContext('2d');
          const img = ctx.createImageData(width, height);
          for(let i = 0; i < width * height; i++) {
            img.data[i * 4 + 0] = bgra[8 + i * 4 + 2];
            img.data[i * 4 + 1] = bgra[8 + i * 4 + 1];
            img.data[i * 4 + 2] = bgra[8 + i * 4 + 0];
            img.data[i * 4 + 3] = bgra[8 + i * 4 + 3];
          }
          ctx.putImageData(img, 0, 0);
        }
      }

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
          this.drawerVisible = false;
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
          this.moveDone = pos[4] > 0;
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
        if(this.intervalValue.CENTER) {
          this.centerMark = this.intervalValue.CENTER === 'on';
        }
        if(this.intervalValue.FLIP) {
          this.videoFlip = this.intervalValue.FLIP !== 'normal';
        }
      }, 1000);
      this.StillImageInterval();
      this.CheckHomeKit();
      window.addEventListener('resize', this.ResizeEvent.bind(this));
    },
    methods: {
      ResizeEvent() {
        const svg = document.querySelector('.image-svg');
        this.$set(this.motionArea, 'scaleX', ((svg?.clientWidth ?? 99) - 10) / 99);
        this.$set(this.motionArea, 'scaleY', ((svg?.clientHeight ?? 99) - 10) / 99);
        if(svg) {
          const rect = svg.getBoundingClientRect();
          this.motionArea.svgX = rect.left;
          this.motionArea.svgY = rect.top;
          this.$set(this.motionArea, 'svgX', rect.left);
          this.$set(this.motionArea, 'svgY', rect.top);
          this.$set(this.motionArea, 'valid', this.motionArea.valid | 2);
        }
      },
      MouseDown(modeX, modeY) {
        this.$set(this.motionArea, 'modeX', modeX);
        this.$set(this.motionArea, 'modeY', modeY);
      },
      MouseLeave() {
        this.$set(this.motionArea, 'modeX', 0);
        this.$set(this.motionArea, 'modeY', 0);
      },
      MouseMove(ev) {
        if(!this.motionArea.modeX && !this.motionArea.modeY) return;
        if(!this.motionArea.scaleX || !this.motionArea.scaleY) return;
        const offsetX = ev.pageX - this.motionArea.svgX - 5;
        const offsetY = ev.pageY - this.motionArea.svgY - 5;
        if(this.motionArea.modeX === 1) {
          let sx = offsetX / this.motionArea.scaleX;
          if(sx < 0) sx = 0;
          if(sx > 98) sx = 98;
          this.$set(this.motionArea, 'sx', sx);
        }
        if(this.motionArea.modeY === 1) {
          let sy = offsetY / this.motionArea.scaleY;
          if(sy < 0) sy = 0;
          if(sy > 98) sy = 98;
          this.$set(this.motionArea, 'sy', sy);
        }
        if(this.motionArea.modeX === 2) {
          let dx = offsetX / this.motionArea.scaleX;
          if(dx < 1) dx = 1;
          if(dx > 99) dx = 99;
          this.$set(this.motionArea, 'dx', dx);
        }
        if(this.motionArea.modeY === 2) {
          let dy = offsetY / this.motionArea.scaleY;
          if(dy < 1) dy = 1;
          if(dy > 99) dy = 99;
          this.$set(this.motionArea, 'dy', dy);
        }
        this.MotionArea();
      },
      RTMPRestart() {
        this.rtspRestart = true;
        this.Submit();
      },
      CenterMark() {
        const mode = this.centerMark ? 'off' : 'on';
        this.Exec(`center ${mode}`, 'socket');
      },
      VideoFlip() {
        const mode = this.videoFlip ? 'normal' : 'flip_mirror';
        this.Exec(`flip ${mode}`);
      },
      async GetCameraProperty() {
        const property = ((await this.Exec('property', 'socket')).data ?? '').split(/[\n\x00]/);
        if(!property.length) return;
        this.property = property.reduce((d, s) => {
          if(s.length && (s !== 'ok')) d[s.replace(/ *=.*$/, '')] = s.replace(/^.*= */, '');
          return d;
        }, {});
        if(this.property.motionArea.length) {
          const s = this.property.motionArea.split(/[ \t]/);
          if(s.length === 5) {
            this.$set(this.property, 'motionArea', s[0]);
            this.$set(this.motionArea, 'sx', parseInt(s[1]));
            this.$set(this.motionArea, 'sy', parseInt(s[2]));
            this.$set(this.motionArea, 'dx', parseInt(s[1]) + parseInt(s[3]));
            this.$set(this.motionArea, 'dy', parseInt(s[2]) + parseInt(s[4]));
            this.$set(this.motionArea, 'valid', this.motionArea.valid | 1);
          }
        }
        this.property.valid = true;
        // eslint-disable-next-line no-console
        console.log('cameraProperty', this.property);
        this.ResizeEvent();
      },
      async CameraSet(item) {
        if(!this.property.valid) return;
        await this.Exec(`property ${item} ${this.property[item]}`, 'socket');
      },
      async MotionArea(val) {
        if(!this.property.valid) return;
        if(val != null) this.property.motionArea = val;
        if(this.motionTimeoutID) clearTimeout(this.motionTimeoutID);
        this.motionTimeoutID = setTimeout(async () => {
          this.motionTimeoutID = null;
          await this.Exec(`property motionArea ${this.property.motionArea} ${this.motionArea.sx} ${this.motionArea.sy} ${this.motionArea.dx - this.motionArea.sx} ${this.motionArea.dy - this.motionArea.sy}`, 'socket');
        }, 1000);
      },
      async ISPSet(item) {
        if(this.ispSettingsTimeoutID) clearTimeout(this.ispSettingsTimeoutID);
        this.ispSettingsTimeoutID = setTimeout(async () => {
          if(['aeitmin', 'aeitmax', 'expmode', 'expline'].indexOf(item) >= 0) {
            await this.Exec(`video expr ${this.ISPSettings.expmode} ${this.ISPSettings.expline} ${this.ISPSettings.aeitmin} ${this.ISPSettings.aeitmax}`, 'socket');
          } else {
            await this.Exec(`video ${item} ${this.ISPSettings[item]}`, 'socket');
          }
        }, 300);
        if(this.ispSettingsFileTimeoutID) clearTimeout(this.ispSettingsFileTimeoutID);
        this.ispSettingsFileTimeoutID = setTimeout(async () => {
          this.ispSettingsFileTimeoutID = null;
          await axios.post('./cgi-bin/video_isp.cgi', this.ISPSettings).catch(err => {
            // eslint-disable-next-line no-console
            console.log('axios.post ./cgi-bin/video_isp.cgi', err);
          });
        }, 1500);
      },
      async CheckHomeKit() {
        if((this.oldConfig.HOMEKIT_ENABLE !== 'on') || (this.config.HOMEKIT_ENABLE !== 'on')) return;

        const localhost = window.location.origin;
        const pairingInfo = (await axios.get(`${localhost}:1984/api/homekit/pairing`).catch(err => {
          // eslint-disable-next-line no-console
          console.log(`${localhost}:1984/api/homekit/pairing: ${err.message}`);
          return null;
        }))?.data;
        if((this.homeKitSetupURI !== pairingInfo?.video0?.SetupURI) ||
           (this.homeKitSetupCode !== pairingInfo?.video0?.Pin) ||
           (this.homeKitPairing !== pairingInfo?.video0?.Status)) {
          // eslint-disable-next-line no-console
          console.log('pairingInfo : ', pairingInfo);
        }
        if(pairingInfo?.video0) {
          this.homeKitPairing = pairingInfo?.video0?.Status ?? '';
          if((pairingInfo?.video0?.SetupURI ?? '').indexOf('X-HM://') === 0) {
            if(this.homeKitSetupURI === '') this.KickHomeKit();
            this.homeKitSetupURI = pairingInfo?.video0?.SetupURI;
            this.homeKitSetupCode = pairingInfo?.video0?.Pin;
          }
        }
        if(this.homeKitPairing === '' || this.homeKitSetupURI === '') {
          setTimeout(this.CheckHomeKit, 1000);
        } else {
          setTimeout(this.CheckHomeKit, 5000);
        }
      },
      async UnpairHomeKit() {
        const localhost = window.location.origin;
        await axios.delete(`${localhost}:1984/api/homekit/pairing?stream=video0`).catch(err => {
          // eslint-disable-next-line no-console
          console.log(`delete ${localhost}:1984/api/homekit/pairing?stream=video0`, err);
          return '';
        });
        this.homeKitPairing = '';
        this.homeKitSetupURI = '';
        this.KickHomeKit();
        this.CheckHomeKit();
      },
      async KickHomeKit() {
        if((this.oldConfig.HOMEKIT_ENABLE !== 'on') || (this.config.HOMEKIT_ENABLE !== 'on')) return;
        const localhost = window.location.origin;
        await axios.get(`${localhost}:1984/api/homekit`).catch(err => {
          // eslint-disable-next-line no-console
          console.log(`${localhost}:1984/api/homekit`, err);
          return '';
        });
      },
      async GetLatestVer() {
        const status = (await axios.get('./cgi-bin/cmd.cgi?name=latest-ver').catch(err => {
          // eslint-disable-next-line no-console
          console.log('axios.get ./cgi-bin/cmd.cgi', err);
          return { data: '' };
        })).data.split('\n').reduce((s, d) => {
          s[d.replace(/=.*$/, '').trim()] = d.replace(/^.*=/, '').trim();
          return s;
        }, {});
        this.latestVer = status.LATESTVER;
      },
      HandleTabsClick(tab) {
        this.selectedTabIndex = parseInt(tab.index);
        if(this.selectedTab === 'CameraSettings') this.GetCameraProperty();
        if(this.selectedTab === 'maintenance') this.GetLatestVer();
      },
      async Move() {
        if(!this.posValid || !this.moveDone) return;
        await this.Exec(`move ${this.pan} ${this.tilt} 5 3`, 'socket');
        this.StillImageInterval();
        if(this.moveTimeout) clearTimeout(this.moveTimeout);
        this.moveTimeout = setTimeout(() => {
          this.moveTimeout = null;
          this.Exec('posrec');
        }, 3000);
      },
      NightVision(mode) {
        if(this.distributor !== 'ATOM') {
          this.property.nightVision = mode;
          this.CameraSet('nightVision');
        } else {
          this.Exec(`night ${mode}`, 'socket');
        }
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
          startTime: '00:00',
          endTime: '23:59',
          dayOfWeekSelect: [0, 1, 2, 3, 4, 5, 6],
        });
      },
      DeleteSchedule(schedule, i, confKey) {
        this[schedule].splice(i, 1);
        if(!this[schedule].length) this.$set(this.config, confKey, 'off');
      },
      AddTimelapseSchedule() {
        this.timelapseSchedule.push({
          dayOfWeekSelect: [0, 1, 2, 3, 4, 5, 6],
          startTime: '04:00',
          interval: 60,
          count: 960,
        });
      },
      DeleteTimelapseSchedule(i) {
        if(!this.timelapseSchedule.length) this.$set(this.config, 'timelapse', 'off');
        this.timelapseSchedule.splice(i, 1);
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
        this.drawerComment = 'rebooting';
        this.progress = 0;
        this.drawerVisible = true;
        this.rebootStart = new Date();
        this.rebootStart.setSeconds(this.rebootStart.getSeconds() + 30);
        this.Exec('reboot');
      },
      async DoErase() {
        this.drawerComment = 'erasing';
        this.progress = 0;
        this.drawerVisible = true;
        await this.Exec('sderase');
        this.drawerVisible = false;
      },
      async DoUpdate() {
        await this.Submit();
        this.drawerComment = 'downloading';
        this.progress = 0;
        this.drawerVisible = true;
        await this.Exec('update');
        const updateIntervalID = setInterval(async () => {
          this.progress = parseInt(((await this.Exec('update_status'))?.data ?? '').replace(/^.* ([+-]*\d+) .*\n*$/, '$1')) ?? -1;
          if(this.progress < 0) {
            clearInterval(updateIntervalID);
            this.drawerComment = 'downloadError';
            this.progress = 0;
            this.drawerClosable = true;
          }
          if(this.progress === 100) {
            clearInterval(updateIntervalID);
            this.drawerComment = 'rebooting';
            this.progress = 0;
            this.rebootStart = new Date();
            this.rebootStart.setSeconds(this.rebootStart.getSeconds() + 30);
          }
        }, 1000);
      },
      UploadPNG(ev) {
        this.isDrag = false;
        const file = ev?.dataTransfer?.files?.[0];
        const reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onloadend = async () => {
          if(file.name.slice(-4) !== '.png') return;
          const img = new Image();
          img.src = reader.result;
          await img.decode();
          const width = img.naturalWidth;
          const height = img.naturalHeight;
          if((width > 500) || (height > 100)) return;
          const canvas = document.getElementById("watermark");
          canvas.width = width;
          canvas.height = height;
          canvas.style.width = `${width}px`;
          canvas.style.height = `${height}px`;
          const ctx = canvas.getContext('2d');
          ctx.drawImage(img, 0, 0, width, height);
          this.watermarkUploaded = true;
        };
      },
      async Submit() {
        if((this.loginAuth === 'on') && this.account.length) {
          if(this.password.length) {
            this.config.DIGEST = `${this.account}:${this.relm}:` + md5(`${this.account}:${this.relm}:${this.password}`);
          }
        } else {
          this.config.DIGEST='';
        }

        for(let schedule of ['periodicRec', 'alarmRec']) {
          const confKey = schedule.toUpperCase() + '_SCHEDULE_LIST';
          const innerKey = schedule + 'Schedule';
          let str = '';
          for(const i in this[innerKey]) {
            const timeTable = this[innerKey][i];
            str += `[index_${(i - 0 + 1).toString().padStart(2, '0')}];`;
            const val = timeTable.dayOfWeekSelect.reduce((v, d) => v | (2 << d), 0);
            str += `Rule=${val};`;
            const stime = parseInt((timeTable.startTime ?? '0').slice(0, 2)) * 60 + parseInt((timeTable.startTime ?? '0').slice(-2));
            const etime = parseInt((timeTable.endTime ?? '0').slice(0, 2)) * 60 + parseInt((timeTable.endTime ?? '0').slice(-2)) + 1;
            str += `ContinueTime=${etime - stime};`;
            str += `StartTime=${stime};`;
            str += `Status=1;`;
            str += `DelFlags=1;`;
          }
          this.$set(this.config, confKey, str);
        }

        if(this.config.PERIODICREC_SDCARD !== 'on' && this.config.ALARMREC_SDCARD !== 'on' && this.config.TIMELAPSE_SDCARD !== 'on') this.config.STORAGE_SDCARD_PUBLISH = 'off';

        this.config.LOCALE = this.$i18n.locale;
        this.config.TIMELAPSE_SCHEDULE = this.timelapseSchedule.reduce((str, schedule) => {
          str += parseInt(schedule.startTime.slice(-2)) + ' ' +
          parseInt(schedule.startTime.slice(0, 2)) + ' * * ' +
          schedule.dayOfWeekSelect.sort((a, b) => a - b).reduce((v, d) => v + (v.length ? ':' : '') + ((d + 1) % 7).toString(), '') +
          ' /scripts/timelapse.sh start ' + schedule.interval + ' ' + schedule.count + ';';
          return str;
        }, '');

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

        if(this.config.RTSP_VIDEO0 === 'off') {
          this.config.HOMEKIT_ENABLE = 'off';
          this.config.RTMP_ENABLE = 'off';
          this.config.WEBRTC_ENABLE = 'off';
        }
        if(this.distributor !== 'ATOM') {
          this.config.RTSP_VIDEO2 = 'off';
          this.config.RTSP_AUDIO2 = 'off';
        }
        this.config.HOMEKIT_SOURCE = this.RtspUrl0.replace(/^rtsp:\/\/.*:/, 'rtsp://localhost:');

        await axios.post('./cgi-bin/hack_ini.cgi', this.config).catch(err => {
          // eslint-disable-next-line no-console
          console.log('axios.post ./cgi-bin/hack_ini.cgi', err);
        });
        // eslint-disable-next-line no-console
        console.log('config', this.config);

        if(this.watermarkUploaded) {
          const canvas = document.getElementById("watermark");
          const width = canvas.width;
          const height = canvas.height;
          const ctx = canvas.getContext('2d');
          const imageData = ctx.getImageData(0, 0, width, height).data;
          const bgra = new Uint8Array(8 + width * height * 4);
          bgra[0] = height & 0xff;
          bgra[1] = (height >> 8) & 0xff;
          bgra[2] = 0;
          bgra[3] = 0;
          bgra[4] = width & 0xff;
          bgra[5] = (width >> 8) & 0xff;
          bgra[6] = 0;
          bgra[7] = 0;
          for(let i = 0; i < width * height; i++) {
            bgra[8 + i * 4 + 0] = imageData[i * 4 + 2];
            bgra[8 + i * 4 + 1] = imageData[i * 4 + 1];
            bgra[8 + i * 4 + 2] = imageData[i * 4 + 0];
            bgra[8 + i * 4 + 3] = imageData[i * 4 + 3];
          }
          await axios.post('./cgi-bin/watermark.cgi', bgra).catch(err => {
            // eslint-disable-next-line no-console
            console.log('axios.post ./cgi-bin/watermark.cgi', err);
          });
          this.watermarkUploaded = false;
        }

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
        if(parseInt(this.config.PERIODICREC_SKIP_JPEG) !== parseInt(this.oldConfig.PERIODICREC_SKIP_JPEG)) {
          execCmds.push(`skipRecJpeg ${this.config.PERIODICREC_SKIP_JPEG}`);
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
            (this.config.RTSP_VIDEO1 !== this.oldConfig.RTSP_VIDEO1) ||
            (this.config.RTSP_VIDEO2 !== this.oldConfig.RTSP_VIDEO2)) &&
           (this.config.RTSP_VIDEO0 === 'off') && (this.config.RTSP_VIDEO1 === 'off') && (this.config.RTSP_VIDEO2 === 'off')) {
          execCmds.push('rtspserver off');
        }
        if(this.config.STORAGE_SDCARD_PUBLISH !== this.oldConfig.STORAGE_SDCARD_PUBLISH) {
          execCmds.push(`samba ${this.config.STORAGE_SDCARD_PUBLISH}`);
        }
        if((this.config.RTSP_VIDEO0 === 'on') || (this.config.RTSP_VIDEO1 === 'on') || (this.config.RTSP_VIDEO2 === 'on')) {
          if((this.config.RTSP_OVER_HTTP !== this.oldConfig.RTSP_OVER_HTTP) ||
             (this.config.RTSP_AUTH !== this.oldConfig.RTSP_AUTH) ||
             (this.config.RTSP_USER !== this.oldConfig.RTSP_USER) ||
             (this.config.RTSP_PASSWD !== this.oldConfig.RTSP_PASSWD) ||
             (this.config.HOMEKIT_ENABLE !== this.oldConfig.HOMEKIT_ENABLE) ||
             (this.config.RTMP_ENABLE !== this.oldConfig.RTMP_ENABLE) ||
             (this.config.RTMP_URL !== this.oldConfig.RTMP_URL) ||
             (this.config.WEBRTC_ENABLE !== this.oldConfig.WEBRTC_ENABLE) ||
             (this.config.RTSP_VIDEO0 !== this.oldConfig.RTSP_VIDEO0) ||
             (this.config.RTSP_VIDEO1 !== this.oldConfig.RTSP_VIDEO1) ||
             (this.config.RTSP_VIDEO2 !== this.oldConfig.RTSP_VIDEO2) ||
             (this.config.RTSP_AUDIO0 !== this.oldConfig.RTSP_AUDIO0) ||
             (this.config.RTSP_AUDIO1 !== this.oldConfig.RTSP_AUDIO1) ||
             (this.config.RTSP_AUDIO2 !== this.oldConfig.RTSP_AUDIO2) ||
             this.rtspRestart) {
            execCmds.push('rtspserver restart');
          }
        }
        this.RTSPRestart = false;
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
          this.drawerComment = 'executing';
          this.progress = 0;
          this.drawerVisible = true;
          this.$nextTick(async () => {
            for(const cmd of execCmds) {
              await this.Exec(cmd);
            }
            if(execCmds.indexOf('lighttpd') >= 0) {
              setTimeout(() => this.drawerVisible = false, 3000);
            } else {
              this.drawerVisible = false;
            }
            if(href) window.location.href = href;
          });
        }
        this.CheckHomeKit();
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
    flex-basis: 20rem;
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
    height: calc(100vh - 150px);
    height: calc(100dvh - 150px);
    margin: 10px 20px 5px 20px;
    overflow-x: hidden;
    overflow-y: scroll;
  }

  .container-flex-no-submit {
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

  .image-overlay {
    z-index: 101;
    display: flex;
    flex-direction: column;
    width: 100%;
    height: calc(((100dvw - 400px)* 0.55 - 38px)* 1080 / 1920);
  }

  .image-svg {
    width: calc(100% - 38px);
    height: calc(100% + 10px);
  }

  .motionAreaRect {
    fill: #0000;
    stroke: orange;
    stroke-width: 0.3vw;
  }

  .motionAreaHandle {
    opacity: 0;
    stroke-width: 2vw;
    stroke: white;
  }

  .image-frame-camera-settings {
    width: calc((100vw - 400px) * 0.55 );
    width: calc((100dvw - 400px) * 0.55 );
    position:fixed;
    right: 30px;
    top: 100px;
    padding: 0;
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

  .image-frame-inner4 {
    justify-content: flex-end;
    display: flex;
    height: 100%;
    margin: -5px;
  }

  .ir-led {
    font-size: 24px;
    color: gray;
  }

  .center-mark {
    margin-left: 10px;
    padding: 1px 10px;
    font-size: 20px;
  }

  .video-flip {
    margin-left: 10px;
    padding: 1px 10px;
    font-size: 20px;
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

  .homekit {
    display: inline-block;
    padding: 10px 20px;
    margin: 20px;
    border: solid 4px;
    border-radius: 15px;
  }

  .homekit-qrcode {
    vertical-align: middle;
    padding: 5px;
  }

  .homekit-setupcode {
    font-weight: 600;
    display:inline-block;
    vertical-align: middle;
    font-size: 2em;
  }

  .homekit-deviceid {
    font-weight: 400;
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

  .watermark-drop-area {
    background-color: #ffffff;
    padding: 5px;
    margin: 10px 0px;
    border: 1px solid #e3e3e3;
    border-radius: 5px;
    box-shadow: inset 0 1px 1px rgba(0,0,0,.05);
    width: 500px;
    height: 100px;
  }

  #watermark {
    width: 500px;
    height: 100px;
    border: solid 1px #999;
     background-image: linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%),
        linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%);
    background-position: 0 0, 3px 3px;
    background-size: 6px 6px;
    background-color: #999;
 }

  .is-drag {
    background-color: #f0f0f0;
  }

  .progress {
    padding: 0px 10vw;
  }
</style>
