<template>
  <ElTooltip :tabindex="-1" placement="top" :disabled="$te(i18n + '.tooltip') ? false : true" :content="($te(i18n + '.tooltip') ? $t(i18n + '.tooltip') : '') + tooltip" effect="light" :open-delay="500">
    <ElRow>
      <ElCol :offset="titleOffset" :span="9 - titleOffset">
        <h4 v-if="$te(i18n + '.title')" v-t="i18n+'.title'" />
        <h4 v-else>
          {{ title }}
        </h4>
      </ElCol>
      <ElCol :span="span">
        <ElSlider v-model="innerValue" @input="Input" @change="Change" :marks="marks" :min="min" :max="max" :step="step" />
      </ElCol>
      <ElCol :offset="2" :span="2">
        <ElButton class="refresh" size="mini" type="primary" icon="el-icon-refresh-left" @click="ResetValue" />
      </ElCol>
    </ElRow>
  </ElTooltip>
</template>

<script>
  import { Tooltip, Slider } from 'element-ui';
  import 'element-ui/lib/theme-chalk/tooltip.css';
  import 'element-ui/lib/theme-chalk/slider.css';

  export default {
    components: {
      ElTooltip: Tooltip,
      ElSlider: Slider,
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
      value: {
        type: Number,
        required: true,
      },
      span: {
        type: Number,
        default: 6,
      },
      min: {
        type: Number,
        default: -Infinity,
      },
      max: {
        type: Number,
        default: Infinity,
      },
      defaultValue: {
        type: Number,
        default: 0,
      },
      step: {
        type: Number,
        default: 1,
      },
    },
    data() {
      return {
        innerValue: Math.abs(this.value),
      };
    },
    computed: {
      marks() {
        const marks = {};
        marks[this.min] = this.min.toString();
        marks[this.max] = this.max.toString();
        marks[this.defaultValue] = this.defaultValue.toString();
        return marks;
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
        this.$emit('input', this.innerValue);
      },
      Change() {
        this.$emit('change', this.innerValue);
      },
      ResetValue() {
        this.innerValue = this.defaultValue;
        this.$emit('input', this.innerValue);
      },
    },
  };
</script>

<style scoped>
.refresh {
  font-size: 20px;
  padding: 2px 14px;
}
</style>
