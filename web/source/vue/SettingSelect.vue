<template>
  <ElTooltip :tabindex="-1" placement="top" :content="($te(i18n + '.tooltip') ? $t(i18n + '.tooltip') : '') + tooltip" effect="light" :open-delay="500">
    <ElRow>
      <ElCol :offset="titleOffset" :span="9 - titleOffset">
        <h4 v-if="$te(i18n + '.title')" v-t="i18n+'.title'" />
        <h4 v-else>
          {{ title }}
        </h4>
      </ElCol>
      <ElCol :span="8">
        <ElRadioGroup :value="value" @input="$emit('input', $event)" @change="$emit('input', $event)" size="mini">
          <ElRadioButton v-for="(val, idx) of label" :key="'select'+idx" :label="label[idx]" :name="idx">
            {{ labelText[idx] }}
          </ElRadioButton>
        </ElRadioGroup>
      </ElCol>
    </ElRow>
  </ElTooltip>
</template>

<script>
  import { Tooltip, RadioGroup, RadioButton } from 'element-ui';
  import 'element-ui/lib/theme-chalk/radio-group.css';
  import 'element-ui/lib/theme-chalk/radio-button.css';

  export default {
    components: {
      ElTooltip: Tooltip,
      ElRadioGroup: RadioGroup,
      ElRadioButton: RadioButton,
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
      label: {
        type: Array,
        default: null,
      },
    },
    computed: {
      labelText() {
        return this.label.map((l, idx) => this.$te(this.i18n + `.label[${idx}]`) ? this.$t(this.i18n + `.label[${idx}]`) : l);
      },
    },
  };
</script>
