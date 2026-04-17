#include <stdio.h>
#include <stdlib.h>

void addit(double* a, double* b, int m, int n, int x);

int main() {
  int n = 1024;
  int m = 10;
  int x = -5;  // x < 0, so a[i-x] looks backward (no forward dependency)

  double *a = (double*)malloc((m + n) * sizeof(double));
  double *b = (double*)malloc((m + n) * sizeof(double));

  // Initialize arrays
  for (int i = 0; i < m + n; i++) {
    a[i] = (double)i;
    b[i] = (double)(i * 2);
  }

  // Call the function
  addit(a, b, m, n, x);

  // Print some results
  printf("a[%d] = %f\n", m, a[m]);
  printf("a[%d] = %f\n", m+100, a[m+100]);
  printf("a[%d] = %f\n", m+n-1, a[m+n-1]);

  free(a);
  free(b);
  return 0;
}
