'use strict';
// Мост игры: вход (общий с лаунчером), адрес сервера и настройки из лаунчера (window.civDesktop)
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('civDesktop', {
  session: () => ipcRenderer.sendSync('g:session'),
  setSession: s => ipcRenderer.send('g:setSession', s || null),
  api: () => ipcRenderer.sendSync('g:api'),
  prefs: () => ipcRenderer.sendSync('g:prefs'),
  setPref: (key, value) => ipcRenderer.send('g:setPref', key, value),
});
