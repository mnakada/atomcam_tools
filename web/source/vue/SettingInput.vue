<template>
  <ElTooltip :tabindex="-1" placement="top" :content="($te(i18n + '.tooltip') ? $t(i18n + '.tooltip') : '') + tooltip" effect="light" :open-delay="500">
    <ElRow>
      <ElCol :offset="titleOffset" :span="9 - titleOffset">
        <h4 v-if="$te(i18n + '.title')" v-t="i18n+'.title'" />
        <h4 v-else>
          {{ title }}
        </h4>
      </ElCol>
      <ElCol :span="span">
        <ElInput :value="value" :type="(type==='readonly')?'text':type" :readonly="type==='readonly'" @input="$emit('input', $event)" @change="$emit('change', $event)" :clearable="clearable" :placeholder="($te(i18n + '.placeholder') ? $t(i18n + '.placeholder') : '') + placeholder" :show-password="showPassword" />
      </ElCol>
      <ElCol :offset="1" :span="14 - span">
        <slot />
      </ElCol>
    </ElRow>
  </ElTooltip>
</template>

<script>
  import { Tooltip, Input } from 'element-ui';
  import 'element-ui/lib/theme-chalk/tooltip.css';
  import 'element-ui/lib/theme-chalk/input.css';

  export default {
    components: {
      ElTooltip: Tooltip,
      ElInput: Input,
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
        type: String,
        required: true,
      },
      type: {
        type: String,
        default: 'text',
        validator(value) {
          return ['text', 'password', 'readonly'].indexOf(value) !== -1;
        },
      },
      span: {
        type: Number,
        default: 6,
      },
      placeholder: {
        type: String,
        default: '',
      },
      clearable: {
        type: Boolean,
        default: false,
      },
      showPassword: {
        type: Boolean,
        default: false,
      },
    },
  };
</script>
