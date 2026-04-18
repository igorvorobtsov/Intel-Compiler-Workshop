#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int compress(float *a, float *b, int na);

int main() {
    int na = 10000000;  // 10 million elements
    float *a = (float*)malloc(na * sizeof(float));
    float *b = (float*)malloc(na * sizeof(float));

    // Initialize: mix of positive and negative values (roughly 50% positive)
    srand(42);
    for (int i = 0; i < na; i++) {
        a[i] = (rand() % 1000) - 500.0f;  // Range: -500 to 499
    }

    // Warmup
    int nb = compress(a, b, na);

    // Benchmark
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    int num_runs = 10;
    for (int run = 0; run < num_runs; run++) {
        nb = compress(a, b, na);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);

    double elapsed = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
    double avg_time = elapsed / num_runs;

    printf("Input elements: %d\n", na);
    printf("Output elements: %d (%.1f%% positive)\n", nb, 100.0 * nb / na);
    printf("Average time: %.6f seconds\n", avg_time);
    printf("Throughput: %.2f million elements/sec\n", na / (avg_time * 1e6));
    printf("First positive values: %.1f, %.1f, %.1f\n", b[0], b[1], b[2]);

    free(a);
    free(b);
    return 0;
}
