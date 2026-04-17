void addit(double* a, double* b, int m,
           int n, int x)
{
  for (int i = m; i < m+n; i++) {
        a[i] = b[i] + a[i-x];
  }
}
