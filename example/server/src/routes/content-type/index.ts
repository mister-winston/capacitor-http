import Hapi from '@hapi/hapi';
import JsonRoutes from './json.js';
import PlaintextRoutes from './plaintext.js';
import MultipartFormRoutes from './multipart-form.js';
import ImageRoutes from './image.js';
import OctetStreamRoutes from './octet-stream.js';
import PdfRoutes from './pdf.js';
import VideoRoutes from './video.js';
import XmlRoutes from './xml.js';
import ZipRoutes from './zip.js';

const output: Hapi.ServerRoute[] = [];
output.push(...JsonRoutes, ...PlaintextRoutes, ...ImageRoutes, ...OctetStreamRoutes, ...PdfRoutes, ...VideoRoutes, ...ZipRoutes, ...MultipartFormRoutes, ...XmlRoutes);
export default output;
