#include <stdio.h>
#include <stdlib.h>

// For dist.c without KNOWN_TRIP_COUNT: MYDIM becomes nd (variable)
// For dist.c with KNOWN_TRIP_COUNT: MYDIM becomes 3 (constant)
#ifdef KNOWN_TRIP_COUNT
#define MYDIM 3
#else
#define MYDIM nd
#endif

void dist(int n, int nd, float pt[][MYDIM], float dis[], float ptref[]);

int main() {
    int n = 1000;     // Number of points
    int nd = 3;       // Dimensions (3D points)

    // Allocate as 2D array with variable dimensions
    float (*pt)[nd] = (float (*)[nd])malloc(n * nd * sizeof(float));
    float *dis = (float*)malloc(n * sizeof(float));
    float ptref[3] = {0.0f, 0.0f, 0.0f};  // Reference point at origin

    // Initialize points
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < nd; j++) {
            pt[i][j] = (float)(i + j * 0.1);
        }
    }

    // Calculate distances
    dist(n, nd, pt, dis, ptref);

    // Print some results
    printf("Distance from point 0 to reference: %f\n", dis[0]);
    printf("Distance from point 100 to reference: %f\n", dis[100]);
    printf("Distance from point 999 to reference: %f\n", dis[999]);

    free(pt);
    free(dis);
    return 0;
}
