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
        <slot>
          <ElButton :type="type" size="mini" @click="$emit('click', $event)">
            {{ buttonLabel }}
          </ElButton>
        </slot>
      </ElCol>
    </ElRow>
  </ElTooltip>
</template>

<script>
  import { Tooltip } from 'element-ui';
  import 'element-ui/lib/theme-chalk/tooltip.css';

  export default {
    components: {
      ElTooltip: Tooltip,
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
      span: {
        type: Number,
        default: 6,
      },
      type: {
        type: String,
        default: 'primary',
      },
      button: {
        type: String,
        default: null,
      },
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
