<template>
  <ElRow>
    <ElCol :offset="titleOffset" :span="9 - titleOffset">
      <h4 v-if="$te(i18n + '.title')" v-t="i18n+'.title'" />
      <h4 v-else>
        {{ title }}
      </h4>
    </ElCol>
    <ElCol :span="span">
      <span class="comment" v-t="i18n + '.comment'" :style="{ color: color, 'font-weight': weight }" />
      <span class="comment" :style="{ color: color, 'font-weight': weight }">
        <slot />
      </span>
    </ElCol>
  </ElRow>
</template>

<script>
  export default {
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
      span: {
        type: Number,
        default: 15,
      },
      color: {
        type: String,
        default: 'black',
      },
      weight: {
        type: String,
        default: 'normal',
      },
    },
  };
</script>

<style scoped>
.comment {
  font-size: 1em;
  white-space: pre-line;
}
</style>
