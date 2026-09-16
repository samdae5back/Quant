#include "qcore/qcore.h"

const char *qc_status_str(int status)
{
    switch (status) {
    case QC_OK:        return "ok";
    case QC_EINVAL:    return "invalid argument";
    case QC_ESINGULAR: return "singular or non positive definite matrix";
    case QC_ENOCONV:   return "iteration did not converge";
    default:           return "unknown status";
    }
}

const char *qc_version(void)
{
    return "0.1.0";
}
