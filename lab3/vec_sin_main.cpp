#include <cstdio>
#include <cstdlib>

// Declaration only - definition is in vec_sin_fixed.cpp
void foo (float * theta, float * sth);

int main() {
  float *theta = (float*)std::malloc(512 * sizeof(float));
  float *sth = (float*)std::malloc(512 * sizeof(float));

  // Initialize input array
  for (int i = 0; i < 512; i++) {
    theta[i] = i * 0.01f;
  }

  // Call the vectorized function
  foo(theta, sth);

  // Print a few results
  std::printf("sth[0] = %f\n", sth[0]);
  std::printf("sth[100] = %f\n", sth[100]);
  std::printf("sth[511] = %f\n", sth[511]);

  std::free(theta);
  std::free(sth);
  return 0;
}
