#!/usr/bin/env python3
"""Testes do tema Luma que não precisam de sessão gráfica.

- Contraste WCAG 2.1 AA dos esquemas de cores (texto >= 4,5:1; foco/indicadores >= 3:1).
- Coerência dos pacotes Look-and-Feel: Id = diretório, defaults apontam para esquemas,
  ícones e wallpaper que o pacote realmente fornece ou que a base fornece.
Uso: python3 tests/unit/test_theme.py
"""
import configparser
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "themes"
SCHEMES = {p.stem: p for p in (THEME / "color-schemes").glob("*.colors")}
LNF = {p.name: p for p in (THEME / "look-and-feel").iterdir() if p.is_dir()}

TEXT_GROUPS = ["View", "Window", "Button", "Header", "Tooltip", "Complementary"]
TEXT_KEYS = ["ForegroundNormal", "ForegroundInactive", "ForegroundLink", "ForegroundVisited",
             "ForegroundNegative", "ForegroundNeutral", "ForegroundPositive", "ForegroundActive"]


def luminance(rgb):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(x) for x in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def rgb(s):
    return tuple(int(x) for x in s.split(","))


def read_colors(path):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    # A seção "[Colors:Header][Inactive]" é válida para o KConfig e para o configparser
    cp.read(path, encoding="utf-8")
    return cp


def read_defaults(path):
    """contents/defaults usa grupos aninhados KConfig: [arquivo][grupo]."""
    out, section = {}, None
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = re.fullmatch(r"((?:\[[^\]]+\])+)", line)
        if m:
            section = tuple(re.findall(r"\[([^\]]+)\]", m.group(1)))
            continue
        k, _, v = line.partition("=")
        out[(section, k)] = v
    return out


class TestContrastMath(unittest.TestCase):
    def test_reference_values(self):
        self.assertAlmostEqual(contrast((0, 0, 0), (255, 255, 255)), 21.0, places=2)
        self.assertAlmostEqual(contrast((255, 255, 255), (255, 255, 255)), 1.0, places=2)
        # #767676 sobre branco é o cinza mínimo AA conhecido (4,54:1)
        self.assertAlmostEqual(contrast((118, 118, 118), (255, 255, 255)), 4.54, places=2)


class TestSchemes(unittest.TestCase):
    def test_both_schemes_exist(self):
        self.assertEqual(set(SCHEMES), {"LumaLight", "LumaDark"})

    def test_text_contrast(self):
        for name, path in SCHEMES.items():
            cp = read_colors(path)
            for g in TEXT_GROUPS:
                sec = cp[f"Colors:{g}"]
                for bgkey in ("BackgroundNormal", "BackgroundAlternate"):
                    bg = rgb(sec[bgkey])
                    for k in TEXT_KEYS:
                        with self.subTest(scheme=name, group=g, fg=k, bg=bgkey):
                            self.assertGreaterEqual(contrast(rgb(sec[k]), bg), 4.5)

    def test_selection_contrast(self):
        for name, path in SCHEMES.items():
            sec = read_colors(path)["Colors:Selection"]
            bg = rgb(sec["BackgroundNormal"])
            for k in TEXT_KEYS:
                with self.subTest(scheme=name, fg=k):
                    self.assertGreaterEqual(contrast(rgb(sec[k]), bg), 4.5)

    def test_focus_indicator_visible(self):
        for name, path in SCHEMES.items():
            cp = read_colors(path)
            for g in ("View", "Window", "Button"):
                sec = cp[f"Colors:{g}"]
                with self.subTest(scheme=name, group=g):
                    self.assertGreaterEqual(contrast(rgb(sec["DecorationFocus"]), rgb(sec["BackgroundNormal"])), 3.0)

    def test_window_titles(self):
        for name, path in SCHEMES.items():
            wm = read_colors(path)["WM"]
            with self.subTest(scheme=name):
                self.assertGreaterEqual(contrast(rgb(wm["activeForeground"]), rgb(wm["activeBackground"])), 4.5)
                self.assertGreaterEqual(contrast(rgb(wm["inactiveForeground"]), rgb(wm["inactiveBackground"])), 4.5)

    def test_dark_is_dark_and_light_is_light(self):
        # Plasma escolhe images_dark/ do wallpaper e ícones pela luminância do fundo da janela
        light = read_colors(SCHEMES["LumaLight"])["Colors:Window"]["BackgroundNormal"]
        dark = read_colors(SCHEMES["LumaDark"])["Colors:Window"]["BackgroundNormal"]
        self.assertGreater(luminance(rgb(light)), 0.5)
        self.assertLess(luminance(rgb(dark)), 0.05)


class TestAurorae(unittest.TestCase):
    def test_theme_files(self):
        for t in ("Luma", "LumaEscuro"):
            d = THEME / "aurorae" / t
            meta = json.loads((d / "metadata.json").read_text(encoding="utf-8"))
            with self.subTest(theme=t):
                self.assertEqual(meta["KPackageStructure"], "KWin/Aurorae")
                self.assertEqual(meta["KPlugin"]["Id"], t)
                for f in ("decoration.svg", "close.svg", "minimize.svg", "maximize.svg", f"{t}rc"):
                    self.assertTrue((d / f).is_file(), f)
                svg = (d / "decoration.svg").read_text(encoding="utf-8")
                for part in ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright"):
                    self.assertIn(f'id="decoration-{part}"', svg)
                    self.assertIn(f'id="decoration-inactive-{part}"', svg)

    def test_button_colors_from_mockup(self):
        for kind, color in (("close", "#FD4D56"), ("minimize", "#FECB18"), ("maximize", "#2CD656")):
            svg = (THEME / "aurorae" / "Luma" / f"{kind}.svg").read_text(encoding="utf-8")
            with self.subTest(button=kind):
                self.assertIn(color, svg)
                for state in ("active", "hover", "pressed", "inactive"):
                    self.assertIn(f'id="{state}-center"', svg)


class TestControlCenter(unittest.TestCase):
    D = ROOT / "plasma" / "plasmoids" / "org.luma.controlcenter"

    def test_metadata(self):
        meta = json.loads((self.D / "metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(meta["KPackageStructure"], "Plasma/Applet")
        self.assertEqual(meta["KPlugin"]["Id"], "org.luma.controlcenter")
        self.assertEqual(meta["KPlugin"]["Name[pt_BR]"], "Central de Controle")

    def test_only_existing_plasma_apis(self):
        # Módulos QML conferidos nos applets do Plasma 6.3 (LUMA-OS); revalidar no Plasma 6.6 do Fedora 44 [H]
        allowed = {"QtQuick", "QtQuick.Layouts", "QtQuick.Controls", "org.kde.plasma.plasmoid",
                   "org.kde.plasma.core", "org.kde.kirigami", "org.kde.kcmutils",
                   "org.kde.plasma.networkmanagement", "org.kde.bluezqt", "org.kde.notificationmanager",
                   "org.kde.plasma.private.brightnesscontrolplugin", "org.kde.plasma.private.volume"}
        for f in (self.D / "contents/ui").glob("*.qml"):
            used = set(re.findall(r"^import ([A-Za-z.]+)", f.read_text(encoding="utf-8"), re.M))
            with self.subTest(arquivo=f.name):
                self.assertLessEqual(used, allowed)

    def test_four_tiles_and_two_sliders(self):
        qml = (self.D / "contents/ui/main.qml").read_text(encoding="utf-8")
        for name in ("tileWifi", "tileBluetooth", "tileDnd", "tileMirror"):
            self.assertIn(f'objectName: "{name}"', qml)
        self.assertEqual(qml.count("SliderRow {"), 3)  # brilho, brilho indisponível, volume


class TestLookAndFeel(unittest.TestCase):
    EXPECTED = {"org.luma.desktop": ("LumaLight", "Papirus", "Luma"), "org.luma.dark.desktop": ("LumaDark", "Papirus-Dark", "LumaEscuro")}

    def test_packages_present(self):
        self.assertEqual(set(LNF), set(self.EXPECTED))

    def test_metadata(self):
        for pid, path in LNF.items():
            meta = json.loads((path / "metadata.json").read_text(encoding="utf-8"))
            with self.subTest(pkg=pid):
                self.assertEqual(meta["KPackageStructure"], "Plasma/LookAndFeel")
                self.assertEqual(meta["KPlugin"]["Id"], pid)
                self.assertIn("Name[pt_BR]", meta["KPlugin"])
                self.assertEqual(meta["X-Plasma-APIVersion"], "2")

    def test_defaults_reference_real_assets(self):
        wallpaper_id = json.loads((ROOT / "wallpapers/Luma/metadata.json").read_text(encoding="utf-8"))["KPlugin"]["Id"]
        for pid, path in LNF.items():
            d = read_defaults(path / "contents/defaults")
            scheme, icons, deco = self.EXPECTED[pid]
            with self.subTest(pkg=pid):
                self.assertEqual(d[(("kdeglobals", "General"), "ColorScheme")], scheme)
                self.assertIn(scheme, SCHEMES)
                self.assertEqual(d[(("kdeglobals", "Icons"), "Theme")], icons)
                self.assertEqual(d[(("Wallpaper",), "Image")], wallpaper_id)
                self.assertEqual(d[(("kwinrc", "org.kde.kdecoration2"), "library")], "org.kde.kwin.aurorae")
                self.assertEqual(d[(("kwinrc", "org.kde.kdecoration2"), "theme")], f"__aurorae__svg__{deco}")
                self.assertTrue((THEME / "aurorae" / deco / "decoration.svg").is_file())
                self.assertEqual(d[(("kwinrc", "org.kde.kdecoration2"), "ButtonsOnLeft")], "XIA")

    def test_layout_uses_known_widgets(self):
        js = (ROOT / "plasma/layouts/luma-layout.js").read_text(encoding="utf-8")
        # Plasmoides presentes no Plasma 6.3 (Debian trixie, LUMA-OS); revalidar em /usr/share/plasma/plasmoids do Fedora 44 [H]
        known = {"org.kde.plasma.kickoff", "org.kde.plasma.icontasks", "org.kde.plasma.systemtray",
                 "org.kde.plasma.digitalclock", "org.kde.plasma.panelspacer", "org.kde.plasma.marginsseparator",
                 "org.kde.plasma.appmenu", "org.kde.plasma.trash", "org.luma.controlcenter"}
        used = set(re.findall(r'addWidget\("([^"]+)"\)', js))
        self.assertTrue(used)
        self.assertLessEqual(used, known)


if __name__ == "__main__":
    unittest.main(verbosity=1)
