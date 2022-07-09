/*

  frontend/js/AtomSetting.js

  Copyright (C) 2021 Mitsuru Nakada
  This software is released under the MIT License, see license file.

*/
'use strict';

import Vue from 'vue';
import { Row, Col, Button } from 'element-ui';
import lang from 'element-ui/lib/locale/lang/ja';
import locale from 'element-ui/lib/locale';

const i18n = {
  install: function(Vue) {
    Vue.defaultLocale = 'en';
    Vue.prototype.$t = function(obj) {
      return obj[navigator.language] ? obj[navigator.language] : obj[Vue.defaultLocale];
    };
  },
};

locale.use(lang);
Vue.use(i18n);
Vue.prototype.$ELEMENT = { size: 'mini' };
Vue.use(Row);
Vue.use(Col);
Vue.use(Button);

import Setting from '../vue/Setting.vue';

// css
import 'element-ui/lib/theme-chalk/base.css';
import 'element-ui/lib/theme-chalk/row.css';
import 'element-ui/lib/theme-chalk/col.css';
import 'element-ui/lib/theme-chalk/button.css';
import '../css/localStyle.css';

class AtomSetting {
  constructor() {
    new Vue({
      el: '#app',
      template: '<setting/>',
      components: { 'setting': Setting },
    });
  }
}
new AtomSetting();
