{-# LANGUAGE OverloadedStrings #-}
-- | CSV helpers shared by the data loaders. Two shapes are supported:
-- a two-column @date,value@ file (FRED style, missing values as @.@) and a
-- generic OHLCV file from which the adjusted or plain close is taken.
module Quant.Data.Csv
  ( parseDateValueCsv
  , parseCloseCsv
  , renderDateValueCsv
  , renderPanelCsv
  , parseDay
  ) where

import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BLC
import qualified Data.Csv as Csv
import Data.List (intercalate)
import qualified Data.Text as T
import Data.Time.Calendar (Day)
import Data.Time.Format (defaultTimeLocale, formatTime, parseTimeM)
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
import Text.Read (readMaybe)

import Quant.Core.Matrix (rows, (!), cols)
import Quant.Types (Panel (..), TimeSeries (..), mkTimeSeries)

parseDay :: T.Text -> Maybe Day
parseDay = parseTimeM True defaultTimeLocale "%Y-%m-%d" . T.unpack

-- | A missing cell (FRED writes @.@) is not an observation: the row is dropped
-- so that the as-of join forward-fills across it instead of poisoning a
-- rolling window with NaN.
parseValue :: T.Text -> Maybe Double
parseValue t = case readMaybe (T.unpack (T.strip t)) of
  Just v | not (isNaN v) -> Just v
  _ -> Nothing

-- | Parse @date,value@ rows (header optional, detected by a non-date first cell).
parseDateValueCsv :: BL.ByteString -> Either String TimeSeries
parseDateValueCsv bs = do
  recs <- Csv.decode Csv.NoHeader bs :: Either String (V.Vector (V.Vector T.Text))
  let body = V.toList (V.filter (\r -> V.length r >= 2) recs)
      rowsParsed = [ (d, v) | r <- body, Just d <- [parseDay (r V.! 0)], Just v <- [parseValue (r V.! 1)] ]
  mkTimeSeries rowsParsed

-- | Parse an OHLCV file with a header row and take the close. Prefers a column
-- named @adj_close@ or @Adj Close@, falls back to @close@ or @Close@.
parseCloseCsv :: BL.ByteString -> Either String TimeSeries
parseCloseCsv bs = do
  recs <- Csv.decode Csv.NoHeader bs :: Either String (V.Vector (V.Vector T.Text))
  (hdr, body) <- case V.toList recs of
    [] -> Left "parseCloseCsv: empty file"
    (h : rest) -> Right (V.toList h, rest)
  let indexOf cands = case [ i | (i, name) <- zip [0 :: Int ..] hdr, name `elem` cands ] of
        (i : _) -> Right i
        [] -> Left ("parseCloseCsv: none of " ++ show cands ++ " among " ++ show hdr)
  dateIx <- indexOf ["date", "Date", "DATE", "timestamp"]
  closeIx <- indexOf ["adj_close", "Adj Close", "adjClose", "close", "Close", "CLOSE"]
  let rowsParsed =
        [ (d, v)
        | r <- body
        , V.length r > max dateIx closeIx
        , Just d <- [parseDay (r V.! dateIx)]
        , Just v <- [parseValue (r V.! closeIx)]
        ]
  mkTimeSeries rowsParsed

renderDay :: Day -> String
renderDay = formatTime defaultTimeLocale "%Y-%m-%d"

renderDateValueCsv :: TimeSeries -> BL.ByteString
renderDateValueCsv ts = BLC.pack . unlines $
  "date,value" : [ renderDay d ++ "," ++ show v | (d, v) <- zip (V.toList (tsDates ts)) (VS.toList (tsValues ts)) ]

renderPanelCsv :: Panel -> BL.ByteString
renderPanelCsv p = BLC.pack . unlines $ header : body
  where
    m = pMatrix p
    header = intercalate "," ("date" : map T.unpack (V.toList (pNames p)))
    body = [ intercalate "," (renderDay d : [ show (m ! (i, j)) | j <- [0 .. cols m - 1] ])
           | (i, d) <- zip [0 .. rows m - 1] (V.toList (pDates p)) ]
