{-# LANGUAGE OverloadedStrings #-}
-- | Daily price loaders. Stooq offers free daily OHLCV CSV downloads for US
-- tickers without a key; swap in Tiingo or a broker feed later by adding a
-- new URL builder, the CSV shape is handled by 'Quant.Data.Csv'.
module Quant.Data.Prices
  ( stooqCsvUrl
  , fetchStooq
  , parsePricesCsv
  ) where

import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import Network.HTTP.Client (Manager, httpLbs, parseRequest, responseBody, responseStatus)
import Network.HTTP.Types.Status (statusCode)

import Quant.Data.Csv (parseCloseCsv)
import Quant.Types

-- | Stooq wants lowercase tickers with a @.us@ suffix, e.g. @spy.us@.
stooqCsvUrl :: Symbol -> String
stooqCsvUrl (Symbol s) = "https://stooq.com/q/d/l/?s=" ++ T.unpack (T.toLower s) ++ ".us&i=d"

parsePricesCsv :: BL.ByteString -> Either String TimeSeries
parsePricesCsv = parseCloseCsv

fetchStooq :: Manager -> Symbol -> IO (Either String (BL.ByteString, TimeSeries))
fetchStooq mgr sym = do
  req <- parseRequest (stooqCsvUrl sym)
  resp <- httpLbs req mgr
  let code = statusCode (responseStatus resp)
      body = responseBody resp
  pure $ if code /= 200
    then Left ("Stooq " ++ T.unpack (unSymbol sym) ++ ": HTTP " ++ show code)
    else (\ts -> (body, ts)) <$> parsePricesCsv body
