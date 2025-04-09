<template>
    <v-chip v-if="status" style="font-weight: bold;" :color="getStatusColor(status)">
      <v-icon left>{{ getStatusIcon(status) }}</v-icon>
      {{ humanizeStatus(status) }}
    </v-chip>
  </template>

<script>
export default {
  props: {
    status: String,
  },
  methods: {
    getStatusIcon(status) {
      if (!status || status.toLowerCase().includes('stopped') || status.toLowerCase().includes('failed') || status.toLowerCase() === 'n/a') {
        return 'mdi-alert-circle';
      }
      return 'mdi-check-circle';
    },
    humanizeStatus(status) {
      if (!status || status.toLowerCase() === 'n/a') {
        return 'N/A';
      }
      if (!status || status.toLowerCase().includes('stopped') || status.toLowerCase().includes('failed')) {
        return 'Failed';
      }
      return 'Success';
    },
    getStatusColor(status) {
      if (!status || status.toLowerCase() === 'n/a') {
        return 'warn';
      }
      if (!status || status.toLowerCase().includes('stopped') || status.toLowerCase().includes('failed')) {
        return 'error';
      }
      return 'success';
    },
  },
};
</script>

  <style scoped>
  .v-chip {
    display: flex;
    align-items: center;
  }
  </style>
