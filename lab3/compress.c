// Compress Loop Pattern - Special Idiom
// Filters positive values from array a into array b
//
// This pattern is recognized by the compiler and can be vectorized
// using AVX-512's vcompressps instruction, but not with AVX2

int compress(float *a, float *b, int na)
{
    int nb = 0;
    for (int ia = 0; ia < na; ia++)
    {
        if (a[ia] > 0.f)
            b[nb++] = a[ia];
    }

    return nb;
}
