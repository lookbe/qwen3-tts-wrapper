#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include "qwen.h"
#include "audio-io.h"

static std::string read_text_file(const char* path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {};
    }

    std::ostringstream ss;
    ss << file.rdbuf();
    std::string text = ss.str();
    while (!text.empty() && (text.back() == '\n' || text.back() == '\r')) {
        text.pop_back();
    }
    return text;
}

int design() {
    std::cout << "Qwen3 TTS DLL Test" << std::endl;
    std::cout << "Version: " << qt_version() << std::endl;

    // Model paths (update these to match your setup!)
    const char* model_path = "D:\\ai\\gguf\\tts\\qwen-talker-1.7b-voicedesign-Q4_K_M.gguf";
    const char* codec_path = "D:\\ai\\gguf\\tts\\qwen-tokenizer-12hz-Q4_K_M.gguf";
    const char* output_wav = "output_voice_design.wav";

    // Initialize parameters
    qt_init_params iparams;
    qt_init_default_params(&iparams);
    iparams.talker_path = model_path;
    iparams.codec_path  = codec_path;

    // Load model
    std::cout << "Loading model..." << std::endl;
    qt_context* q = qt_init(&iparams);
    if (!q) {
        std::cerr << "ERROR: Failed to load model: " << qt_last_error() << std::endl;
        return 1;
    }

    std::cout << "Model loaded successfully!" << std::endl;

    // TTS parameters for voice design
    qt_tts_params params;
    qt_tts_default_params(&params);
    params.text = "Hello, this is a voice design test using Qwen3 TTS!";
    params.lang = "English";
    params.instruct = "Female, young adult, friendly, warm tone";

    // Synthesize audio
    std::cout << "Synthesizing audio..." << std::endl;
    qt_audio audio = {};
    qt_status status = qt_synthesize(q, &params, &audio);
    if (status != QT_STATUS_OK) {
        std::cerr << "ERROR: Synthesis failed: " << qt_last_error() << std::endl;
        qt_free(q);
        return 1;
    }

    // Write WAV file
    std::cout << "Writing WAV file: " << output_wav << std::endl;
    if (!audio_write_wav(output_wav, audio.samples, audio.n_samples, audio.sample_rate, WAV_S16)) {
        std::cerr << "ERROR: Failed to write WAV file" << std::endl;
        qt_audio_free(&audio);
        qt_free(q);
        return 1;
    }

    // Cleanup
    qt_audio_free(&audio);
    qt_free(q);

    std::cout << "Success! WAV file created at " << output_wav << std::endl;
    return 0;
}

int clone() {
    std::cout << "Qwen3 TTS DLL Clone Test" << std::endl;
    std::cout << "Version: " << qt_version() << std::endl;

    // Clone mode uses the base talker model plus the shared codec.
    const char* model_path = "D:\\ai\\gguf\\tts\\qwen-talker-1.7b-base-Q4_K_M.gguf";
    const char* codec_path = "D:\\ai\\gguf\\tts\\qwen-tokenizer-12hz-Q4_K_M.gguf";
    const char* output_wav = "output_voice_design.wav";
    const char* ref_wav_path = "D:\\ai\\sample\\trump.wav";
    const char* ref_text_path = "D:\\ai\\sample\\trump.txt";

    std::string ref_text = read_text_file(ref_text_path);
    if (ref_text.empty()) {
        std::cerr << "ERROR: Failed to read transcript: " << ref_text_path << std::endl;
        return 1;
    }

    int ref_n_samples = 0;
    float* ref_audio = audio_read_mono(ref_wav_path, 24000, &ref_n_samples);
    if (!ref_audio) {
        std::cerr << "ERROR: Failed to read reference WAV: " << ref_wav_path << std::endl;
        return 1;
    }

    qt_init_params iparams;
    qt_init_default_params(&iparams);
    iparams.talker_path = model_path;
    iparams.codec_path = codec_path;

    std::cout << "Loading model..." << std::endl;
    qt_context* q = qt_init(&iparams);
    if (!q) {
        std::cerr << "ERROR: Failed to load model: " << qt_last_error() << std::endl;
        std::free(ref_audio);
        return 1;
    }

    std::cout << "Model loaded successfully!" << std::endl;

    qt_tts_params params;
    qt_tts_default_params(&params);
    params.text = "Hello, this is a clone test using Qwen3 TTS!";
    params.lang = "English";
    params.ref_audio_24k = ref_audio;
    params.ref_n_samples = ref_n_samples;
    params.ref_text = ref_text.c_str();

    std::cout << "Synthesizing clone audio..." << std::endl;
    qt_audio audio = {};
    qt_status status = qt_synthesize(q, &params, &audio);
    if (status != QT_STATUS_OK) {
        std::cerr << "ERROR: Synthesis failed: " << qt_last_error() << std::endl;
        qt_free(q);
        std::free(ref_audio);
        return 1;
    }

    std::cout << "Writing WAV file: " << output_wav << std::endl;
    if (!audio_write_wav(output_wav, audio.samples, audio.n_samples, audio.sample_rate, WAV_S16)) {
        std::cerr << "ERROR: Failed to write WAV file" << std::endl;
        qt_audio_free(&audio);
        qt_free(q);
        std::free(ref_audio);
        return 1;
    }

    qt_audio_free(&audio);
    qt_free(q);
    std::free(ref_audio);

    std::cout << "Success! WAV file created at " << output_wav << std::endl;
    return 0;
}

int main() {
    return clone();
}
