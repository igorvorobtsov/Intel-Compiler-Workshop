#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

#ifdef KNOWN_TRIP_COUNT
#define MYDIM 3
#else
#define MYDIM nd
#endif

void dist(int n, int nd, float pt[][MYDIM], float dis[], float ptref[]);

// Get CPU information
void print_cpu_info() {
    FILE *fp = fopen("/proc/cpuinfo", "r");
    if (fp == NULL) {
        printf("CPU: Unable to detect\n");
        return;
    }

    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "model name", 10) == 0) {
            char *model = strchr(line, ':');
            if (model) {
                model += 2;  // Skip ": "
                // Remove trailing newline
                char *newline = strchr(model, '\n');
                if (newline) *newline = '\0';
                printf("CPU: %s\n", model);
                break;
            }
        }
    }
    fclose(fp);
}

// Timing utility
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

int main() {
    // Print CPU information
    print_cpu_info();
    printf("\n");

    int n = 100000000;  // 100 million points for robust timing
    int nd = 3;         // 3D points

    // Allocate arrays
    float (*pt)[nd] = (float (*)[nd])malloc(n * nd * sizeof(float));
    float *dis = (float*)malloc(n * sizeof(float));
    float ptref[3] = {1.0f, 2.0f, 3.0f};

    // Initialize points
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < nd; j++) {
            pt[i][j] = (float)(i + j * 0.1);
        }
    }

    // Warmup run
    dist(n, nd, pt, dis, ptref);

    // Benchmark: run multiple times and take average
    int num_runs = 10;
    double total_time = 0.0;

    for (int run = 0; run < num_runs; run++) {
        double start = get_time();
        dist(n, nd, pt, dis, ptref);
        double end = get_time();
        total_time += (end - start);
    }

    double avg_time = total_time / num_runs;
    double gflops = (n * 6.0) / (avg_time * 1e9);  // 6 FLOPs per point (3 sub, 3 mul, 1 add for sum, 1 sqrt)

    printf("Problem size: %d points (%.1f MB)\n", n, (n * nd * sizeof(float)) / (1024.0 * 1024.0));
    printf("Iterations: %d runs\n", num_runs);
    printf("Average time: %.6f seconds\n", avg_time);
    printf("Throughput: %.2f million points/sec\n", n / (avg_time * 1e6));
    printf("Performance: %.2f GFLOPS\n", gflops);
    printf("Verification - First: %.6f, Last: %.6f\n", dis[0], dis[n-1]);

    free(pt);
    free(dis);
    return 0;
}
