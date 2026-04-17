#include <omp.h>

void addit(double* a, double* b, int m,
           int n, int x)
{
  #pragma omp simd  // I know x<0
  for (int i = m; i < m+n; i++) {
        a[i] = b[i] + a[i-x];
  }
}
