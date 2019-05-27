<template>
  <div id="app">
    <NavBar
      v-on:load="load"
      :name.sync="name"
      :params.sync="params"
      :loaded.sync="loaded"
      :busy.sync="busy"
      :finished.sync="finished"
    />

    <section class="hero" v-if="!loaded">
      <div class="hero-body">
        <div class="container has-text-centered">
          <h1 class="title">
            No design loaded, yet
          </h1>
          <h2 class="subtitle">
            Turn the switch on to start the simulation.
          </h2>
        </div>
      </div>
    </section>
  </div>
</template>

<script>
import Vue from 'vue'

import VueResource from 'vue-resource'
Vue.use(VueResource);

import "@mdi/font/css/materialdesignicons.css";

import Buefy from "buefy";
import "buefy/dist/buefy.css";
Vue.use(Buefy);

import NavBar from "@/components/NavBar.vue";

export default {
  name: 'app',
  components: {
    NavBar
  },
  data() {
    return {
      name: '',
      params: [0, 0, 0],
      data: {},
      loaded: false,
      polling: null,
      busy: false,
      finished: false
    };
  },
  methods: {
    setPolling () {
      this.polling = setInterval(() => {
        this.$http.get('/api/update').then((r) => {
          if (r.status === 200) {
            console.log('UPDATE', r.body)
            this.loaded = true;
            var u = r.body['update']
            if (u != 0) {
                this.name = r.body.name;
                this.params = r.body.params;
                this.data = r.body.data;
                this.busy = false;
                var msg = 'Data updated!'
                if (u == 2) {
                  this.finished = true;
                  msg = 'Simulation finished!'
                }
                this.$toast.open({
                  duration: 2000,
                  message: msg,
                  position: 'is-bottom',
                  type: 'is-warning'
                })
            }
          } else {
            alert('Request failed. Returned status of ' + r.status);
          }
        })
      }, 2000);
    },
    load (v) {
      if (v === true) {
        this.setPolling();
        this.busy = true;
        this.$http.get('/api/load').then((r) => {
          if (r.status === 200) {
            console.log('LOAD', r.body)
          } else {
            alert('Request failed. Returned status of ' + r.status);
          }
        });
      } else {
        clearInterval(this.polling);
        this.$http.get('/api/unload').then((r) => {
          if (r.status === 200) {
            console.log('UNLOAD', r.body)
          } else {
            alert('Request failed. Returned status of ' + r.status);
          }
        })
      }
    },
  }
}
</script>

<style>
#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>

<style lang="scss">
@import "~bulma";
@import "~buefy/src/scss/buefy";

@font-face {
  font-family: BigJohnPRORegular;
  src: url("assets/fonts/BigJohnPRO-Regular.otf");
}
@font-face {
  font-family: BigJohnPROLight;
  src: url("assets/fonts/BigJohnPRO-Light.otf");
}
@font-face {
  font-family: BigJohnPROBold;
  src: url("assets/fonts/BigJohnPRO-Bold.otf");
}
/*
html,
body,
#app {
  height: 100%;
  max-height: 100%;
  background-color: #f2f1ef;
}
#view {
  flex-grow: 1;
}
#app {
  font-family: "Fenix", "Avenir", Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #202a33;
  display: flex;
  flex-direction: column;
}
.nothome {
  padding-top: 56px;
}
hr {
  height: 1px;
  background-color: #ec563c;
  margin: 1rem 0;
}
*/
</style>