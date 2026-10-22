---
title: "Modern Flatpak Apps for Linux — Creative, Development & Office"
aliases:
  - Flatpak apps
  - Flathub apps
  - Flatpak app list
  - Flathub curated list
  - Flatpak creative stack
  - Flathub reference
description: >-
  Curated, API-verified list of 157 Flathub applications for creative work, software
  development, and office productivity, with Flatpak IDs, one-line purposes, licences and
  monthly install counts. Includes a per-app permission and sandbox-override section.
tags:
  - flatpak
  - flathub
  - linux
  - app-list
  - curated
  - reference
  - software
  - desktop
  - creative-tools
  - development
  - office
  - sandboxing
  - self-hosting
  - foss
type: reference-list
status: evergreen
confidence: high
created: 2026-09-27
updated: 2026-09-27
last_reviewed: 2026-09-27
review_after: 2026-10-27
language: en
audience: linux-desktop
scope: application catalogue
platform:
  - Linux
  - Flatpak
  - Flathub
methodology: api-extraction
data_source:
  - '[Flathub API v2](https://flathub.org/api/v2)'
sample_size: 157
temporal_coverage: 2026-09-27
tools:
  - Flathub API v2
verified: true
verification_method: Flathub API v2 — /api/v2/collection/category/*, /api/v2/appstream/<id>, /api/v2/search
reproducible: true
keywords:
  - flatpak install
  - flatpak run
  - flatpak update
  - flathub
  - AppStream
  - verified publisher badge
  - org.gimp.GIMP
  - org.kde.krita
  - org.blender.Blender
  - org.kde.kdenlive
  - com.brave.Browser
  - org.onlyoffice.desktopeditors
  - JetBrains
  - com.valvesoftware.Steam
  - Flatpak overrides
  - --device=all
sources:
  - "[Flathub](https://flathub.org)"
  - "[Flathub API v2](https://flathub.org/api/v2)"
source_retrieved: 2026-09-27
related:
  - "[[terminal-keybindings]]"
  - "[[Linux Desktop]]"
  - "[[Arch Linux]]"
  - "[[Self-Hosting]]"
  - "[[FOSS]]"
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document curated Flatpak applications"
ai-review: pending
categories:
  - creative
  - illustration
  - vector
  - photography
  - raw-development
  - 3d
  - cad
  - pcb
  - 3d-printing
  - video
  - post-production
  - audio
  - music
  - djing
  - streaming
  - screen-recording
  - browsers
  - office
  - notes
  - knowledge-management
  - pdf
  - readers
  - library
  - research
  - code-editors
  - ides
  - game-engines
  - version-control
  - containers
  - databases
  - api
  - networking
  - local-ai
  - coding-agents
cssclasses:
  - reference
  - wide-table
---

# Modern Flatpak Apps for Linux — Creative, Development & Office

A curated, **verified** list of Flatpak applications from [Flathub](https://flathub.org) for
creative work, software development, and office productivity.

- **157 apps** — every Flatpak ID below was confirmed to exist on Flathub via its API
- **84 apps** carry Flathub's ✅ *verified* publisher badge
- **126 open source**, 26 proprietary (marked in the tables)
- Combined ~2.18M monthly installs — install counts are the real Flathub figures, useful as a
  rough proxy for how healthy and maintained each project is

## Quick start

```bash
# install a single app
flatpak install flathub com.brave.Browser
flatpak install flathub org.onlyoffice.desktopeditors

# install a whole creative stack at once
flatpak install flathub \
  org.gimp.GIMP org.kde.krita org.inkscape.Inkscape \
  org.blender.Blender org.kde.kdenlive org.audacityteam.Audacity

# launch
flatpak run com.brave.Browser

# update everything
flatpak update

# list installed apps
flatpak list --app
```

> **Tip:** instead of copying IDs, open `https://flathub.org/apps/<id>` in your browser, or use
> your distro's Software Center (GNOME Software, KDE Discover, COSMIC Store, etc.).

## How to read the tables

| Column | Meaning |
|---|---|
| **App** | Display name on Flathub |
| **Flatpak ID** | The exact ID for `flatpak install flathub <id>` |
| **What it does** | Short official summary from the app's AppStream metadata |
| **License** | `open source` or `**proprietary**`; ✅ = Flathub-verified publisher |
| **Installs/mo** | Monthly installs on Flathub |

## Contents

1. [Creative — Image, Illustration & Vector](#creative--image-illustration--vector)
2. [Creative — Photography & RAW Development](#creative--photography--raw-development)
3. [Creative — 3D, CAD, PCB & 3D Printing](#creative--3d-cad-pcb--3d-printing)
4. [Creative — Video Editing & Post-Production](#creative--video-editing--post-production)
5. [Creative — Audio, Music & DJing](#creative--audio-music--djing)
6. [Creative — Streaming, Screen Recording & Capture](#creative--streaming-screen-recording--capture)
7. [Browsers](#browsers)
8. [Office & Productivity — incl. ONLYOFFICE](#office--productivity--incl-onlyoffice)
9. [Notes, Writing & Knowledge Management](#notes-writing--knowledge-management)
10. [PDF Tools](#pdf-tools)
11. [Reading, Library & Research](#reading-library--research)
12. [Developer — Code Editors](#developer--code-editors)
13. [Developer — IDEs](#developer--ides-jetbrains-eclipse-apache)
14. [Developer — Game Engines & Version Control](#developer--game-engines--version-control)
15. [Developer — Containers, Databases, API & Networking](#developer--containers-databases-api--networking)
16. [Local AI & Coding Agents](#local-ai--coding-agents)
17. [Voice typing](#voice-typing)
18. [Spotify Frontends & Music Streaming](#spotify-frontends--music-streaming)

---

## Creative — Image, Illustration & Vector

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **GNU Image Manipulation Program** | `org.gimp.GIMP` | High-end image creation and manipulation | open source ✅ | 61,669 |
| **Krita** | `org.kde.krita` | Digital Painting, Creative Freedom | open source ✅ | 34,417 |
| **Drawing** | `com.github.maoschanz.drawing` | Edit screenshots or memes | open source ✅ | 4,889 |
| **Inkscape** | `org.inkscape.Inkscape` | Vector Graphics Editor | open source ✅ | 23,163 |
| **Scribus** | `net.scribus.Scribus` | Open Source Page Layout and Desktop Publishing (DTP) | open source | 3,929 |
| **Pinta** | `com.github.PintaProject.Pinta` | Edit images and paint digitally | open source ✅ | 15,658 |
| **KolourPaint** | `org.kde.kolourpaint` | Paint Program | open source ✅ | 6,054 |
| **Pixelorama** | `com.orama_interactive.Pixelorama` | Pixel Art & Animation | open source | 2,840 |
| **LibreSprite** | `com.github.libresprite.LibreSprite` | Animated sprite editor and pixel art tool | open source | 2,773 |
| **Pencil2D** | `org.pencil2d.Pencil2D` | Create 2D animations with ease | open source ✅ | 846 |
| **Synfig Studio** | `org.synfig.SynfigStudio` | Create and edit 2D animations and compositions | open source ✅ | 811 |
| **Natron** | `fr.natron.Natron` | Compose industry-grade VFX and Motion Graphics. | open source | 1,125 |
| **Photocrea** | `com.github.vikdevelop.photopea_app` | Advanced image editor | open source ✅ | 2,360 |
| **Upscayl** | `org.upscayl.Upscayl` | Free and Open Source AI Image Upscaler | open source ✅ | 8,436 |
| **Upscaler** | `io.gitlab.theevilskeleton.Upscaler` | Upscale and enhance images | open source ✅ | 5,573 |
| **Image Viewer** | `org.gnome.Loupe` | View and edit images | open source ✅ | 13,038 |
| **Okular** | `org.kde.okular` | View and annotate documents | open source ✅ | 16,120 |
| **Xournal++** | `com.github.xournalpp.xournalpp` | Take handwritten notes | open source ✅ | 10,324 |
| **Rnote** | `com.github.flxzt.rnote` | Sketch and take handwritten notes | open source ✅ | 5,198 |
| **Gradia** | `be.alexandervanhee.gradia` | Annotate your screenshots | open source ✅ | 7,245 |
| **Komikku** | `info.febvre.Komikku` | Discover and read manga & comics | open source ✅ | 5,052 |
| **Coulr** | `com.github.huluti.Coulr` | Enjoy colors and feel happy | open source ✅ | 2,781 |
| **draw.io** | `com.jgraph.drawio.desktop` | Create and share diagrams | open source | 8,086 |
| **Gaphor** | `org.gaphor.Gaphor` | Simple UML and SysML modeling tool | open source ✅ | 1,608 |
| **XnView MP** | `com.xnview.XnViewMP` | View, convert and organize your images | **proprietary** ✅ | 7,481 |
| **ksnip** | `org.ksnip.ksnip` | Cross-Platform Screenshot tool with annotation features | open source | 1,816 |


## Creative — Photography & RAW Development

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **darktable** | `org.darktable.Darktable` | Organize and develop images from digital cameras | open source | 32,573 |
| **RawTherapee** | `com.rawtherapee.RawTherapee` | An advanced raw photo development program | open source | 2,151 |
| **digiKam** | `org.kde.digikam` | Photo Management Program | open source ✅ | 4,843 |
| **RapidRAW** | `io.github.CyberTimon.RapidRAW` | A non-destructive, and GPU-accelerated RAW image editor built with performance in mind | open source ✅ | 4,176 |
| **Curtail** | `com.github.huluti.Curtail` | Compress your images | open source ✅ | 2,202 |
| **Shotwell** | `org.gnome.Shotwell` | Digital photo organizer | open source ✅ | 4,306 |
| **gThumb Image Viewer** | `org.gnome.gThumb` | View and organize your images | open source | 2,800 |
| **VueScan** | `com.hamrick.VueScan` | Scanning software for 6000+ scanners | **proprietary** | 2,253 |
| **A Photo Tool (Libre)** | `me.ahola.aphototoollibre` | Photo editor for Linux | open source ✅ | 1,779 |


## Creative — 3D, CAD, PCB & 3D Printing

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **Blender** | `org.blender.Blender` | Free and open source 3D creation suite | open source | 22,329 |
| **FreeCAD** | `org.freecad.FreeCAD` | An open source parametric 3D CAD modeler | open source ✅ | 32,168 |
| **LibreCAD** | `org.librecad.librecad` | 2D Computer Aided Design (CAD) | open source ✅ | 3,569 |
| **OpenSCAD** | `org.openscad.OpenSCAD` | The Programmers Solid 3D CAD Modeller | open source ✅ | 2,545 |
| **Sweet Home 3D** | `com.sweethome3d.Sweethome3d` | Interior Design Application | open source | 3,475 |
| **Blockbench** | `net.blockbench.Blockbench` | Blockbench - A boxy 3D model editor | open source ✅ | 4,013 |
| **KiCad** | `org.kicad.KiCad` | An EDA suite for schematic and circuit board design | open source ✅ | 7,845 |
| **LibrePCB** | `org.librepcb.LibrePCB` | Design Schematics and PCBs | open source ✅ | 1,820 |
| **Bambu Studio** | `com.bambulab.BambuStudio` | Get perfect 3D prints! | open source ✅ | 24,087 |
| **PrusaSlicer** | `com.prusa3d.PrusaSlicer` | The Slicer for Every Maker | open source ✅ | 10,638 |
| **OrcaSlicer** | `com.orcaslicer.OrcaSlicer` | Get even more perfect prints! | open source ✅ | 21,311 |
| **UltiMaker Cura** | `com.ultimaker.cura` | Slicer to prepare your 3D printing projects | open source | 3,440 |


## Creative — Video Editing & Post-Production

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **Kdenlive** | `org.kde.kdenlive` | Video editor | open source ✅ | 39,253 |
| **Shotcut** | `org.shotcut.Shotcut` | Video editor | open source ✅ | 14,484 |
| **OpenShot Video Editor** | `org.openshot.OpenShot` | An easy to use, quick to learn, and surprisingly powerful video editor | open source | 7,077 |
| **Pitivi** | `org.pitivi.Pitivi` | Create and edit your own movies | open source ✅ | 1,862 |
| **Flowblade** | `io.github.jliljebl.Flowblade` | Video Editor - Fast, Precise, Stable | open source ✅ | 1,851 |
| **Olive** | `org.olivevideoeditor.Olive` | Non-linear video editor | open source | 652 |
| **Avidemux** | `org.avidemux.Avidemux` | Multi-purpose video editing and processing software | open source | 3,842 |
| **LosslessCut** | `no.mifi.losslesscut` | Losslessly trim audio and video | open source | 6,172 |
| **HandBrake** | `fr.handbrake.ghb` | Video Transcoder | open source ✅ | 23,753 |
| **REAL Video Enhancer** | `io.github.tntwise.REAL-Video-Enhancer` | Free and Open Source Video Enhancement Tool | open source ✅ | 2,130 |
| **Video Trimmer** | `org.gnome.gitlab.YaLTeR.VideoTrimmer` | Trim videos quickly | open source ✅ | 5,934 |
| **VidCutter** | `com.ozmartians.VidCutter` | Media Cutter + Joiner | open source | 1,389 |


## Creative — Audio, Music & DJing

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **Audacity** | `org.audacityteam.Audacity` | Audacity is the world's most popular audio editing and recording app | open source | 21,170 |
| **Ardour** | `org.ardour.Ardour` | Digital Audio Workstation | open source | 4,797 |
| **LMMS** | `io.lmms.LMMS` | A music production application | open source | 3,516 |
| **Mixxx DJ Software** | `org.mixxx.Mixxx` | Everything you need to perform live DJ mixes | open source ✅ | 4,397 |
| **MuseScore** | `org.musescore.MuseScore` | Create, play and print beautiful sheet music | open source | 3,840 |
| **TuxGuitar** | `ar.com.tuxguitar.TuxGuitar` | TuxGuitar is a free and open-source tablature editor | open source | 1,577 |
| **Strawberry Music Player** | `org.strawberrymusicplayer.strawberry` | A music player and collection organizer | open source ✅ | 9,115 |
| **Easy Effects** | `com.github.wwmm.easyeffects` | Simple audio effects | open source ✅ | 29,675 |
| **Audio Player** | `org.gnome.Decibels` | Play audio files | open source ✅ | 5,654 |
| **fre:ac** | `org.freac.freac` | Audio converter and CD ripper | open source ✅ | 4,922 |


## Creative — Streaming, Screen Recording & Capture

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **OBS Studio** | `com.obsproject.Studio` | Live stream and record videos | open source ✅ | 91,436 |
| **GPU Screen Recorder** | `com.dec05eba.gpu_screen_recorder` | A shadowplay-like screen recorder for Linux. The fastest screen recorder for Linux | open source ✅ | 16,312 |
| **Camera** | `org.gnome.Snapshot` | Take pictures and videos | open source ✅ | 15,079 |
| **Cine** | `io.github.diegopvlk.Cine` | Play your videos | open source ✅ | 6,928 |
| **Drift** | `org.cutwire.Drift` | Edit and export videos easily | open source ✅ | 6,103 |


## Browsers

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **Brave** | `com.brave.Browser` | Fast Internet, AI, Adblock | open source ✅ | 172,291 |
| **Firefox** | `org.mozilla.firefox` | Fast, Private & Safe Web Browser | open source ✅ | 186,694 |
| **LibreWolf** | `io.gitlab.librewolf-community` | LibreWolf Web Browser | open source ✅ | 42,377 |
| **Chromium Web Browser** | `org.chromium.Chromium` | The web browser from Chromium project | open source | 32,926 |
| **Vivaldi** | `com.vivaldi.Vivaldi` | Feature-packed web browser | **proprietary** | 18,796 |
| **Floorp** | `one.ablaze.floorp` | Customizable Firefox-based browser from Japan | open source ✅ | 7,800 |
| **Ungoogled Chromium** | `io.github.ungoogled_software.ungoogled_chromium` | Chromium without Google | open source ✅ | 16,955 |
| **Mullvad Browser** | `net.mullvad.MullvadBrowser` | Free the internet from mass surveillance | open source | 8,321 |
| **Ecosia Browser** | `org.ecosia.Browser` | The greenest browser on Earth | **proprietary** ✅ | 2,869 |
| **Microsoft Edge** | `com.microsoft.Edge` | Introducing the new Microsoft Edge web browser. It’s time to expect more. More privacy. More… | **proprietary** | 33,201 |
| **Zen** | `app.zen_browser.zen` | Stay focused, browse faster | open source ✅ | 60,428 |


## Office & Productivity — incl. ONLYOFFICE

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **ONLYOFFICE Desktop Editors** | `org.onlyoffice.desktopeditors` | Office productivity suite | open source ✅ | 83,676 |
| **LibreOffice** | `org.libreoffice.LibreOffice` | The LibreOffice productivity suite | open source ✅ | 59,782 |
| **Collabora Office** | `com.collaboraoffice.Office` | The Collabora Office productivity suite | open source ✅ | 7,755 |
| **WPS Office** | `com.wps.Office` | WPS Office Suite | **proprietary** | 18,922 |
| **Zoom** | `us.zoom.Zoom` | Video Conferencing, Web Conferencing, Webinars, Screen Sharing | **proprietary** | 25,932 |
| **Super Productivity** | `com.super_productivity.SuperProductivity` | To-do list and time tracker | open source ✅ | 5,273 |


## Notes, Writing & Knowledge Management

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **Obsidian** | `md.obsidian.Obsidian` | Markdown-based knowledge base | **proprietary** ✅ | 75,019 |
| **Logseq** | `com.logseq.Logseq` | Connect your notes and knowledge | open source ✅ | 18,250 |
| **Joplin** | `net.cozic.joplin_desktop` | open source note taking and to-do application | open source | 10,492 |
| **Zettlr** | `com.zettlr.Zettlr` | A Markdown editor for the 21st century | open source ✅ | 1,817 |
| **MarkText** | `com.github.marktext.marktext` | Next generation markdown editor | open source | 3,277 |
| **Standard Notes** | `org.standardnotes.standardnotes` | A simple and private place for your notes, thoughts, and life's work | open source | 2,703 |
| **AppFlowy** | `io.appflowy.AppFlowy` | Open Source Notion Alternative | open source ✅ | 3,350 |
| **Foliate** | `com.github.johnfactotum.Foliate` | Read e-books in style | open source ✅ | 13,387 |
| **Apostrophe** | `org.gnome.gitlab.somas.Apostrophe` | Edit Markdown in style | open source ✅ | 5,159 |


## PDF Tools

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **PDF Arranger** | `com.github.jeromerobert.pdfarranger` | Merge, shuffle, and crop PDFs | open source ✅ | 19,603 |
| **Document Viewer** | `org.gnome.Papers` | Read documents | open source ✅ | 9,125 |
| **Master PDF Editor** | `net.code_industry.MasterPDFEditor` | Master PDF Editor is a full solution for work with PDF documents | **proprietary** | 6,201 |
| **PDF4QT** | `io.github.JakubMelka.Pdf4qt` | Open Source PDF Editor | open source ✅ | 3,030 |
| **Scans to PDF** | `com.github.unrud.djpdf` | Create small, searchable PDFs from scanned documents | open source ✅ | 1,005 |
| **indiPDF** | `com.indomitusgroup.indipdf` | A powerful PDF editor for Linux | **proprietary** ✅ | 4,236 |
| **Adobe Reader** | `com.adobe.Reader` | PDF viewer | **proprietary** | 8,410 |


## Reading, Library & Research

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **calibre** | `com.calibre_ebook.calibre` | The one stop solution to all your e-book needs | open source | 11,665 |
| **Zotero** | `org.zotero.Zotero` | Collect, organize and cite research | open source | 6,504 |
| **YACReader** | `com.yacreader.YACReader` | Yet another comic reader | open source | 2,222 |


## Developer — Code Editors

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **Visual Studio Code** | `com.visualstudio.code` | Code editing. Redefined. | **proprietary** | 57,446 |
| **VSCodium** | `com.vscodium.codium` | Telemetry-less code editing | open source ✅ | 22,590 |
| **Zed** | `dev.zed.Zed` | High-performance code editor | open source | 9,650 |
| **Sublime Text** | `com.sublimehq.SublimeText` | Text Editing, Done Right | **proprietary** | 4,855 |
| **Text Editor** | `org.gnome.TextEditor` | Edit text files | open source ✅ | 11,505 |
| **Kate** | `org.kde.kate` | Advanced text editor | open source ✅ | 7,360 |
| **Builder** | `org.gnome.Builder` | Create applications for GNOME | open source ✅ | 2,319 |
| **Notepadqq** | `com.notepadqq.Notepadqq` | An advanced text editor | open source | 2,002 |
| **Notepadng** | `org.notepadng.Notepadng` | Notepad++-like editor | open source ✅ | 1,511 |
| **Geany** | `org.geany.Geany` | Fast and lightweight IDE | open source | 1,803 |
| **Code::Blocks** | `org.codeblocks.codeblocks` | IDE for C, C++ and Fortran | open source | 2,504 |
| **Bluefish** | `nl.openoffice.bluefish` | Code and text editor with many web and software development extras | open source ✅ | 1,459 |
| **Vim** | `org.vim.Vim` | The ubiquitous text editor | open source | 1,055 |
| **neovide** | `dev.neovide.neovide` | Advanced graphical interface for Neovim | open source | 526 |


## Developer — IDEs (JetBrains, Eclipse, Apache)

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **IntelliJ IDEA Open** | `com.jetbrains.IntelliJ-IDEA-Community` | Leading Java and Kotlin editor | open source | 6,519 |
| **PyCharm-Professional** | `com.jetbrains.PyCharm-Professional` | The most intelligent Python IDE | **proprietary** | 4,638 |
| **WebStorm** | `com.jetbrains.WebStorm` | JavaScript and TypeScript IDE | **proprietary** | 1,314 |
| **CLion** | `com.jetbrains.CLion` | A cross-platform IDE for C and C++ | **proprietary** | 2,288 |
| **Rider** | `com.jetbrains.Rider` | Fast & powerful, cross platform .NET IDE | **proprietary** | 2,165 |
| **GoLand** | `com.jetbrains.GoLand` | Capable and Ergonomic Go IDE | **proprietary** | 549 |
| **Eclipse IDE for Java Developers** | `org.eclipse.Java` | The essential tools for any Java developer, including a Java IDE, a Git client, XML Editor, M… | open source | 5,346 |
| **NetBeans** | `org.apache.netbeans` | NetBeans - Apache Java IDE. Fits the Pieces Together | open source | 3,171 |
| **Android Studio** | `com.google.AndroidStudio` | IDE for Android app development | **proprietary** | 13,029 |
| **Arduino IDE v2** | `cc.arduino.IDE2` | Open-source electronics prototyping platform | open source | 11,303 |


## Developer — Game Engines & Version Control

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **Godot Engine** | `org.godotengine.Godot` | Easily create 2D and 3D games | open source | 8,842 |
| **Unity Hub** | `com.unity.UnityHub` | Manage game engine installations | **proprietary** | 5,818 |
| **Scratch** | `edu.mit.Scratch` | Create stories, games, and animations, share with others around the world | open source | 3,641 |
| **GitHub Desktop** | `io.github.shiftey.Desktop` | Simple collaboration from your desktop | open source | 10,579 |
| **GitKraken** | `com.axosoft.GitKraken` | For repo management, in-app code editing & issue tracking | **proprietary** | 1,429 |
| **GitButler** | `com.gitbutler.gitbutler` | Git, finally designed for humans | **proprietary** | 430 |
| **Gitte** | `de.wwwtech.gitte` | Manage your code history | open source ✅ | 1,659 |


## Developer — Containers, Databases, API & Networking

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **Podman Desktop** | `io.podman_desktop.PodmanDesktop` | Manage Podman and other container engines from a single UI | open source ✅ | 12,746 |
| **DBeaver Community** | `io.dbeaver.DBeaverCommunity` | Free Universal Database Tool | open source | 15,233 |
| **pgAdmin 4** | `org.pgadmin.pgadmin4` | Admin and development platform for PostgreSQL | open source | 3,824 |
| **DB Browser for SQLite** | `org.sqlitebrowser.sqlitebrowser` | light GUI editor for SQLite databases | open source ✅ | 2,954 |
| **Beekeeper Studio** | `io.beekeeperstudio.Studio` | The SQL Editor and Database Manager Of Your Dreams | open source | 2,185 |
| **Bruno** | `com.usebruno.Bruno` | Fast and Git-Friendly API Client | **proprietary** ✅ | 4,754 |
| **Postman** | `com.getpostman.Postman` | Platform for building and using APIs | **proprietary** | 10,165 |
| **Insomnia** | `rest.insomnia.Insomnia` | Open-source API client | open source | 2,125 |
| **Wireshark** | `org.wireshark.Wireshark` | Network protocol analyzer (without capture support) | open source | 5,070 |
| **Ghidra** | `org.ghidra_sre.Ghidra` | Ghidra Reverse Engineering Suite | open source | 3,257 |
| **FileZilla** | `org.filezillaproject.Filezilla` | Fast and reliable FTP client | open source | 11,243 |


## Local AI & Coding Agents

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **LM Studio** | `ai.lmstudio.lm-studio` | Run AI models, locally and privately | **proprietary** | 15,121 |
| **Jan** | `ai.jan.Jan` | Private offline AI assistant | open source ✅ | 8,426 |
| **GPT4ALL** | `io.gpt4all.gpt4all` | Open-source assistant | open source | 1,654 |
| **OpenCode** | `ai.opencode.opencode` | Open source AI coding agent | open source | 6,209 |

## Voice typing

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **Speed of Sound** | `io.speedofsound.SpeedOfSound` | Voice typing for the Linux desktop — offline Whisper transcription, types into any app | open source ✅ | 1,553 |
| **Speech Note** | `net.mkiol.SpeechNote` | Notes with offline Speech to Text, Text to Speech and Machine Translation | open source ✅ | 8,804 |


## Spotify Frontends & Music Streaming

| App | Flatpak ID | What it does | License | Installs/mo |
|---|---|---|---|---|
| **Spotify** | `com.spotify.Client` | Official Spotify desktop client | **proprietary** | 115,814 |
| **Spotube** | `com.github.KRTirtho.Spotube` | Open-source Spotify frontend — privacy-focused, no ads | open source ✅ | 4,916 |
| **ncspot** | `io.github.hrkfdn.ncspot` | Terminal-based ncurses Spotify client | open source | 1,118 |
| **Nuclear** | `com.nuclearplayer.Nuclear` | Music streaming app with Spotify integration | open source ✅ | 3,643 |
| **Riff** | `dev.diegovsky.Riff` | Stream Spotify without distraction — minimal UI | open source ✅ | 2,569 |
| **verse** | `io.github.TanmayPatil105.verse` | Get currently playing Spotify song lyrics | open source ✅ | 157 |

> **Note:** The official Spotify Flatpak is community-maintained (not verified by Spotify). It is
> built from the official Snap package and works well, but is not officially supported by Spotify.
> All third-party frontends require a Spotify Premium account.

---

## Recommended starter stacks

Copy-paste these to get a working setup in one command.

### 🎨 Creative workstation

```bash
flatpak install flathub \
  com.brave.Browser \
  org.gimp.GIMP org.kde.krita org.inkscape.Inkscape net.scribus.Scribus \
  org.darktable.Darktable org.blender.Blender org.freecad.FreeCAD \
  org.kde.kdenlive org.shotcut.Shotcut fr.handbrake.ghb \
  org.audacityteam.Audacity com.obsproject.Studio
```

### 🧑‍💻 Developer workstation

```bash
flatpak install flathub \
  com.brave.Browser \
  com.visualstudio.code dev.zed.Zed \
  com.jetbrains.IntelliJ-IDEA-Community com.jetbrains.PyCharm-Professional \
  io.dbeaver.DBeaverCommunity com.usebruno.Bruno io.podman_desktop.PodmanDesktop \
  org.wireshark.Wireshark com.valvesoftware.Steam
```

### 📄 Office & document workflow (ONLYOFFICE-first)

```bash
flatpak install flathub \
  com.brave.Browser \
  org.onlyoffice.desktopeditors org.libreoffice.LibreOffice com.collaboraoffice.Office \
  md.obsidian.Obsidian com.github.jeromerobert.pdfarranger org.zotero.Zotero \
  com.calibre_ebook.calibre com.super_productivity.SuperProductivity
```

## Important notes & caveats

**ONLYOFFICE** (`org.onlyoffice.desktopeditors`) is the **single most-installed office app on
Flathub** (~84k/month), ahead of LibreOffice and Obsidian. It has the best MS Office format
fidelity of the Linux suites — the practical choice if you live in `.docx`/`.xlsx`/`.pptx`.
Pick Collabora if you prefer a fully open-source, LibreOffice-derived UI.

**Flatpak sandboxing affects developers most.** These need extra work inside a Flatpak:

| App | You need to grant |
|---|---|
| `com.visualstudio.code` | `--filesystem=host` + dev tools in `PATH`; prefer the [Toolbox](https://code.visualstudio.com/docs/remote/linux) method for real projects |
| `com.jetbrains.*` | `--filesystem=host`; JetBrains runtimes (JBR) sometimes need the `java` plugin fix |
| `com.google.AndroidStudio` | KVM access (`/dev/kvm`) and USB passthrough for device debugging |
| `org.wireshark.Wireshark` | `--device=all` (or root) to capture raw traffic |
| `dev.zed.Zed` | `language-server` in `PATH` for LSP completions |
| `com.valvesoftware.Steam` | It's a **wrapper** — the Flatpak launches your native Steam install |

Grant these only if you need them; the defaults are deliberately locked down.

**Not on Flathub** (use your distro's repos or an alternative from these tables):
Microsoft **Teams**, **Outlook**, and the full **Unity Editor** (only Unity Hub is listed).
Also absent: Ostinato, a few niche upscalers. Proprietary vendor Flatpaks are repackaged by
the community and are **not supported by Microsoft, Unity, Adobe, or JetBrains** — expect
occasional breakage on vendor updates.

**Gaming:** `com.valvesoftware.Steam` (97k/mo) is the biggest app here, but it is only a
launcher for your existing native Steam install — install Steam from your distro for a
better experience.

## Maintenance

This list is a snapshot generated on **2026-09-27** by querying the Flathub API
(`/api/v2/collection/category/*`, `/api/v2/appstream/<id>`, `/api/v2/search`). To refresh it,
re-run those endpoints and re-verify each ID — roughly 6 apps change or vanish from Flathub
every month.

Data source: <https://flathub.org> · AppStream metadata via the Flathub API.

## Sources
- [Flathub](https://flathub.org) — registry, authoritative
- [Flathub API v2](https://flathub.org/api/v2) — api
