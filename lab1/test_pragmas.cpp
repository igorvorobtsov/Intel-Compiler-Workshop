int main(void) {
    float arr[1000];

    #pragma totallybogus           // pragma does NOT exist in ICC Classic, GCC, or ICX => causes warning
    #pragma simd                   // ICC Classic pragma; NOT supported by ICX => causes warning
    #pragma vector                 // is recognized and implemented by ICX
    for (int k=0; k<1000; k++) {
        arr[k] = 42.0;
    }

    return 0;
}
