{-# LANGUAGE OverloadedStrings #-}
-- | Write backtest output under a run directory: an equity CSV that notebooks
-- can plot, and a summary JSON with the metrics.
module Quant.Report
  ( writeRun
  , metricsJson
  ) where

import Data.Aeson (Value, object, (.=))
import qualified Data.Aeson.Encode.Pretty as Pretty
import qualified Data.ByteString.Lazy.Char8 as BLC
import qualified Data.Text as T
import Data.Time.Format (defaultTimeLocale, formatTime)
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

import Quant.Backtest (BacktestResult (..))
import Quant.Metrics

metricsJson :: T.Text -> Metrics -> Value
metricsJson name m = object
  [ "strategy" .= name
  , "totalReturn" .= mTotalReturn m
  , "cagr" .= mCagr m
  , "annualizedVol" .= mAnnualizedVol m
  , "sharpe" .= mSharpe m
  , "maxDrawdown" .= mMaxDrawdown m
  , "avgTurnover" .= mAvgTurnover m
  ]

-- | Writes @equity.csv@ and @summary.json@ into @dir@, creating it if needed.
writeRun :: FilePath -> BacktestResult -> Metrics -> IO ()
writeRun dir r m = do
  createDirectoryIfMissing True dir
  let rowsCsv =
        [ formatTime defaultTimeLocale "%Y-%m-%d" d ++ "," ++ show e ++ "," ++ show t
        | (d, e, t) <- zip3 (V.toList (brDates r)) (VS.toList (brEquity r)) (VS.toList (brTurnover r)) ]
  BLC.writeFile (dir </> "equity.csv") (BLC.pack (unlines ("date,equity,turnover" : rowsCsv)))
  BLC.writeFile (dir </> "summary.json") (Pretty.encodePretty (metricsJson (brStrategy r) m))
