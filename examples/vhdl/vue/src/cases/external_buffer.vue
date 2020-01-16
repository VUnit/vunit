<template>
  <div class="container">
    <Memory
      name="buffer"
      :buf="content.mem"/>
  </div>
</template>

<script>
import Memory from "@/components/Memory.vue";

function isEmpty(obj) {
  for(var key in obj) {
    if(obj.hasOwnProperty(key))
      return false;
  }
  return true;
}

export default {
  name: 'external_buffer',
  components: {
    Memory
  },
  props: {
    data: Object
  },
  computed: {
    content() {
      return (isEmpty(this.data)) ? {
        mem: [],
      } : {
        mem: this.data.mem,
      };
    }
  },
  methods: {
    isEmpty(d) {
      return isEmpty(d);
    }
  }
}
</script>
