#include <stdio.h>
#include "ctest.h"

int ct_checks = 0;
int ct_failures = 0;

void test_diff_and_returns(void);
void test_rolling_mean(void);
void test_rolling_mean_with_nan(void);
void test_rolling_std_and_zscore(void);
void test_rolling_large_offset(void);
void test_rolling_std_cancellation(void);
void test_ewma(void);
void test_cholesky_inverse(void);
void test_eigen(void);
void test_covariance_and_ols(void);
void test_mahalanobis(void);
void test_simulate_buy_hold(void);
void test_simulate_lookahead_guard(void);
void test_simulate_costs_and_cash(void);

int main(void)
{
    RUN(test_diff_and_returns);
    RUN(test_rolling_mean);
    RUN(test_rolling_mean_with_nan);
    RUN(test_rolling_std_and_zscore);
    RUN(test_rolling_large_offset);
    RUN(test_rolling_std_cancellation);
    RUN(test_ewma);
    RUN(test_cholesky_inverse);
    RUN(test_eigen);
    RUN(test_covariance_and_ols);
    RUN(test_mahalanobis);
    RUN(test_simulate_buy_hold);
    RUN(test_simulate_lookahead_guard);
    RUN(test_simulate_costs_and_cash);
    printf("%d checks, %d failures\n", ct_checks, ct_failures);
    return ct_failures ? 1 : 0;
}
