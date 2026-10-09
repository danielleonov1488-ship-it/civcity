'use strict';
// Мост лаунчера: окно лаунчера видит только эти действия, всё остальное делает программа (main.js)
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('civ', {
  info: () => ipcRenderer.invoke('l:info'),
  content: () => ipcRenderer.invoke('l:content'),
  login: (mode, email, password) => ipcRenderer.invoke('l:login', mode, email, password),
  forgot: email => ipcRenderer.invoke('l:forgot', email),
  logout: () => ipcRenderer.invoke('l:logout'),
  setPref: (key, value) => ipcRenderer.invoke('l:setPref', key, value),
  play: () => ipcRenderer.invoke('l:play'),
  downloadShell: () => ipcRenderer.invoke('l:shell'),
  open: url => ipcRenderer.invoke('l:open', url),
  win: what => ipcRenderer.send('l:win', what),
  onUpdate: cb => ipcRenderer.on('l:update', (e, s) => cb(s)),
});
