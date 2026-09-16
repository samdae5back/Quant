#include "ctest.h"
#include "qcore/series.h"

void test_diff_and_returns(void)
{
    double x[] = {100, 110, 99, 99};
    double out[4];
    CHECK_EQ_INT(qc_diff(x, 4, out), QC_OK);
    CHECK_NAN(out[0]); CHECK_NEAR(out[1], 10, 1e-12); CHECK_NEAR(out[2], -11, 1e-12);
    CHECK_EQ_INT(qc_returns(x, 4, out), QC_OK);
    CHECK_NEAR(out[1], 0.10, 1e-12); CHECK_NEAR(out[3], 0.0, 1e-12);
    CHECK_EQ_INT(qc_log_returns(x, 4, out), QC_OK);
    CHECK_NEAR(out[1], log(1.1), 1e-12);
    CHECK_EQ_INT(qc_diff(NULL, 4, out), QC_EINVAL);
}

void test_rolling_mean(void)
{
    double x[] = {1, 2, 3, 4, 5, 6};
    double out[6];
    CHECK_EQ_INT(qc_rolling_mean(x, 6, 3, out), QC_OK);
    CHECK_NAN(out[0]); CHECK_NAN(out[1]);
    CHECK_NEAR(out[2], 2.0, 1e-12); CHECK_NEAR(out[5], 5.0, 1e-12);
    CHECK_EQ_INT(qc_rolling_mean(x, 6, 7, out), QC_EINVAL);
    CHECK_EQ_INT(qc_rolling_mean(x, 6, 0, out), QC_EINVAL);
}

void test_rolling_mean_with_nan(void)
{
    double x[] = {1, 2, NAN, 4, 5, 6};
    double out[6];
    CHECK_EQ_INT(qc_rolling_mean(x, 6, 2, out), QC_OK);
    CHECK_NEAR(out[1], 1.5, 1e-12);
    CHECK_NAN(out[2]); CHECK_NAN(out[3]);          /* windows touching the NaN */
    CHECK_NEAR(out[4], 4.5, 1e-12); CHECK_NEAR(out[5], 5.5, 1e-12);
}

void test_rolling_std_and_zscore(void)
{
    double x[] = {2, 4, 4, 4, 5, 5, 7, 9};
    double out[8];
    CHECK_EQ_INT(qc_rolling_std(x, 8, 8, out), QC_OK);
    /* population std of this classic set is 2; sample std is 2 * sqrt(8/7) */
    CHECK_NEAR(out[7], 2.0 * sqrt(8.0 / 7.0), 1e-12);
    CHECK_EQ_INT(qc_rolling_std(x, 8, 1, out), QC_EINVAL);

    double c[] = {5, 5, 5, 5};
    CHECK_EQ_INT(qc_rolling_zscore(c, 4, 2, out), QC_OK);
    CHECK_NAN(out[1]);                              /* zero variance -> NaN, not inf */

    double y[] = {1, 2, 3, 4, 5};
    CHECK_EQ_INT(qc_rolling_zscore(y, 5, 3, out), QC_OK);
    CHECK_NEAR(out[4], 1.0, 1e-12);                 /* (5 - 4) / 1 */
}

void test_rolling_large_offset(void)
{
    /* large level with tiny variance: cancellation guard */
    double x[5];
    for (int i = 0; i < 5; i++) x[i] = 1e9 + (double)i;
    double out[5];
    CHECK_EQ_INT(qc_rolling_std(x, 5, 5, out), QC_OK);
    CHECK_NEAR(out[4], sqrt(2.5), 1e-6);
}

void test_ewma(void)
{
    double x[] = {1, NAN, 3};
    double out[3];
    CHECK_EQ_INT(qc_ewma(x, 3, 0.5, out), QC_OK);
    CHECK_NEAR(out[0], 1.0, 1e-12); CHECK_NEAR(out[1], 1.0, 1e-12); CHECK_NEAR(out[2], 2.0, 1e-12);
    CHECK_EQ_INT(qc_ewma(x, 3, 0.0, out), QC_EINVAL);
}
