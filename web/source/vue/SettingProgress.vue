<template>
  <ElTooltip :tabindex="-1" placement="top" :disabled="$te(i18n + '.tooltip') ? false : true" :content="($te(i18n + '.tooltip') ? $t(i18n + '.tooltip') : '') + tooltip" effect="light" :open-delay="500">
    <ElRow>
      <ElCol :offset="titleOffset" :span="9 - titleOffset">
        <h4 v-if="$te(i18n + '.title')" v-t="i18n+'.title'" />
        <h4 v-else>
          {{ title }}
        </h4>
      </ElCol>
      <ElCol :span="span - 2">
        <ElProgress class="progress-bar" :percentage="percentage" :show-text="false" />
      </ElCol>
      <ElCol :span="2">
        <span>{{ label }}</span>
      </ElCol>
    </ElRow>
  </ElTooltip>
</template>

<script>
  import { Tooltip, Progress } from 'element-ui';
  import 'element-ui/lib/theme-chalk/tooltip.css';
  import 'element-ui/lib/theme-chalk/progress.css';

  export default {
    components: {
      ElTooltip: Tooltip,
      ElProgress: Progress,
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
      percentage: {
        type: Number,
        required: true,
      },
      label: {
        type: String,
        default: '',
      },
      span: {
        type: Number,
        default: 15,
      },
    },
  };
</script>

<style scoped>
  .progress-bar {
    margin-top: 5px;
  }
</style>
