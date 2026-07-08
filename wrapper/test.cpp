#include <iostream>
#include "qwen.h"
#include "audio-io.h"

int main() {
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
