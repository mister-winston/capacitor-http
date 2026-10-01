import Hapi from '@hapi/hapi';
import EmptyRoutes from './empty.js';
import JsonRoutes from './json.js';
import StringRoutes from './string.js';
import NumberRoutes from './number.js';
import BooleanRoutes from './bool.js';

const output: Hapi.ServerRoute[] = [];
output.push(...EmptyRoutes, ...JsonRoutes, ...StringRoutes, ...NumberRoutes, ...BooleanRoutes);
export default output;
