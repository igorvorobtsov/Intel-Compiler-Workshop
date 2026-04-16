#include <iostream>

int main() {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
    int X;
#pragma clang diagnostic pop

    int Y;  // This should still trigger a warning
    std::cout << "Hello World!";
    return 0;
}
