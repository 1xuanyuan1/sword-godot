// Copyright (C) 2026 sword-godot contributors
// Uses the pinned SDLPal/AdPlug RIX player and MAME OPL core.
// SPDX-License-Identifier: GPL-3.0-or-later

#include <algorithm>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "adplug/mame_opls.h"
#include "adplug/rix.h"

class ToolEmuOpl final : public CEmuopl {
public:
    explicit ToolEmuOpl(int sample_rate)
        : CEmuopl(new MAMEOPL2(sample_rate), Copl::TYPE_OPL2) {}
};

static void write_u16(std::ofstream &stream, uint16_t value) {
    const char bytes[] = {static_cast<char>(value & 0xff), static_cast<char>((value >> 8) & 0xff)};
    stream.write(bytes, sizeof(bytes));
}

static void write_u32(std::ofstream &stream, uint32_t value) {
    const char bytes[] = {
        static_cast<char>(value & 0xff), static_cast<char>((value >> 8) & 0xff),
        static_cast<char>((value >> 16) & 0xff), static_cast<char>((value >> 24) & 0xff),
    };
    stream.write(bytes, sizeof(bytes));
}

static bool write_wav(const std::string &path, const std::vector<int16_t> &samples, int sample_rate) {
    std::ofstream output(path, std::ios::binary);
    if (!output) return false;
    const uint32_t data_size = static_cast<uint32_t>(samples.size() * sizeof(int16_t));
    output.write("RIFF", 4); write_u32(output, 36 + data_size); output.write("WAVE", 4);
    output.write("fmt ", 4); write_u32(output, 16); write_u16(output, 1); write_u16(output, 1);
    write_u32(output, sample_rate); write_u32(output, sample_rate * 2); write_u16(output, 2); write_u16(output, 16);
    output.write("data", 4); write_u32(output, data_size);
    output.write(reinterpret_cast<const char *>(samples.data()), data_size);
    return output.good();
}

int main(int argc, char **argv) {
    if (argc < 4) {
        std::cerr << "usage: rix_renderer MUS.MKF SONG_INDEX OUTPUT.wav [MAX_SECONDS]\n";
        return 2;
    }
    const std::string input_path = argv[1];
    const int song_index = std::stoi(argv[2]);
    const std::string output_path = argv[3];
    const int max_seconds = argc >= 5 ? std::max(1, std::stoi(argv[4])) : 300;
    constexpr int sample_rate = 44100;
    constexpr int refresh_rate = 70;
    const int samples_per_tick = sample_rate / refresh_rate;

    ToolEmuOpl opl(sample_rate);
    CrixPlayer player(&opl);
    CProvider_Filesystem provider;
    if (!player.load(input_path, provider)) {
        std::cerr << "failed to load RIX/MKF input\n";
        return 3;
    }
    if (song_index < 0 || song_index >= static_cast<int>(player.getsubsongs())) {
        std::cerr << "song index out of range: " << song_index << " / " << player.getsubsongs() << "\n";
        return 4;
    }
    player.rewind(song_index);
    std::vector<int16_t> samples;
    samples.reserve(static_cast<size_t>(sample_rate) * std::min(max_seconds, 60));
    std::vector<int16_t> tick(samples_per_tick);
    const int max_ticks = max_seconds * refresh_rate;
    for (int tick_index = 0; tick_index < max_ticks; ++tick_index) {
        if (!player.update()) break;
        opl.update(tick.data(), samples_per_tick);
        samples.insert(samples.end(), tick.begin(), tick.end());
    }
    if (samples.empty() || !write_wav(output_path, samples, sample_rate)) {
        std::cerr << "failed to render/write output\n";
        return 5;
    }
    std::cout << "{\"song\":" << song_index << ",\"sample_rate\":" << sample_rate
              << ",\"samples\":" << samples.size() << ",\"seconds\":"
              << (static_cast<double>(samples.size()) / sample_rate) << "}\n";
    return 0;
}

