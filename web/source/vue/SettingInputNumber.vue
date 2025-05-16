<template>
  <ElTooltip :tabindex="-1" placement="top" :disabled="$te(i18n + '.tooltip') ? false : true" :content="($te(i18n + '.tooltip') ? $t(i18n + '.tooltip') : '') + tooltip" effect="light" :open-delay="500">
    <ElRow>
      <ElCol :offset="titleOffset" :span="9 - titleOffset">
        <h4 v-if="$te(i18n + '.title')" v-t="i18n+'.title'" />
        <h4 v-else>
          {{ title }}
        </h4>
      </ElCol>
      <ElCol v-if="withSwitch" :span="4">
        <ElSwitch v-model="switchValue" @change="SwitchChange" />
      </ElCol>
      <ElCol v-if="inputEnabled" :span="span">
        <ElInputNumber v-model="innerValue" @input="Input" @change="Change" :min="min" :max="max" :step="step" :step-strictly="true" size="mini" />
        <span v-if="$te(i18n + '.unit')" v-t="i18n+'.unit'" />
        <span v-else>
          {{ unit }}
        </span>
      </ElCol>
    </ElRow>
  </ElTooltip>
</template>

<script>
  import { Tooltip, Switch, InputNumber } from 'element-ui';
  import 'element-ui/lib/theme-chalk/tooltip.css';
  import 'element-ui/lib/theme-chalk/switch.css';
  import 'element-ui/lib/theme-chalk/input-number.css';

  export default {
    components: {
      ElTooltip: Tooltip,
      ElSwitch: Switch,
      ElInputNumber: InputNumber,
    },
    props: {
      tooltip: {
        type: String,
        default: '',
      },
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
      withSwitch: {
        type: Boolean,
        default: false,
      },
      value: {
        type: Number,
        required: true,
      },
      span: {
        type: Number,
        default: 10,
      },
      min: {
        type: Number,
        default: -Infinity,
      },
      max: {
        type: Number,
        default: Infinity,
      },
      step: {
        type: Number,
        default: 1,
      },
      unit: {
        type: String,
        default: '',
      },
    },
    data() {
      return {
        innerValue: Math.abs(this.value),
        switchValue: this.value >= 0,
      };
    },
    computed: {
      inputEnabled() {
        return !this.withSwitch || this.switchValue;
      },
    },
    watch: {
      value(v) {
        this.innerValue = Math.abs(v);
        this.switchValue = v >= 0;
      },
    },
    methods: {
      Input() {
        this.$emit('input', this.innerValue * (this.inputEnabled ? 1 : -1));
      },
      Change() {
        this.$emit('change', this.innerValue * (this.inputEnabled ? 1 : -1));
      },
      SwitchChange() {
        this.$emit('input', this.innerValue * (this.inputEnabled ? 1 : -1));
      },
    },
  };
</script>
