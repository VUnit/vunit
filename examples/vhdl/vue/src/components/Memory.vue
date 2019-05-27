<template>
<div class="box">
  <b-table
    :data="content"
    :columns="columns"
    striped="true"
    narrowed="true"
    hoverable="true"
    :paginated="true"
    :per-page="perPage"
    :current-page.sync="currentPage"
    paginationSize="is-small">
    <template slot="bottom-left">
      <span class="tag is-static is-small" style="margin-right: 0.75rem;">
        <span class="has-text-weight-semibold">id:&nbsp;</span>
        <span>{{name}}</span>
        <span class="has-text-weight-semibold">&nbsp;size:&nbsp;</span>
        <span>{{buf.length}} bytes</span>
      </span>
      <b-switch
        v-model="decimal"
        size="is-small"
        type="is-info"
        >Decimal</b-switch>
    </template>
    </b-table>
</div>
</template>

<script>
var columns = [{
    field: 'addr',
    label: '',
}]

for (var i=0; i<16; i++) {
    var x = (i).toString(16)
    columns.push({
      field: x,
      label: x,
      centered: true,
    })
}

export default {
  name: "navbar",
  props: {
    name: String,
    buf: [],
  },
  data() {
    return {
      decimal: true,
      perPage: 32,
      currentPage: 1,
      columns: columns
    }
  },
  computed: {
    content() {
      var base = this.decimal ? 10 : 16;
      var l = this.buf.length
      var d = []
      var y = 0
      for (var i=0; i<Math.ceil(l/16); i++) {
          var r = { 'addr': '0x' + ((i*16).toString(16)).padStart(4, '0') };
          for (var x=0; x<16; x++) {
            y = i*16+x;
            if (y >= l) { break; }
            r[x.toString(16)] = this.buf[y].toString(base);
          }
          d.push(r);
      }
      return d;
    }
  }
};
</script>

<style lang="scss">
.b-table .level {
  padding-bottom: 0 !important;
}
</style>
