<template>
  <ElRow>
    <ElCol :offset="titleOffset" :span="9 - titleOffset">
      <h4 v-if="$te(i18n + '.title')" v-t="i18n+'.title'" />
      <h4 v-else>
        {{ title }}
      </h4>
    </ElCol>
    <ElCol :span="12">
      <div class="well schedule">
        <div class="schedule-week">
          <ElCheckboxGroup v-model="innerValue.dayOfWeekSelect" size="small" :min="1" @input="TimeSet">
            <ElCheckboxButton v-for="(day, i) of $t('schedule.weekDays')" :label="i" :key="i">
              {{ day }}
            </ElCheckboxButton>
          </ElCheckboxGroup>
          <ElButton v-if="timeRange" class="schedule-button" type="text" size="small" circle icon="el-icon-minus" @click="$emit('remove', $event)" />
        </div>
        <div v-if="timeRange" class="schedule-week">
          <div class="schedule-time">
            <ElSwitch v-model="allDay" :active-text="$t('schedule.allDay')" @input="TimeSet" />
            <div v-if="!allDay" class="schedule-timerange">
              <ElTimePicker class="time-picker" v-model="innerValue.startTime" :placeholder="$t('schedule.startTime')" value-format="HH:mm" format="HH:mm" @change="TimeSet" />
              -
              <ElTimePicker class="time-picker" v-model="innerValue.endTime" :placeholder="$t('schedule.endTime')" value-format="HH:mm" format="HH:mm" @change="TimeSet" />
            </div>
          </div>
          <ElButton v-if="timeRange" class="schedule-button" type="text" size="small" circle icon="el-icon-plus" @click="$emit('add', $event)" />
        </div>
        <div v-else-if="timelapse">
          <div class="schedule-time">
            <ElTimePicker class="time-picker" v-model="innerValue.startTime" :placeholder="$t('schedule.timelapse.startTime')" value-format="HH:mm" format="HH:mm" @change="TimeSet" />
            <span class="strings" v-t="{ path: 'schedule.timelapse.endTime', args: { endTime: timelapseEndTime }}" />
          </div>
          <div class="schedule-time">
            <span class="strings" v-t="'schedule.timelapse.interval.title'" />
            <ElInputNumber class="timelapse-number" v-model="innerValue.interval" @change="TimeSet" :min="1" :controls="false" :step-strictly="true" size="mini" />
            <span class="strings" v-t="'schedule.timelapse.interval.unit'" />
            <ElInputNumber class="timelapse-number" v-model="innerValue.count" @change="TimeSet" :min="1" :controls="false" :step-strictly="true" size="mini" />
            <span class="strings" v-t="'schedule.timelapse.interval.count'" />
          </div>
        </div>
        <div v-else class="schedule-week schedule-time">
          <ElTimePicker class="time-picker" v-model="innerValue.startTime" :placeholder="$t('schedule.time')" value-format="HH:mm" format="HH:mm" @change="TimeSet" />
        </div>
      </div>
    </ElCol>
  </ElRow>
</template>

<script>
  import { Switch, CheckboxGroup, CheckboxButton, TimePicker, InputNumber } from 'element-ui';
  import 'element-ui/lib/theme-chalk/switch.css';
  import 'element-ui/lib/theme-chalk/checkbox.css';
  import 'element-ui/lib/theme-chalk/time-picker.css';
  import 'element-ui/lib/theme-chalk/input-number.css';

  export default {
    components: {
      ElSwitch: Switch,
      ElCheckboxGroup: CheckboxGroup,
      ElCheckboxButton: CheckboxButton,
      ElTimePicker: TimePicker,
      ElInputNumber: InputNumber,
    },
    props: {
      titleOffset: {
        type: Number,
        default: 1,
      },
      title: {
        type: String,
        default: '',
      },
      i18n: {
        type: String,
        default: '',
      },
      timeRange: {
        type: Boolean,
        default: false,
      },
      timelapse: {
        type: Boolean,
        default: false,
      },
      value: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        innerValue: { ...this.value },
        allDay: (this.value.startTime === '00:00') && (this.value.endTime === '23:59'),
      };
    },
    computed: {
      timelapseEndTime() {
        const startTime = (this.innerValue.startTime || '').split(':');
        let minutes = ((startTime.length === 2) ? parseInt(startTime[0]) * 60 + parseInt(startTime[1]) : 0) + (this.value.count * this.value.interval) / 60;
        let str = '';
        if(minutes >= 48 * 60) {
          str += this.$t('schedule.timelapse.daysLater', { days: Math.floor(minutes / 24 / 60).toString() });
        } else if(minutes >= 24 * 60) {
          str += this.$t('schedule.timelapse.tommorow');
        }
        str += Math.floor((minutes % 1440) / 60).toString().padStart(2, '0') + ':';
        str += Math.floor(minutes % 60).toString().padStart(2, '0');
        return str;
      },
    },
    watch: {
      value(v) {
        this.innerValue = { ...v };
      },
    },
    methods: {
      TimeSet() {
        if(this.timeRange && this.allDay) {
          this.innerValue.startTime = '00:00';
          this.innerValue.endTime = '23:59';
        }
        this.$emit('input', this.innerValue);
      },
    },
  };
</script>

<style scoped>
  .schedule {
    display: inline-flex;
    flex-direction: column;
    width: 95%;
  }
  .schedule-week {
    display: inline-flex;
    justify-content: space-between;
  }
  .schedule-time {
    display: inline-flex;
    margin:10px 5px 5px 5px;
  }
  .schedule-timerange {
    margin:0px 0px 0px 10px;
  }
  .schedule-button {
    padding: 0;
    text-alin:right;
    float:right;
  }
  .time-picker {
    width: 110px;
  }
  .timelapse-number {
    margin:0px 0px 0px 10px;
  }
  .strings {
    margin:0px 5px 0px 5px;
    font-size: 1.1em;
  }
</style>
<style>
  .el-checkbox-button.is-disabled.is-checked .el-checkbox-button__inner {
    color: #C0C4CC;
    cursor: not-allowed;
    background-image: none;
    background-color: #409EFF;
    border-color: #409EFF;
    -webkit-box-shadow: none;
    box-shadow: none;
  }
</style>
