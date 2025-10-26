#include <termios.h>
#include <unistd.h>

#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <mutex>
#include <string>

namespace {
std::mutex gMutex;
termios gOriginalTermios{};
bool gHasOriginalTermios = false;
bool gSupportsAnsi = false;
bool gPromptRendered = false;
bool gStatusLineActive = false;

constexpr const char *kClearLine = "\033[2K";
constexpr const char *kCursorUp = "\033[A";
constexpr const char *kCursorDown = "\033[B";
constexpr const char *kSaveCursor = "\0337";
constexpr const char *kRestoreCursor = "\0338";
}  // namespace

extern "C" int32_t ConfigureTerminalForPrompt() {
    std::lock_guard<std::mutex> lock(gMutex);

    bool supportsAnsi = isatty(STDOUT_FILENO) != 0;

    if (const char *forceAnsi = std::getenv("CAPITALIST_FORCE_ANSI")) {
        if (forceAnsi[0] != '\0') {
            supportsAnsi = true;
        }
    }

    if (const char *disableAnsi = std::getenv("CAPITALIST_DISABLE_ANSI")) {
        if (disableAnsi[0] != '\0') {
            supportsAnsi = false;
        }
    }

    gSupportsAnsi = supportsAnsi;

    bool configuredTerminal = false;
    if (isatty(STDIN_FILENO) != 0) {
        if (tcgetattr(STDIN_FILENO, &gOriginalTermios) != 0) {
            return -1;
        }

        termios modified = gOriginalTermios;
#if defined(ECHOCTL)
        // Hide control characters like ^C while leaving canonical input intact.
        modified.c_lflag &= ~ECHOCTL;
#endif
        if (tcsetattr(STDIN_FILENO, TCSANOW, &modified) != 0) {
            return -1;
        }

        configuredTerminal = true;
    }

    gHasOriginalTermios = configuredTerminal;
    return 0;
}

extern "C" void RestoreTerminalSettings() {
    std::lock_guard<std::mutex> lock(gMutex);

    if (!gHasOriginalTermios) {
        return;
    }

    tcsetattr(STDIN_FILENO, TCSANOW, &gOriginalTermios);
    gHasOriginalTermios = false;
}

static void renderPromptFancy(const std::string &prompt, const std::string &status) {
    std::cout << '\r' << kClearLine;
    std::cout << '\n' << kCursorUp;
    std::cout << '\r' << kClearLine << prompt << kSaveCursor;
    std::cout << '\n' << kClearLine << status;
    std::cout << kRestoreCursor << std::flush;
    gPromptRendered = true;
    gStatusLineActive = true;
}

static void renderPromptFallback(const std::string &prompt, const std::string &status) {
    std::cout << prompt << '\n' << status << '\n' << prompt << std::flush;
    gPromptRendered = true;
    gStatusLineActive = false;
}

extern "C" void RenderPrompt(const char *prompt, const char *statusLine) {
    std::lock_guard<std::mutex> lock(gMutex);

    const std::string promptText = prompt != nullptr ? prompt : "";
    const std::string statusText = statusLine != nullptr ? statusLine : "";

    if (gSupportsAnsi) {
        renderPromptFancy(promptText, statusText);
    } else {
        renderPromptFallback(promptText, statusText);
    }
}

extern "C" void UpdateStatusLine(const char *statusLine) {
    std::lock_guard<std::mutex> lock(gMutex);

    if (!gPromptRendered) {
        return;
    }

    const std::string statusText = statusLine != nullptr ? statusLine : "";

    if (!gSupportsAnsi || !gStatusLineActive) {
        return;
    }

    std::cout << kSaveCursor << '\r' << kCursorDown << kClearLine << statusText
              << kRestoreCursor << std::flush;
}
