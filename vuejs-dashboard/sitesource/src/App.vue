<template>
  <v-app v-if="state === 'success'" class="app">
    <v-main>
      <router-view
        :userPermissions="(userRole || {}).permissions"
        :userRole="(userRole || {}).role"
        :userId="(user || {}).id"
        :isAdmin="(user || {}).admin"
        :user="user"
      ></router-view>
    </v-main>

  </v-app>
  <v-app v-else-if="state === 'loading'">
    <v-main>
      <v-container
        fluid
        fill-height
        align-center
        justify-center
        class="pa-0"
      >
        <v-progress-circular
          :size="70"
          color="primary"
          indeterminate
        ></v-progress-circular>
      </v-container>
    </v-main>
  </v-app>
  <v-app v-else-if="state === 'error'">
    <v-main>
      <v-container
        fluid
        flex-column
        fill-height
        align-center
        justify-center
        class="pa-0 text-center"
      >
        <div class="mb-6">
          <v-btn text color="blue darken-1" @click="refreshPage()">
            <v-icon left>mdi-refresh</v-icon>
            'refreshPage'
          </v-btn>

        </div>
      </v-container>
    </v-main>
  </v-app>
  <v-app v-else></v-app>
</template>
<style lang="scss">

.v-alert__wrapper {
  overflow: auto;
}

.v-dialog > .v-card > .v-card__title {
  flex-wrap: nowrap;
  overflow: hidden;

  & * {
    white-space: nowrap;
  }
}

.v-data-table tbody tr.v-data-table__expanded__content {
  box-shadow: none !important;

}

.v-data-table a {
  text-decoration-line: none;

  &:hover {
    text-decoration-line: underline;
  }
}

.breadcrumbs__item--link {
  text-decoration-line: none;

  &:hover {
    text-decoration-line: underline;
  }
}

.breadcrumbs__separator {
  padding: 0 10px;
}

.app__project-selector {
  height: 64px;

  & > .v-list-item__content {
    padding: 0;
  }

  .v-list-item__icon {
    margin-top: 20px !important;
  }
}

.app__project-selector-title {
  font-size: 1.25rem !important;
  font-weight: bold;
}

.v-application--is-ltr .v-list-item__action:first-child,
.v-application--is-ltr .v-list-item__icon:first-child {
  margin-right: 16px !important;
}

.v-toolbar__content {
  height: 64px !important;
}

.v-data-table-header {
}

.v-data-table > .v-data-table__wrapper > table > thead > tr:last-child > th {
  text-transform: uppercase;
  white-space: nowrap;
}

.v-data-table > .v-data-table__wrapper > table > tbody > tr {
  background: transparent !important;

  & > td {
    white-space: nowrap;
  }

  & > td:first-child {
    //font-weight: bold !important;
  }
}

.v-data-table > .v-data-table__wrapper > table > tbody > tr > th,
.v-data-table > .v-data-table__wrapper > table > thead > tr > th,
.v-data-table > .v-data-table__wrapper > table > tfoot > tr > th,
.v-data-table > .v-data-table__wrapper > table > tbody > tr > td {
  font-size: 1rem !important;
}

.v-data-footer {
  font-size: 1rem !important;
}

.v-toolbar__title {
  font-weight: bold !important;
}

.v-app-bar__nav-icon {
  margin-left: 0 !important;
}

.v-toolbar__title:not(:first-child) {
  margin-left: 10px !important;
}

@media (min-width: 960px) {
  .v-app-bar__nav-icon {
    display: none !important;
  }

  .v-toolbar__title:not(:first-child) {
    padding-left: 0 !important;
    margin-left: 0 !important;
  }
}

</style>

<script>

import { getErrorMessage } from '@/lib/error';
import EventBus from '@/event-bus';
import socket from '@/socket';

export default {
  name: 'App',
  components: {
  },
  data() {
    return {
      drawer: null,
      user: null,
      userRole: null,
      systemInfo: null,
      state: 'loading',
      darkMode: true,
    };
  },

  watch: {
    darkMode(val) {
      this.$vuetify.theme.dark = val;
      if (val) {
        localStorage.setItem('darkMode', '1');
      } else {
        localStorage.removeItem('darkMode');
      }
    },
  },

  computed: {
    isAuthenticated() {
      // return document.cookie.includes('semaphore=');
      return false;
    },

  },

  async created() {
    if (!this.isAuthenticated) {
      this.state = 'success';
      return;
    }

    if (localStorage.getItem('darkMode') === '0') {
      this.darkMode = false;
    } else {
      this.darkMode = true;
    }

    try {
      await this.loadData();
      this.state = 'success';
    } catch (err) {
      EventBus.$emit('i-snackbar', {
        color: 'error',
        text: getErrorMessage(err),
      });
      this.state = 'error';
      socket.stop();
    }
  },

  mounted() {
    EventBus.$on('i-snackbar', (e) => {
      this.snackbar = true;
      this.snackbarColor = e.color;
      this.snackbarText = e.text;
    });

    EventBus.$on('i-show-drawer', async () => {
      this.drawer = true;
    });
  },

  methods: {

    refreshPage() {
      const { location } = document;
      document.location = location;
    },
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
