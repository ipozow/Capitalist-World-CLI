#include <iostream>
#include <string>

extern "C" void RenderPrompt(const char *prompt, const char *balance) {
    if (prompt == nullptr || balance == nullptr) {
        return;
    }

    std::string promptStr(prompt);
    std::string balanceStr(balance);

    // Clear current line and print prompt without newline
    std::cout << "\033[0G\033[2K" << promptStr;

    // Save cursor position
    std::cout << "\0337";

    // Move to next line, ensure blank line, then print balance line
    std::cout << '\n' << "\033[2K"    // ensure blank line stays empty
              << '\n' << "\033[2KSaldo: " << balanceStr;

    // Restore cursor to original prompt position and flush
    std::cout << "\0338" << std::flush;
}
