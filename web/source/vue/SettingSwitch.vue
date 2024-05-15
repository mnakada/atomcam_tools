<template>
  <ElTooltip :tabindex="-1" placement="top" :content="($te(i18n + '.tooltip') ? $t(i18n + '.tooltip') : '') + tooltip" effect="light" :open-delay="500">
    <ElRow>
      <ElCol :offset="titleOffset" :span="9 - titleOffset">
        <h4 v-if="$te(i18n + '.title')" v-t="i18n+'.title'" />
        <h4 v-else>
          {{ title }}
        </h4>
      </ElCol>
      <ElCol :span="textLabel?8:4">
        <ElSwitch :value="value" @input="$emit('input', $event)" @change="$emit('change', $event)" :active-value="onOff ? 'on' : true" :inactive-value="onOff ? 'off' : false" :active-color="textLabel?'#13ce66':'#409eff'" :active-text="textLabel && textLabel[0]" :inactive-color="textLabel?'#409eff':'#c0ccda'" :inactive-text="textLabel && textLabel[1]" :disabled="disabled" :key="i18n + title" />
      </ElCol>
      <ElCol v-if="commentValid" :span="textLabel?7:11">
        <span v-t="i18n + '.comment'">
          {{ comment }}
        </span>
      </ElCol>
    </ElRow>
  </ElTooltip>
</template>

<script>
  import { Tooltip, Switch } from 'element-ui';
  import 'element-ui/lib/theme-chalk/tooltip.css';
  import 'element-ui/lib/theme-chalk/switch.css';

  export default {
    components: {
      ElTooltip: Tooltip,
      ElSwitch: Switch,
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
        type: [ String, Boolean ],
        required: true,
      },
      onOff: {
        type: Boolean,
        default: true,
      },
      text: {
        type: Array,
        default: null,
      },
      comment: {
        type: String,
        default: '',
      },
      disabled: {
        type: Boolean,
        default: false,
      },
    },
    computed: {
      textLabel() {
        const textLabel = this.text || [];
        if(this.$te(this.i18n + '.text[0]')) textLabel.push(this.$t(this.i18n + '.text[0]'));
        if(this.$te(this.i18n + '.text[1]')) textLabel.push(this.$t(this.i18n + '.text[1]'));
        return textLabel.length ? textLabel : null;
      },
      commentValid() {
        if(this.comment.length) return true;
        return this.$te(this.i18n + '.comment');
      },
    },
  };
</script>
