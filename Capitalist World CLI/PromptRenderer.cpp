#include <iostream>
#include <string>

extern "C" void RenderPrompt(const char *prompt, const char *statusLine) {
    if (prompt == nullptr || statusLine == nullptr) {
        return;
    }

    std::string promptStr(prompt);
    std::string statusLineStr(statusLine);

    // Clear current line and print prompt without newline
    std::cout << "\033[0G\033[2K" << promptStr;

    // Save cursor position
    std::cout << "\0337";

    // Move to next line, ensure blank line, then print balance line
    std::cout << '\n' << "\033[2K"    // ensure blank line stays empty
              << '\n' << "\033[2K" << statusLineStr;

    // Restore cursor to original prompt position and flush
    std::cout << "\0338" << std::flush;
}
