#include "ctest.h"
#include "qcore/linalg.h"
#include "qcore/stats.h"
#include "qcore/regime.h"

void test_cholesky_inverse(void)
{
    double a[] = {4, 2, 2, 3};
    double inv[4];
    CHECK_EQ_INT(qc_sym_inverse(a, 2, inv), QC_OK);
    /* inverse of [[4,2],[2,3]] = 1/8 * [[3,-2],[-2,4]] */
    CHECK_NEAR(inv[0], 3.0 / 8.0, 1e-12); CHECK_NEAR(inv[1], -2.0 / 8.0, 1e-12);
    CHECK_NEAR(inv[3], 4.0 / 8.0, 1e-12);
    double bad[] = {1, 2, 2, 1};                     /* indefinite */
    CHECK_EQ_INT(qc_sym_inverse(bad, 2, inv), QC_ESINGULAR);
}

void test_eigen(void)
{
    double a[] = {2, 1, 1, 2};
    double evals[2], evecs[4];
    CHECK_EQ_INT(qc_sym_eigen(a, 2, evals, evecs, 0), QC_OK);
    CHECK_NEAR(evals[0], 3.0, 1e-10); CHECK_NEAR(evals[1], 1.0, 1e-10);
    /* first eigenvector is (1,1)/sqrt2 up to sign */
    CHECK_NEAR(fabs(evecs[0 * 2 + 0]), 1.0 / sqrt(2.0), 1e-10);
    CHECK_NEAR(fabs(evecs[1 * 2 + 0]), 1.0 / sqrt(2.0), 1e-10);
    double ar;
    CHECK_EQ_INT(qc_absorption_ratio(evals, 2, 1, &ar), QC_OK);
    CHECK_NEAR(ar, 0.75, 1e-12);
}

void test_covariance_and_ols(void)
{
    /* two perfectly linearly related columns plus a NaN row that must be dropped */
    double panel[] = {1, 2,  2, 4,  3, 6,  NAN, 1,  4, 8};
    double cov[4];
    CHECK_EQ_INT(qc_covariance(panel, 5, 2, cov), QC_OK);
    CHECK_NEAR(cov[0], 5.0 / 3.0, 1e-12);            /* var of 1,2,3,4 */
    CHECK_NEAR(cov[1], 10.0 / 3.0, 1e-12);
    CHECK_NEAR(cov[3], 20.0 / 3.0, 1e-12);

    double X[] = {1, 2, 3, 4};
    double y[] = {3, 5, 7, 9};                       /* y = 2x + 1 */
    double beta[2], rv;
    CHECK_EQ_INT(qc_ols(X, y, 4, 1, 1, beta, &rv), QC_OK);
    CHECK_NEAR(beta[0], 2.0, 1e-10); CHECK_NEAR(beta[1], 1.0, 1e-10);
    CHECK_NEAR(rv, 0.0, 1e-18);
}

void test_mahalanobis(void)
{
    double mu[] = {0, 0};
    double cov_inv[] = {1, 0, 0, 0.25};              /* variances 1 and 4 */
    double x[] = {1, 2};
    double d;
    CHECK_EQ_INT(qc_mahalanobis(x, mu, cov_inv, 2, &d), QC_OK);
    CHECK_NEAR(d, sqrt(2.0), 1e-12);
    double xn[] = {NAN, 2};
    CHECK_EQ_INT(qc_mahalanobis(xn, mu, cov_inv, 2, &d), QC_OK);
    CHECK_NAN(d);
}
