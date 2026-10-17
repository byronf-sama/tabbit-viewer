// Proves that relative scripts load: updates the status line on the sample page.
const status = document.getElementById("script-status");
status.textContent = "script ran at " + new Date().toLocaleTimeString();
status.classList.add("ok");
