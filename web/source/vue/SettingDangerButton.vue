<template>
  <ElTooltip :tabindex="-1" placement="top" :content="tooltip" effect="light" :open-delay="500">
    <ElRow>
      <ElCol :offset="titleOffset" :span="9 - titleOffset">
        <h4>{{ title }}</h4>
      </ElCol>
      <ElCol :span="4">
        <ElSwitch v-model="enable" inactive-text="Lock" :disabled="disabled" />
      </ElCol>
      <ElCol :span="4">
        <ElButton @click="$emit('click', $event)" type="danger" :disabled="!enable" :icon="icon">
          {{ label }}
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
        required: true,
      },
      icon: {
        type: String,
        default: null,
      },
      label: {
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
  };
</script>

<style scoped>
