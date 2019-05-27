<template>
  <nav
    class="navbar is-fixed-top is-dark"
    role="navigation"
    aria-label="main navigation"
  >
    <div class="container">
      <div class="navbar-brand">
        <router-link
          class="navbar-item"
          to="/"
          style="padding-top: 0; padding-bottom: 0;"
        >
          <span style="font-size: 2rem; font-family: BigJohnPROBold;"
            >VUnitCoSim</span
          >
        </router-link>

        <a
          role="button"
          class="navbar-burger burger"
          aria-label="menu"
          aria-expanded="false"
          data-target="navbarBasicExample"
        >
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
        </a>
      </div>

      <div id="navbarBasicExample" class="navbar-menu">
        <div class="navbar-start">
          <div class="navbar-item">
            {{name}}
          </div>
          <div class="navbar-item" v-if="loaded && !busy">
            clk: {{params[0]}}, {{params[1]}}
          </div>
          <div class="navbar-item" v-if="loaded && !busy">
            step: {{params[2]}}
          </div>
        </div>
        <div class="navbar-end">
          <div class="navbar-item" v-show="loaded && !finished">
            <div class="buttons">
              <div class="field has-addons">
                <div class="control">
                  <b-button
                    :type="loaded?'is-warning':''"
                    :disabled="finished || !loaded"
                    :loading="busy"
                    @click="step"
                    >Run</b-button>
                </div>
                <div class="control">
                  <div class="select">
                    <select v-model="activeRunMode" :disabled="busy||!loaded">
                      <option v-for="i in runModes" :key="i">{{i}}</option>
                    </select>
                  </div>
                </div>
                <div class="control has-icons-right">
                  <input
                    class="input"
                    :disabled="busy||!loaded"
                    type="number"
                    min="0"
                    v-model="run">
                  <span class="icon is-right">
                    <i class="mdi mdi-clock-outline"></i>
                  </span>
                </div>
                <div class="control">
                  <a class="button is-static">
                    <span>clock cycles</span>
                  </a>
                </div>
              </div>
            </div>
          </div>
          <div class="navbar-item" v-show="finished">
            <span class="tag is-warning is-medium">
              <span class="icon">
                <i class="mdi mdi-flag-checkered"></i>
              </span>
              <span>Finished</span>
            </span>
          </div>
          <div class="navbar-item">
            <b-switch
              @input="$emit('load', $event)"
              v-model="loaded"
              type="is-warning"
              ></b-switch>
          </div>
        </div>

<!--
          <router-link
            class="navbar-item"
            v-for="r in menu.left"
            :key="r.link"
            :to="r.link"
            active-class="is-active"
            >{{ r.name }}</router-link
          >
          <div class="navbar-item">
            <router-link
              class="navbar-item"
              v-for="r in menu.right"
              :key="r.link"
              :to="r.link"
              active-class="is-active"
              >{{ r.name }}</router-link
            >

            <div class="buttons">
              <a class="button is-primary">
                <strong>Sign up</strong>
              </a>
              <a class="button is-light">
                Log in
              </a>
            </div>
-->
        </div>
      </div>
    </div>
  </nav>
</template>

<script>
export default {
  name: "navbar",
  props: {
    name: String,
    params: Array,
    busy: Boolean,
    finished: Boolean
  },
  data() {
    return {
      menu: {},
      loaded: false,
      runModes: ['for', 'every', 'until'],
      activeRunMode: 'for',
      run: 0,
    };
  },
  methods: {
    step () {
      this.$http.post('/api/step', {'mode': this.activeRunMode, 'val': this.run}).then((r) => {
        if (r.status === 200) {
          console.log("RUN", r.body);
          this.$emit('update:busy', true);
        } else {
          alert('Request failed. Returned status of ' + r.status);
        }
      })
    }
  }
};
</script>

<style lang="scss" scoped>
/*
.navbar-menu > div > a.navbar-item.is-active {
  font-family: BigJohnPROBold;
}
.navbar {
  font-family: BigJohnPRORegular;
  font-weight: bold;
  background: transparent !important;
}
.navbar:hover {
  background: rgba(242, 241, 239, 0.75) !important;
  border-bottom: 1px solid #ec563c;
}
*/
</style>
