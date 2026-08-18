# Thermals

A minimal [Omarchy](https://omarchy.org/) bar widget showing CPU/GPU temperatures,
with a click panel for CPU/GPU temps and fan speeds.

![Thermals bar widget](preview.png)

![Thermals bar widget expanded](preview2.png)

- Bar shows live `CPU 48°  GPU 39°` (slow 10s poll)
- Click to open a panel with CPU temp, CPU fan, GPU temp, GPU fan (2s poll while open)
- One persistent collector process streams readings — no per-tick process spawning
- Reads `/sys/class/hwmon` directly (k10temp/zenpower/coretemp for CPU; amdgpu/nouveau/nvidia for GPU; ITE/Nuvoton super-IO chips for board fans)
- Works best with the `it87` driver on Gigabyte boards (`it87-dkms-git` from AUR, with `ignore_resource_conflict=1`)

## Install

```bash
omarchy plugin add https://github.com/ak127a/thermals.git --enable
```

That clones the plugin into `~/.config/omarchy/plugins/ak.thermals/`, validates
the manifest, and places the widget on the right side of the bar. Move it with:

```bash
omarchy bar move ak.thermals --section right
```

Update later with:

```bash
omarchy plugin update ak.thermals
```

## Remove

```bash
omarchy plugin remove ak.thermals
```

## Requirements

- No runtime dependencies beyond `bash` — the collector is a plain shell script reading sysfs
- Fan readings require a hwmon driver for your motherboard's Super I/O chip
  (e.g. `it87` or `nct6775`); otherwise fans show "n/a"
