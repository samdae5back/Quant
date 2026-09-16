-- | As-of alignment of irregular series onto a common date index.
--
-- The rule that prevents look-ahead: on target date @d@ the value used is the
-- latest observation whose RELEASE date is @<= d@. A monthly figure for
-- August that is published mid-September must not appear on any date before
-- its publication.
module Quant.Data.Align
  ( asOf
  , asOfWithLag
  , lagRelease
  , alignPanel
  , commonDates
  ) where

import qualified Data.Text as T
import Data.Time.Calendar (Day, addDays)
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS

import Quant.Types

-- | Shift release dates forward by @n@ calendar days. Use for sources that
-- report observation dates only.
lagRelease :: Integer -> TimeSeries -> TimeSeries
lagRelease n ts = ts { tsRelease = V.map (addDays n) (tsRelease ts) }

-- | Forward-fill a series onto the target dates by release date. Dates before
-- the first release get NaN.
asOf :: V.Vector Day -> TimeSeries -> VS.Vector Double
asOf targets ts = VS.fromList (go 0 (-1) (V.toList targets))
  where
    n = tsLength ts
    rel = tsRelease ts
    val = tsValues ts
    -- j: index of latest observation released on or before the current target
    go _ _ [] = []
    go i j (d : ds) =
      let j' = advance j
          advance k
            | k + 1 < n && rel V.! (k + 1) <= d = advance (k + 1)
            | otherwise = k
          v = if j' < 0 then nan else val VS.! j'
      in v : go (i + 1 :: Int) j' ds

-- | 'asOf' after applying a release lag.
asOfWithLag :: Integer -> V.Vector Day -> TimeSeries -> VS.Vector Double
asOfWithLag n targets = asOf targets . lagRelease n

-- | Align named series onto one date index into a panel.
alignPanel :: V.Vector Day -> [(T.Text, TimeSeries)] -> Either String Panel
alignPanel dates named = mkPanel dates [ (name, asOf dates ts) | (name, ts) <- named ]

-- | Dates present in the first series and no earlier than the first date of
-- every other series. Handy for using price dates as the master index.
commonDates :: [TimeSeries] -> V.Vector Day
commonDates [] = V.empty
commonDates (master : others) = V.filter (\d -> all (\o -> V.length (tsDates o) > 0 && d >= V.head (tsDates o)) others) (tsDates master)
