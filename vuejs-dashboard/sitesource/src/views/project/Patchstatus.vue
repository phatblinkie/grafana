<template>
  <div>
    <v-toolbar flat>
      <v-toolbar-title>Patch Status</v-toolbar-title>
    </v-toolbar>
    <v-container>
      <!-- Blank page content -->
      <v-row>
        <v-col>
          <h1>Patch Status</h1>
          <p>This page is currently under construction.</p>
        </v-col>
      </v-row>
    </v-container>
  </div>
</template>

<script>
import Patchstatus from '@/components/patchstatus.vue';

export default {
  name: 'App',
  components: {
    Patchstatus,
  },
};
</script>

<style>
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 0px;
}
</style>
