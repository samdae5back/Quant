-- | Trading calendar. Weekdays only for now; NYSE holidays are the obvious
-- next step and belong in a data file, not in code.
module Quant.Data.Calendar
  ( isWeekday
  , weekdaysBetween
  , monthEnds
  , weekEnds
  ) where

import Data.Time.Calendar (Day, DayOfWeek (..), dayOfWeek, toGregorian)
import qualified Data.Vector as V

isWeekday :: Day -> Bool
isWeekday d = dayOfWeek d `notElem` [Saturday, Sunday]

-- | Inclusive range of weekdays.
weekdaysBetween :: Day -> Day -> [Day]
weekdaysBetween from to = filter isWeekday [from .. to]

-- | Indices of the last observed date of each month within a date index.
monthEnds :: V.Vector Day -> [Int]
monthEnds ds = [ i | i <- [0 .. V.length ds - 1], isLast i ]
  where
    ym d = let (y, m, _) = toGregorian d in (y, m)
    isLast i = i + 1 >= V.length ds || ym (ds V.! i) /= ym (ds V.! (i + 1))

-- | Indices of the last observed date of each ISO week within a date index.
weekEnds :: V.Vector Day -> [Int]
weekEnds ds = [ i | i <- [0 .. V.length ds - 1], isLast i ]
  where
    isLast i = i + 1 >= V.length ds || dayOfWeek (ds V.! i) > dayOfWeek (ds V.! (i + 1))
             || (ds V.! (i + 1)) > addWeek (ds V.! i)
    addWeek d = toEnum (fromEnum d + 6)
