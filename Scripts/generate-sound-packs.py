#!/usr/bin/env python3
import json
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 48000
SLOT = 0.16

KEY_NAMES = [
    "Escape", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
    "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20",
    "Backquote", "Digit1", "Digit2", "Digit3", "Digit4", "Digit5", "Digit6", "Digit7", "Digit8",
    "Digit9", "Digit0", "Minus", "Equal", "Backspace", "Tab", "KeyQ", "KeyW", "KeyE", "KeyR",
    "KeyT", "KeyY", "KeyU", "KeyI", "KeyO", "KeyP", "BracketLeft", "BracketRight", "Backslash",
    "CapsLock", "KeyA", "KeyS", "KeyD", "KeyF", "KeyG", "KeyH", "KeyJ", "KeyK", "KeyL",
    "Semicolon", "Quote", "Enter", "ShiftLeft", "KeyZ", "KeyX", "KeyC", "KeyV", "KeyB", "KeyN",
    "KeyM", "Comma", "Period", "Slash", "ShiftRight", "ControlLeft", "AltLeft", "MetaLeft",
    "Space", "MetaRight", "AltRight", "ControlRight", "Fn", "ContextMenu", "IntlBackslash",
    "IntlYen", "IntlRo", "Insert", "Home", "PageUp", "Delete", "End", "PageDown",
    "ArrowUp", "ArrowLeft", "ArrowDown", "ArrowRight", "NumLock", "NumpadEqual", "NumpadDivide",
    "NumpadMultiply", "Numpad7", "Numpad8", "Numpad9", "NumpadSubtract", "Numpad4", "Numpad5",
    "Numpad6", "NumpadAdd", "Numpad1", "Numpad2", "Numpad3", "NumpadEnter", "Numpad0",
    "NumpadDecimal",
]

LARGE = {"Space"}
MEDIUM = {"Enter", "NumpadEnter", "Backspace", "ShiftLeft", "ShiftRight", "CapsLock", "Tab", "Numpad0", "NumpadAdd"}


def onepole_lowpass(signal, cutoff):
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    out = np.zeros_like(signal)
    acc = 0.0
    for i, sample in enumerate(signal):
        acc += alpha * (sample - acc)
        out[i] = acc
    return out


def highpass(signal, cutoff):
    return signal - onepole_lowpass(signal, cutoff)


def bandnoise(rng, length, low, high):
    noise = rng.standard_normal(length)
    return onepole_lowpass(highpass(noise, low), high)


def modes(t, rng, freqs, decays, amps, jitter):
    out = np.zeros_like(t)
    for freq, decay, amp in zip(freqs, decays, amps):
        f = freq * (1.0 + rng.uniform(-jitter, jitter))
        phase = rng.uniform(0, 2 * np.pi)
        out += amp * np.sin(2 * np.pi * f * t + phase) * np.exp(-t / decay)
    return out


def impact(rng, length, at, freqs, decays, amps, noise_band, noise_amp, noise_decay, jitter=0.05):
    t = np.arange(length) / RATE
    out = np.zeros(length)
    start = int(at * RATE)
    local = t[: length - start]
    body = modes(local, rng, freqs, decays, amps, jitter)
    burst = bandnoise(rng, len(local), *noise_band) * noise_amp * np.exp(-local / noise_decay)
    attack = np.minimum(1.0, local / 0.0004)
    out[start:] = (body + burst) * attack
    return out


def thock_down(rng, size):
    length = int(0.13 * RATE)
    scale = {"small": 1.0, "medium": 0.82, "large": 0.66}[size]
    sustain = {"small": 1.0, "medium": 1.35, "large": 1.9}[size]
    hit = impact(
        rng, length, 0.0,
        [220 * scale, 480 * scale, 1150 * scale, 2600],
        [0.020 * sustain, 0.011 * sustain, 0.006, 0.0025],
        [0.9, 0.55, 0.28, 0.12],
        (300, 3200), 0.55, 0.004,
    )
    slide = bandnoise(rng, length, 1500, 6000) * 0.05 * np.exp(-np.arange(length) / RATE / 0.002)
    out = hit + slide
    if size != "small":
        rattle = impact(rng, length, rng.uniform(0.009, 0.014), [900, 2100], [0.004, 0.002], [0.12, 0.08], (1500, 6000), 0.18, 0.002)
        out += rattle
    return out


def thock_up(rng, size):
    length = int(0.09 * RATE)
    scale = {"small": 1.0, "medium": 0.85, "large": 0.7}[size]
    return impact(
        rng, length, 0.0,
        [340 * scale, 760 * scale, 1700, 3400],
        [0.010, 0.006, 0.0035, 0.0015],
        [0.45, 0.3, 0.16, 0.08],
        (600, 4500), 0.3, 0.0025,
    ) * 0.55


def tick_down(rng, size):
    length = int(0.12 * RATE)
    scale = {"small": 1.0, "medium": 0.88, "large": 0.75}[size]
    click = impact(
        rng, length, 0.0,
        [3900, 5600, 2700],
        [0.0022, 0.0014, 0.003],
        [0.75, 0.45, 0.3],
        (2500, 9000), 0.7, 0.0012, 0.04,
    )
    bottom = impact(
        rng, length, rng.uniform(0.012, 0.017),
        [420 * scale, 980 * scale, 2300],
        [0.012, 0.006, 0.0025],
        [0.5, 0.3, 0.14],
        (500, 4000), 0.35, 0.003,
    )
    return click + bottom


def tick_up(rng, size):
    length = int(0.08 * RATE)
    return impact(
        rng, length, 0.0,
        [3300, 4800, 1500],
        [0.0018, 0.0012, 0.004],
        [0.5, 0.3, 0.2],
        (2000, 8000), 0.45, 0.001, 0.05,
    ) * 0.6


def size_of(name):
    if name in LARGE:
        return "large"
    if name in MEDIUM:
        return "medium"
    return "small"


def build_pack(out_dir, pack_id, name, down_fn, up_fn, seed, variants=6):
    rng = np.random.default_rng(seed)
    slots = []
    sprite = []
    index = {}
    for size in ("small", "medium", "large"):
        count = variants if size == "small" else 3
        for v in range(count):
            down = down_fn(rng, size)
            up = up_fn(rng, size)
            index.setdefault(size, []).append((len(slots), len(slots) + 1))
            slots.append(down)
            slots.append(up)

    peak = max(np.max(np.abs(s)) for s in slots)
    slot_len = int(SLOT * RATE)
    for clip in slots:
        clip = clip / peak * 0.85
        padded = np.zeros(slot_len)
        padded[: min(slot_len, len(clip))] = clip[:slot_len]
        sprite.append(padded)
    audio = np.concatenate(sprite)

    def ms(slot, clip_len):
        start = slot * SLOT * 1000
        return [round(start, 3), round(start + clip_len / RATE * 1000, 3)]

    definitions = {}
    for i, key in enumerate(KEY_NAMES):
        size = size_of(key)
        options = index[size]
        down_slot, up_slot = options[(i * 7 + len(key)) % len(options)]
        definitions[key] = {
            "timing": [ms(down_slot, len(slots[down_slot])), ms(up_slot, len(slots[up_slot]))]
        }

    folder = out_dir / name.lower().replace(" ", "-")
    folder.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(audio, -1, 1) * 32767).astype("<i2")
    with wave.open(str(folder / "sound.wav"), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())

    config = {
        "config_version": "2",
        "id": pack_id,
        "name": name,
        "author": "Keyli",
        "description": "Synthesized by Keyli. No recorded or third-party audio.",
        "license": "Same license as Keyli",
        "definition_method": "single",
        "audio_file": "sound.wav",
        "definitions": definitions,
    }
    (folder / "config.json").write_text(json.dumps(config, indent=2) + "\n")


def main():
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "Support" / "SoundPacks"
    build_pack(out_dir, "keyli-slate-thock", "Slate Thock", thock_down, thock_up, seed=11)
    build_pack(out_dir, "keyli-quartz-tick", "Quartz Tick", tick_down, tick_up, seed=29)


if __name__ == "__main__":
    main()
