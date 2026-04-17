// Outer Loop Vectorization Example
// Version 1: Compile without -DUSE_OMP_SIMD and without -DKNOWN_TRIP_COUNT
//            MYDIM=nd (variable), no pragma, inner loop vectorized
// Version 2: Compile with -DUSE_OMP_SIMD but without -DKNOWN_TRIP_COUNT
//            MYDIM=nd (variable), pragma active, outer loop vectorized
// Version 3: Compile with -DUSE_OMP_SIMD and -DKNOWN_TRIP_COUNT
//            MYDIM=3 (constant), pragma active, outer loop vectorized

#ifdef  KNOWN_TRIP_COUNT
#define MYDIM 3
#else                           // pt     input  vector of points
#define MYDIM nd                // ptref  input  reference point
#endif                          // dis    output vector of distances
#include <math.h>

void dist( int n, int nd, float pt[][MYDIM], float dis[], float ptref[]) {
/* calculate distance from data points to reference point */

#ifdef USE_OMP_SIMD
#pragma omp simd
#endif
    for (int ipt=0; ipt<n; ipt++) {
        float d = 0.;

        for (int j=0; j<MYDIM; j++) {
            float t = pt[ipt][j] - ptref[j];
            d+= t*t;
         }

        dis[ipt] = sqrtf(d);
    }
}
