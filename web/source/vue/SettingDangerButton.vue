<template>
  <ElTooltip :tabindex="-1" placement="top" :disabled="$te(i18n + '.tooltip') ? false : true" :content="($te(i18n + '.tooltip') ? $t(i18n + '.tooltip') : '') + tooltip" effect="light" :open-delay="500">
    <ElRow>
      <ElCol :offset="titleOffset" :span="9 - titleOffset">
        <h4 v-if="$te(i18n + '.title')" v-t="i18n+'.title'" />
        <h4 v-else>
          {{ title }}
        </h4>
      </ElCol>
      <ElCol :span="4">
        <ElSwitch v-model="enable" inactive-text="Lock" :disabled="disabled" />
      </ElCol>
      <ElCol :span="4">
        <ElButton @click="$emit('click', $event); enable=false;" type="danger" :disabled="!enable" :icon="icon">
          {{ buttonLabel }}
        </ElButton>
      </ElCol>
      <ElCol :span="7">
        <slot />
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
      icon: {
        type: String,
        default: null,
      },
      button: {
        type: String,
        default: null,
      },
      disabled: {
        type: Boolean,
        default: false,
      },
    },
    data() {
      return {
        enable: false,
      };
    },
    computed: {
      buttonLabel() {
        let label = this.button;
        if(this.$te(this.i18n + '.button')) label = this.$t(this.i18n + '.button');
        return label;
      },
    },
  };
</script>

<style scoped>
