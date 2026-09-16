-- | Error reporting for the C kernels.
--
-- Kernels return an integer status. The wrappers turn a non-zero status into
-- a 'CoreError'. Pure wrappers throw it (like a partial function would),
-- 'Either'-returning wrappers hand it back.
module Quant.Core.Error
  ( CoreError (..)
  , Status (..)
  , statusFromCode
  , checkStatus
  , checkStatusEither
  , coreVersion
  ) where

import Control.Exception (Exception, throwIO)
import Foreign.C.String (peekCString)
import Foreign.C.Types (CInt)
import System.IO.Unsafe (unsafePerformIO)

import Quant.Core.FFI (c_qc_status_str, c_qc_version)

-- | Mirror of the C @qc_status@ enum.
data Status
  = Ok
  | InvalidArgument
  | Singular
  | NoConvergence
  | UnknownStatus Int
  deriving (Eq, Show)

statusFromCode :: CInt -> Status
statusFromCode 0 = Ok
statusFromCode 1 = InvalidArgument
statusFromCode 2 = Singular
statusFromCode 3 = NoConvergence
statusFromCode n = UnknownStatus (fromIntegral n)

data CoreError = CoreError
  { errStatus  :: Status
  , errKernel  :: String   -- ^ name of the C function that failed
  , errMessage :: String   -- ^ message from the C library
  }
  deriving (Eq, Show)

instance Exception CoreError

mkError :: String -> CInt -> IO CoreError
mkError kernel code = do
  msg <- peekCString =<< c_qc_status_str code
  pure (CoreError (statusFromCode code) kernel msg)

-- | Throw on non-zero status.
checkStatus :: String -> CInt -> IO ()
checkStatus _ 0 = pure ()
checkStatus kernel code = mkError kernel code >>= throwIO

-- | Return the error on non-zero status.
checkStatusEither :: String -> CInt -> IO (Either CoreError ())
checkStatusEither _ 0 = pure (Right ())
checkStatusEither kernel code = Left <$> mkError kernel code

-- | Version string of the linked C library.
coreVersion :: String
coreVersion = unsafePerformIO (peekCString =<< c_qc_version)
{-# NOINLINE coreVersion #-}
