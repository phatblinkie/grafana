<template>
  <div>
    <v-toolbar flat>
      <v-toolbar-title>Graphs for Host: {{ hostname }}</v-toolbar-title>
    </v-toolbar>
    <v-tabs show-arrows class="pl-4">
      <v-tab key="Systemstatus" :to="`/systemstatus`">
        System Status
      </v-tab>
      <v-tab key="Patchstatus" :to="`/patchstatus`">Patch Status</v-tab>
    </v-tabs>
    <br>
    <table width="100%">
      <v-row>
        <v-btn @click="setTimeFrame('today')">Today</v-btn>
        <v-btn @click="setTimeFrame('week')">7 Days</v-btn>
        <v-btn @click="setTimeFrame('month')">30 Days</v-btn>
        <v-btn @click="setTimeFrame('90days')">90 Days</v-btn>
      </v-row>
      <v-row class="left-aligned">
        <v-col cols="12">
          <apexchart
            type="line"
            height="300"
            :options="diskChartOptions"
            :series="diskSeries"
            :key="diskChartKey"
          ></apexchart>
        </v-col>
      </v-row>
      <v-row class="left-aligned">
        <v-col cols="12">
          <apexchart
            type="line"
            height="300"
            :options="procChartOptions"
            :series="procSeries"
            :key="procChartKey"
          ></apexchart>
        </v-col>
      </v-row>
      <v-row class="left-aligned">
        <v-col cols="12">
          <apexchart
            type="line"
            height="300"
            :options="uptimeChartOptions"
            :series="uptimeSeries"
            :key="uptimeChartKey"
          ></apexchart>
        </v-col>
      </v-row>
    </table>
  </div>
</template>

<script>
import axios from 'axios';
import VueApexCharts from 'vue-apexcharts';

export default {
  components: {
    apexchart: VueApexCharts,
  },
  data() {
    return {
      hostname: this.$route.params.hostname,
      timeFrame: 'today', // Default time frame
      diskSeries: [],
      procSeries: [
        {
          name: 'Proc Usage',
          data: [],
        },
      ],
      uptimeSeries: [
        {
          name: 'Uptime',
          data: [],
        },
      ],
      diskChartOptions: {
        chart: {
          height: 300,
          type: 'line',
        },
        xaxis: {
          categories: [],
        },
        stroke: {
          curve: 'smooth',
        },
        title: {
          text: 'Disk Capacity % Used',
          align: 'left',
        },
      },
      procChartOptions: {
        chart: {
          height: 300,
          type: 'line',
        },
        xaxis: {
          categories: [],
        },
        stroke: {
          curve: 'smooth',
        },
        title: {
          text: 'Proc Usage',
          align: 'left',
        },
      },
      uptimeChartOptions: {
        chart: {
          height: 300,
          type: 'line',
        },
        xaxis: {
          categories: [],
        },
        stroke: {
          curve: 'smooth',
        },
        title: {
          text: 'Uptime',
          align: 'left',
        },
      },
      diskChartKey: 0, // Add a key to force re-render
      procChartKey: 0, // Add a key to force re-render
      uptimeChartKey: 0, // Add a key to force re-render
    };
  },
  mounted() {
    this.fetchData();
  },
  watch: {
    '$route.params': {
      handler() {
        this.hostname = this.$route.params.hostname;
        this.fetchData();
      },
      immediate: true,
    },
  },
  methods: {
    setTimeFrame(timeFrame) {
      this.timeFrame = timeFrame;
      this.fetchData();
    },
    fetchData() {
      axios
        .get(`/post/get_host_history_sqlite.php?project_id=2&hostname=${this.hostname}&time_frame=${this.timeFrame}`)
        .then((response) => {
          const data = response.data;
          // console.log('Fetched data:', data); // Debugging line to check the fetched data

          if (!Array.isArray(data)) {
            throw new Error('Expected data to be an array');
          }

          const categories = data.map((entry) => entry.last_updated);

          // Initialize disk series
          const diskSeriesMap = {};

          data.forEach((entry) => {
            if (Array.isArray(entry.disk_capacity)) {
              entry.disk_capacity.forEach((disk) => {
                if (!diskSeriesMap[disk.name]) {
                  diskSeriesMap[disk.name] = {
                    name: disk.name,
                    data: [],
                  };
                }
                diskSeriesMap[disk.name].data.push({
                  x: entry.last_updated,
                  y: disk.used,
                });
              });
            }
          });

          this.diskSeries = Object.values(diskSeriesMap);

          this.procChartOptions.xaxis.categories = categories;
          this.uptimeChartOptions.xaxis.categories = categories;
          this.procSeries[0].data = data.map((entry) => parseFloat(entry.proc_usage));
          this.uptimeSeries[0].data = data.map((entry) => parseFloat(entry.uptime));
          this.diskChartKey += 1; // Update the key to force re-render
          this.procChartKey += 1; // Update the key to force re-render
          this.uptimeChartKey += 1; // Update the key to force re-render
        })
        .catch((error) => {
          console.error('Error fetching data:', error);
        });
    },
  },
};
</script>

<style scoped>
.chart-wrapper {
  height: 350px;
}
.left-aligned {
  justify-content: flex-start;
}
</style>
