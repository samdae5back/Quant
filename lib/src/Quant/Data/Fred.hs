{-# LANGUAGE OverloadedStrings #-}
-- | FRED (Federal Reserve Economic Data) client.
--
-- Uses the public @fredgraph.csv@ endpoint, which needs no API key and
-- returns @DATE,VALUE@ rows with @.@ for missing observations.
--
-- Release dates: this endpoint gives observation dates only. Point-in-time
-- correctness for revised series (CPI, payrolls) needs ALFRED vintages,
-- which is the planned extension of this module. Until then the indicator
-- layer applies a fixed publication lag per series.
module Quant.Data.Fred
  ( fredCsvUrl
  , fetchFred
  , parseFredCsv
  ) where

import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import Network.HTTP.Client (Manager, httpLbs, parseRequest, responseBody, responseStatus)
import Network.HTTP.Types.Status (statusCode)

import Quant.Data.Csv (parseDateValueCsv)
import Quant.Types

fredCsvUrl :: SeriesId -> String
fredCsvUrl (SeriesId sid) = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=" ++ T.unpack sid

parseFredCsv :: BL.ByteString -> Either String TimeSeries
parseFredCsv = parseDateValueCsv

-- | Download one series. Network errors surface as exceptions from http-client;
-- a non-200 status or a parse failure is returned as 'Left'.
fetchFred :: Manager -> SeriesId -> IO (Either String (BL.ByteString, TimeSeries))
fetchFred mgr sid = do
  req <- parseRequest (fredCsvUrl sid)
  resp <- httpLbs req mgr
  let code = statusCode (responseStatus resp)
      body = responseBody resp
  pure $ if code /= 200
    then Left ("FRED " ++ T.unpack (unSeriesId sid) ++ ": HTTP " ++ show code)
    else (\ts -> (body, ts)) <$> parseFredCsv body
