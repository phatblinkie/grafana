<template>
  <div>
    <v-toolbar flat>
      <v-toolbar-title>Compliance Status</v-toolbar-title>
    </v-toolbar>
    <v-tabs show-arrows class="pl-4">
      <v-tab key="Systemstatus" :to="`/systemstatus`">System Status</v-tab>
      <v-tab key="TaskGraphs" :to="`/graphs`">Task Graphs</v-tab>
      <v-tab key="Patchstatus" :to="`/patchstatus`">Patch Status</v-tab>
      <v-tab key="Compliancestatus" :to="`/compliancestatus`">
        Compliance Status
      </v-tab>
    </v-tabs>
    <v-container>
      <v-row>
        <v-col>
          <h1>Under Construction</h1>
          <p>This page is currently under construction. Please check back later.</p>
        </v-col>
      </v-row>
    </v-container>
  </div>
</template>

<script>
export default {
  name: 'Compliancestatus',
};
</script>

<style scoped>
.container {
  width: 100%;
  padding: 12px;
  margin-right: auto;
  margin-left: 18px;
  text-align: center;
}

h1 {
  font-size: 2em;
  margin-bottom: 0.5em;
}

p {
  font-size: 1.2em;
}
</style>
