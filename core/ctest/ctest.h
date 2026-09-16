/* Minimal test harness: no dependencies, one binary, non-zero exit on failure. */
#ifndef CTEST_H
#define CTEST_H
#include <math.h>
#include <stdio.h>

extern int ct_failures;
extern int ct_checks;

#define CHECK(cond) do { ct_checks++; if (!(cond)) { ct_failures++; \
    fprintf(stderr, "  FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); } } while (0)

#define CHECK_EQ_INT(a, b) do { ct_checks++; long long _a = (long long)(a), _b = (long long)(b); \
    if (_a != _b) { ct_failures++; \
    fprintf(stderr, "  FAIL %s:%d: %s == %s (%lld vs %lld)\n", __FILE__, __LINE__, #a, #b, _a, _b); } } while (0)

#define CHECK_NEAR(a, b, tol) do { ct_checks++; double _a = (a), _b = (b); \
    if (!(fabs(_a - _b) <= (tol))) { ct_failures++; \
    fprintf(stderr, "  FAIL %s:%d: %s ~ %s (%.12g vs %.12g)\n", __FILE__, __LINE__, #a, #b, _a, _b); } } while (0)

#define CHECK_NAN(a) do { ct_checks++; if (!isnan(a)) { ct_failures++; \
    fprintf(stderr, "  FAIL %s:%d: expected NaN from %s\n", __FILE__, __LINE__, #a); } } while (0)

#define RUN(fn) do { printf("- %s\n", #fn); fn(); } while (0)

#endif
