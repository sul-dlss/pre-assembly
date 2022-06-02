// Entry point for the build script in your package.json
import * as bootstrap from "bootstrap";
import $ from 'jquery';
import tmpl from './tmpl';

window.jQuery = $;
window.$ = $;
window.tmpl = tmpl;
