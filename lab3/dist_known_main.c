#include <stdio.h>
#include <stdlib.h>

#define MYDIM 3

// For dist.c with -DKNOWN_TRIP_COUNT (2D array)
void dist(int n, int nd, float pt[][MYDIM], float dis[], float ptref[]);

int main() {
    int n = 1000;     // Number of points
    int nd = 3;       // Dimensions (3D points)

    // Allocate as 2D array
    float (*pt)[MYDIM] = (float (*)[MYDIM])malloc(n * sizeof(*pt));
    float *dis = (float*)malloc(n * sizeof(float));
    float ptref[3] = {0.0f, 0.0f, 0.0f};  // Reference point at origin

    // Initialize points
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < MYDIM; j++) {
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
