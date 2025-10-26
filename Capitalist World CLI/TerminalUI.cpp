#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>

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
bool gPromptSuspended = false;

constexpr const char *kClearLine = "\033[2K";
constexpr const char *kSaveCursorLegacy = "\0337";
constexpr const char *kRestoreCursorLegacy = "\0338";
constexpr const char *kSaveCursorAnsi = "\033[s";
constexpr const char *kRestoreCursorAnsi = "\033[u";
}  // namespace

static bool terminalRows(int &rows);
static void moveCursor(int row, int column);
static void saveCursorPosition();
static void restoreCursorPosition();

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

extern "C" void SuspendPromptUpdates() {
    std::lock_guard<std::mutex> lock(gMutex);

    if (!gSupportsAnsi) {
        return;
    }

    if (gPromptRendered) {
        int rows = 0;
        if (terminalRows(rows) && rows >= 4) {
            const int promptRow = rows - 3;
            const int statusRow = rows - 2;
            const int paddingRow = rows - 1;
            const int bottomRow = rows;

            moveCursor(bottomRow, 1);
            std::cout << kClearLine;

            moveCursor(paddingRow, 1);
            std::cout << kClearLine;

            moveCursor(statusRow, 1);
            std::cout << kClearLine;

            moveCursor(promptRow, 1);
            std::cout << kClearLine;

            moveCursor(bottomRow, 1);
            std::cout << std::flush;
        } else {
            std::cout << '\r' << kClearLine << std::endl;
        }
    }

    gPromptSuspended = true;
    gStatusLineActive = false;
    gPromptRendered = false;
}

extern "C" void ResumePromptUpdates() {
    std::lock_guard<std::mutex> lock(gMutex);

    gPromptSuspended = false;
}

static void saveCursorPosition() {
    std::cout << kSaveCursorLegacy << kSaveCursorAnsi;
}

static void restoreCursorPosition() {
    std::cout << kRestoreCursorLegacy << kRestoreCursorAnsi;
}

static bool terminalRows(int &rows) {
    winsize ws{};
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) != 0) {
        return false;
    }
    if (ws.ws_row <= 0) {
        return false;
    }
    rows = ws.ws_row;
    return true;
}

static void moveCursor(int row, int column) {
    if (row < 1) {
        row = 1;
    }
    if (column < 1) {
        column = 1;
    }
    std::cout << "\033[" << row << ';' << column << 'H';
}

static void renderPromptFallback(const std::string &prompt, const std::string &status) {
    std::cout << '\r' << kClearLine << prompt << '\n'
              << kClearLine << status << std::flush;
    gPromptRendered = true;
    gStatusLineActive = false;
    gPromptSuspended = false;
}

static void renderPromptFancy(const std::string &prompt, const std::string &status) {
    int rows = 0;
    if (!terminalRows(rows) || rows < 4) {
        renderPromptFallback(prompt, status);
        return;
    }

    const int promptRow = rows - 3;
    const int statusRow = rows - 2;
    const int paddingRow = rows - 1;
    const int bottomRow = rows;
    if (promptRow < 1) {
        renderPromptFallback(prompt, status);
        return;
    }

    moveCursor(bottomRow, 1);
    std::cout << kClearLine;

    moveCursor(paddingRow, 1);
    std::cout << kClearLine;

    moveCursor(statusRow, 1);
    std::cout << kClearLine << status;

    moveCursor(promptRow, 1);
    std::cout << kClearLine << prompt;

    moveCursor(promptRow, static_cast<int>(prompt.size()) + 1);
    std::cout << std::flush;

    gPromptRendered = true;
    gStatusLineActive = true;
    gPromptSuspended = false;
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

    if (!gSupportsAnsi || !gStatusLineActive || gPromptSuspended) {
        return;
    }

    int rows = 0;
    if (!terminalRows(rows) || rows < 3) {
        saveCursorPosition();
        std::cout << '\r' << kClearLine << statusText;
        restoreCursorPosition();
        std::cout << std::flush;
        return;
    }

    const int statusRow = rows - 2;
    if (statusRow < 1) {
        saveCursorPosition();
        std::cout << '\r' << kClearLine << statusText;
        restoreCursorPosition();
        std::cout << std::flush;
        return;
    }

    saveCursorPosition();
    moveCursor(statusRow, 1);
    std::cout << kClearLine << statusText;
    restoreCursorPosition();
    std::cout << std::flush;
}
