import { seedDemo } from './demo_fixtures.mjs';
await seedDemo();
console.log('Local demo fixtures ready. Password: CampusFixDemo123!');
console.log('Reporter: reporter-demo@campusfix.test; technician: technician-demo@campusfix.test');
console.log('Assigned case: http://127.0.0.1:8080/#/incidents/demo-assigned');
