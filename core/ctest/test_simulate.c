#include "ctest.h"
#include "qcore/simulate.h"

void test_simulate_buy_hold(void)
{
    /* one asset, fully invested, no cost: equity tracks price */
    double prices[] = {100, 110, 121};
    double weights[] = {1, 1, 1};
    double eq[3], to[3];
    CHECK_EQ_INT(qc_simulate(prices, weights, 3, 1, 0.0, eq, to), QC_OK);
    CHECK_NEAR(eq[0], 1.0, 1e-12); CHECK_NEAR(eq[1], 1.1, 1e-12); CHECK_NEAR(eq[2], 1.21, 1e-12);
    CHECK_NEAR(to[0], 1.0, 1e-12); CHECK_NEAR(to[1], 0.0, 1e-12);
}

void test_simulate_lookahead_guard(void)
{
    /* weight set on the last bar must not earn anything: nothing after it */
    double prices[] = {100, 100, 200};
    double weights[] = {0, 0, 1};
    double eq[3];
    CHECK_EQ_INT(qc_simulate(prices, weights, 3, 1, 0.0, eq, NULL), QC_OK);
    CHECK_NEAR(eq[2], 1.0, 1e-12);
    /* and a weight set at t=1 earns the t=1 -> t=2 move */
    double w2[] = {0, 1, 1};
    CHECK_EQ_INT(qc_simulate(prices, w2, 3, 1, 0.0, eq, NULL), QC_OK);
    CHECK_NEAR(eq[2], 2.0, 1e-12);
}

void test_simulate_costs_and_cash(void)
{
    double prices[] = {100, 100, 100};
    double weights[] = {0.5, 0.5, 0.5};              /* half cash */
    double eq[3], to[3];
    CHECK_EQ_INT(qc_simulate(prices, weights, 3, 1, 100.0, eq, to), QC_OK); /* 1% cost */
    CHECK_NEAR(eq[0], 1.0 - 0.5 * 0.01, 1e-12);
    CHECK_NEAR(eq[2], eq[0], 1e-12);                 /* flat prices, no further turnover */

    double pn[] = {100, NAN, 100, 100};              /* two assets, one has a gap */
    double wn[] = {0.5, 0.5, 0.5, 0.5};
    CHECK_EQ_INT(qc_simulate(pn, wn, 2, 2, 0.0, eq, NULL), QC_OK);
    CHECK_NEAR(eq[1], 1.0, 1e-12);
    CHECK_EQ_INT(qc_simulate(pn, wn, 2, 2, -1.0, eq, NULL), QC_EINVAL);
}
