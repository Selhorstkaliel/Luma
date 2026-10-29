// SPDX-License-Identifier: GPL-2.0-or-later
// Layout Luma para Plasma 6 (validado no 6.3 do LUMA-OS; revalidar no 6.6 do Fedora 44 [H]):
// painel superior fino + dock flutuante centralizado.
// Copiado como contents/layouts/org.kde.plasma.desktop-layout.js nos dois pacotes Look-and-Feel.
// API: https://develop.kde.org/docs/plasma/scripting/ (propriedades conferidas no plasmashell 6.3.6)

// Painel superior (mockups: logotipo e menu do app à esquerda; bandeja e relógio à direita)
var topBar = new Panel;
topBar.location = "top";
topBar.height = Math.max(28, 2 * Math.floor(gridUnit * 1.7 / 2));
topBar.floating = false;
var launcher = topBar.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "luma-logo");
launcher.writeConfig("favoritesDisplay", 0);      // grade
launcher.writeConfig("applicationsDisplay", 0);   // grade
topBar.addWidget("org.kde.plasma.appmenu");
topBar.addWidget("org.kde.plasma.panelspacer");
topBar.addWidget("org.kde.plasma.systemtray");
topBar.addWidget("org.luma.controlcenter");   // Central de Controle (mockup claro)
var clock = topBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", false);

// Dock: flutuante, centralizado, ícones grandes, lixeira no fim
var dock = new Panel;
dock.location = "bottom";
dock.height = 2 * Math.floor(gridUnit * 3.6 / 2);
dock.floating = true;
dock.lengthMode = "fit";
dock.alignment = "center";
dock.hiding = "none";
var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:org.mozilla.firefox.desktop",   // o build da imagem troca pelo .desktop que existir (build/image/build.sh)
    "applications:org.kde.konsole.desktop",
    "applications:org.kde.discover.desktop",
    "applications:org.luma.ajustes.desktop"
]);
dock.addWidget("org.kde.plasma.marginsseparator");
dock.addWidget("org.kde.plasma.trash");

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image";
    // Definido aqui (e não depois, por plasma-apply-wallpaperimage) para não concorrer com a recriação do layout
    desktopsArray[j].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktopsArray[j].writeConfig("Image", "file:///usr/share/wallpapers/Luma");
}
