import Vue from 'vue';
import VueRouter from 'vue-router';
import Systemstatus from '../views/project/Systemstatus.vue';
import HostGraphs from '../views/project/HostGraphs.vue';
import Patchstatus from '../components/patchstatus.vue';
import Compliancestatus from '../views/project/compliancestatus.vue'; // Import the new component

Vue.use(VueRouter);

const routes = [
  {
    path: '/',
    component: Systemstatus,
  },
  {
    path: '/systemstatus',
    component: Systemstatus,
  },
  {
    path: '/host/:hostname',
    component: HostGraphs,
  },
  {
    path: '/patchstatus',
    component: Patchstatus,
  },
  {
    path: '/compliancestatus',
    component: Compliancestatus,
  },
  {
    path: '*', // Catch all unmatched routes
    redirect: '/systemstatus', // Redirect to Systemstatus
  },

];

const router = new VueRouter({
  mode: 'history',
  base: '/oldsite/',
  routes,
});

export default router;
