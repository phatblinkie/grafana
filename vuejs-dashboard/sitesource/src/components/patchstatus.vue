<template>
  <div>
    <v-tabs show-arrows class="pl-4">
      <v-tab
        key="Systemstatus"
        :to="`/systemstatus`"
      >
        System Status
      </v-tab>
      <v-tab
        key="Patchstatus"
        :to="`/patchstatus`"
      >
        Patch Status
      </v-tab>
    </v-tabs>

    <div class="grid-container">
      <div class="grid-item hosts">
        <v-toolbar flat>
          <v-toolbar-title>Hosts and Available Updates</v-toolbar-title>
        </v-toolbar>
        <div class="host-list">
          <ul>
            <li v-for="host in hosts" :key="host.hostname" class="host-item">
              <div class="host-item-content">
                <v-btn
                  small
                  outlined
                  class="host-btn"
                  :class="{ 'active-btn': selectedHost === host.hostname }"
                  @click="onHostSelected(host.hostname, host.os_type)"
                >
                  <span class="truncate">{{ host.hostname }}</span>
                </v-btn>
                <v-chip
                  :color="host.available_updates === 0 ? 'green' : 'teal'"
                  label
                  pill
                  class="ma-2"
                >
                  {{ host.available_updates }}
                </v-chip>
                <v-badge
                  :content="host.formatted_timestamp"
                  color="secondary"
                >
                </v-badge>
              </div>
            </li>
          </ul>
        </div>
      </div>

      <div class="grid-item updates">
        <div v-if="hostDetails">
          <div class="update-buttons">
            <v-btn
              small
              outlined
              :class="{ 'active-btn': activeTable === 'available' }"
              @click="toggleTable('available')"
            >
              Available Updates
            </v-btn>
            <v-btn
              small
              outlined
              :class="{ 'active-btn': activeTable === 'installed' }"
              @click="toggleTable('installed')"
            >
              Installed Updates
            </v-btn>
            <v-btn
              v-if="isWindowsHost"
              small
              outlined
              :class="{ 'active-btn': activeTable === 'Failures' }"
              @click="toggleTable('Failures')"
            >
              Installation Failures
            </v-btn>
          </div>

          <div v-if="showAvailableUpdates" style="margin-top: 20px;">
            <div class="search-bar">
              <v-text-field
                v-model="availableUpdatesSearch"
                label="Perform a search"
                dense
                hide-details
                @input="searchAvailableUpdates"
              ></v-text-field>
            </div>
            <v-simple-table class="updates-table">
              <thead>
                <tr>
                  <th class="text-left">Name</th>
                  <th v-if="isLinuxHost" class="text-left">Version</th>
                  <th v-if="isLinuxHost" class="text-left">Repo</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(update, index) in filteredAvailableUpdates" :key="index">
                  <td class="text-left">{{ update.name || update }}</td>
                  <td v-if="isLinuxHost" class="text-left">{{ update.version }}</td>
                  <td v-if="isLinuxHost" class="text-left">{{ update.repo }}</td>
                </tr>
              </tbody>
            </v-simple-table>
          </div>

          <div v-if="showInstalledUpdates" style="margin-top: 20px;">
            <div class="search-bar">
              <v-text-field
                v-model="installedUpdatesSearch"
                label="Perform a search"
                dense
                hide-details
                @input="searchInstalledUpdates"
              ></v-text-field>
            </div>
            <v-simple-table class="updates-table">
              <thead>
                <tr>
                  <th class="text-left">Name</th>
                  <th v-if="isLinuxHost" class="text-left">Version</th>
                  <th v-if="isLinuxHost" class="text-left">Repo</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(installed, index) in filteredInstalledUpdates" :key="index">
                  <td class="text-left">{{ installed.name || installed }}</td>
                  <td v-if="isLinuxHost" class="text-left">{{ installed.version }}</td>
                  <td v-if="isLinuxHost" class="text-left">{{ installed.repo }}</td>
                </tr>
              </tbody>
            </v-simple-table>
          </div>

          <div v-if="showFailures" style="margin-top: 20px;">
            <div class="search-bar">
              <v-text-field
                v-model="FailuresSearch"
                label="Perform a search"
                dense
                hide-details
                @input="searchFailures"
              ></v-text-field>
            </div>
            <v-simple-table class="updates-table">
              <thead>
                <tr>
                  <th class="text-left">Date</th>
                  <th class="text-left">Status</th>
                  <th class="text-left">Title</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(entry, index) in filteredFailures" :key="index">
                  <td class="text-left">{{ entry.date }}</td>
                  <td class="text-left">{{ entry.status }}</td>
                  <td class="text-left">{{ entry.title }}</td>
                </tr>
              </tbody>
            </v-simple-table>
          </div>
        </div>
        <div v-else>
          <v-toolbar flat>
            <v-toolbar-title>Select a host to see details.</v-toolbar-title>
          </v-toolbar>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios';

export default {
  name: 'PatchStatus',
  data() {
    return {
      hosts: [],
      hostDetails: null,
      showAvailableUpdates: false,
      showInstalledUpdates: false,
      showFailures: false,
      availableUpdatesSearch: '',
      installedUpdatesSearch: '',
      FailuresSearch: '',
      filteredAvailableUpdates: [],
      filteredInstalledUpdates: [],
      filteredFailures: [],
      selectedHost: null,
      activeTable: 'available',
      headers: [
        { text: 'Host', value: 'hostname' },
        {
          text: 'Available Updates',
          value: 'available_updates',
        },
      ],
    };
  },
  computed: {
    isLinuxHost() {
      return this.hostDetails && this.hostDetails.os_type === 'linux';
    },
    isWindowsHost() {
      return this.hostDetails && this.hostDetails.os_type === 'windows';
    },
  },
  created() {
    this.fetchHosts();
  },
  methods: {
    async fetchHosts() {
      try {
        const resp = await axios.get(
          '/post/get_patch_status_hosts_sqlite.php?project_id=2',
        );
        this.hosts = resp.data;
      } catch (error) {
        console.error('Error fetching hosts:', error);
      }
    },

    async onHostSelected(hostname, osType) {
      this.selectedHost = hostname;
      this.activeTable = 'available';
      this.showAvailableUpdates = true;
      this.showInstalledUpdates = false;
      this.showFailures = false;
      this.clearSearchFields();
      await this.fetchHostDetails(hostname, osType);
    },

    async fetchHostDetails(hostname, osType) {
      try {
        const resp = await axios.get(
          `/post/get_combined_patch_status_sqlite.php?project_id=2&hostname=${hostname}&os_type=${osType}`,
        );
        this.hostDetails = resp.data;
        this.hostDetails.os_type = osType; // Ensure os_type is set correctly
        this.filteredAvailableUpdates = this.hostDetails.updates || [];
        this.filteredInstalledUpdates = this.hostDetails.installedUpdates || [];
        this.filteredFailures = this.hostDetails.Failures || [];
      } catch (error) {
        console.error('Error fetching host details:', error);
      }
    },

    searchAvailableUpdates() {
      if (!this.availableUpdatesSearch) {
        this.filteredAvailableUpdates = this.hostDetails.updates || [];
        return;
      }
      this.filteredAvailableUpdates = this.hostDetails.updates.filter((update) => {
        const name = update.name || update;
        const version = update.version || '';
        const repo = update.repo || '';
        return (
          name.toLowerCase().includes(this.availableUpdatesSearch.toLowerCase())
          || (this.isLinuxHost && version.toLowerCase().includes(this.availableUpdatesSearch.toLowerCase()))
          || (this.isLinuxHost && repo.toLowerCase().includes(this.availableUpdatesSearch.toLowerCase()))
        );
      });
    },

    searchInstalledUpdates() {
      if (!this.installedUpdatesSearch) {
        this.filteredInstalledUpdates = this.hostDetails.installedUpdates || [];
        return;
      }
      this.filteredInstalledUpdates = this.hostDetails.installedUpdates.filter((installed) => {
        const name = installed.name || installed;
        const version = installed.version || '';
        const repo = installed.repo || '';
        return (
          name.toLowerCase().includes(this.installedUpdatesSearch.toLowerCase())
          || (this.isLinuxHost && version.toLowerCase().includes(this.installedUpdatesSearch.toLowerCase()))
          || (this.isLinuxHost && repo.toLowerCase().includes(this.installedUpdatesSearch.toLowerCase()))
        );
      });
    },

    searchFailures() {
      if (!this.FailuresSearch) {
        this.filteredFailures = this.hostDetails.Failures || [];
        return;
      }
      this.filteredFailures = this.hostDetails.Failures.filter((entry) => (
        entry.date.toLowerCase().includes(this.FailuresSearch.toLowerCase())
        || entry.date.toLowerCase().includes(this.FailuresSearch.toLowerCase())
        || entry.title.toLowerCase().includes(this.FailuresSearch.toLowerCase())
        || entry.status.toLowerCase().includes(this.FailuresSearch.toLowerCase())
      ));
    },

    toggleTable(table) {
      this.activeTable = table;
      if (table === 'available') {
        this.showAvailableUpdates = true;
        this.showInstalledUpdates = false;
        this.showFailures = false;
        this.installedUpdatesSearch = ''; // Reset search field
        this.FailuresSearch = ''; // Reset search field
        this.filteredAvailableUpdates = this.hostDetails.updates || [];
      } else if (table === 'installed') {
        this.showInstalledUpdates = true;
        this.showAvailableUpdates = false;
        this.showFailures = false;
        this.availableUpdatesSearch = ''; // Reset search field
        this.FailuresSearch = ''; // Reset search field
        this.filteredInstalledUpdates = this.hostDetails.installedUpdates || [];
      } else if (table === 'Failures') {
        this.showFailures = true;
        this.showAvailableUpdates = false;
        this.showInstalledUpdates = false;
        this.availableUpdatesSearch = ''; // Reset search field
        this.installedUpdatesSearch = ''; // Reset search field
        this.filteredFailures = this.hostDetails.Failures || [];
      }
    },

    clearSearchFields() {
      this.availableUpdatesSearch = '';
      this.installedUpdatesSearch = '';
      this.FailuresSearch = '';
    },
  },
  watch: {
    showAvailableUpdates(newVal) {
      if (newVal) {
        this.installedUpdatesSearch = ''; // Reset search field
        this.FailuresSearch = ''; // Reset search field
      }
    },
    showInstalledUpdates(newVal) {
      if (newVal) {
        this.availableUpdatesSearch = ''; // Reset search field
        this.FailuresSearch = ''; // Reset search field
      }
    },
    showFailures(newVal) {
      if (newVal) {
        this.availableUpdatesSearch = ''; // Reset search field
        this.installedUpdatesSearch = ''; // Reset search field
      }
    },
    installedUpdatesSearch(newVal) {
      // If search is cleared, ensure we still have an array
      if (!newVal) {
        this.filteredInstalledUpdates = this.hostDetails.installedUpdates || [];
      }
    },
  },
  beforeDestroy() {
    this.clearSearchFields();
  },
};
</script>

<style scoped>
.grid-container {
  display: grid;
  grid-template-columns: 1fr 3fr;
  gap: 20px;
}
.grid-item {
  padding: 10px;
}
.hostsdisabled {
  background-color: #f9f9f9;
}
.updatesdisabled {
  background-color: #ffffff;
}
.fixed-table {
  max-width: 100%;
  table-layout: auto;
  border-collapse: collapse;
  overflow: hidden;
}
.fixed-table th,
.fixed-table td {
  border: 1px solid #ddd;
  padding: 8px;
  text-align: left;
  white-space: normal;
  text-overflow: ellipsis;
  vertical-align: top;
}
html,
body {
  overflow-x: hidden;
}
.fixed-table th {
  background-color: #f2f2f2;
  font-weight: bold;
}
.align-left {
  margin-left: 0;
}
.host-list ul {
  list-style-type: none;
  padding: 0;
}
.host-list li {
  margin-bottom: 2px; /* Reduced margin */
  text-align: left;
}
.host-item-content {
  display: block;
}
.host-btn {
  width: 230px; /* Set a fixed width for the buttons */
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  text-align: left; /* Left-align the text inside the button */
}
.truncate {
  display: inline-block;
  max-width: 80%;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.host-details div {
  margin-bottom: 10px;
}
.update-list ul {
  list-style-type: none;
  padding: 0;
}
.update-list li {
  margin-bottom: 10px;
}
.update-items {
  text-align: left;
}
.update-items .update-item:nth-child(odd) {
  background-color: #f9f9f9;
}
.update-items .update-item:nth-child(even) {
  background-color: #e9e9e9;
}
.search-bar {
  margin-bottom: 10px;
}
.update-buttons {
  text-align: left; /* Align buttons to the left */
  margin-top: 0px;  /* Reduced margin */
}
.active-btn {
  background-color: #1976d2 !important;
  color: white !important;
}
.updates-table {
  width: 100%;
  table-layout: auto;
}
</style>
