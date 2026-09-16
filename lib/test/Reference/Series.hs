-- | Deliberately naive Haskell implementations of the series kernels. They
-- are slow and obvious on purpose: this is the oracle the C code is checked
-- against, and the readable definition of each transform.
module Reference.Series
  ( diffRef
  , returnsRef
  , rollingMeanRef
  , rollingStdRef
  , rollingZScoreRef
  ) where

import qualified Data.Vector.Storable as VS

nanD :: Double
nanD = 0 / 0

diffRef :: [Double] -> [Double]
diffRef xs = nanD : zipWith (-) (drop 1 xs) xs

returnsRef :: [Double] -> [Double]
returnsRef xs = nanD : zipWith (\a b -> if b == 0 then nanD else a / b - 1) (drop 1 xs) xs

windowsOf :: Int -> [Double] -> [Maybe [Double]]
windowsOf w xs = [ if i + 1 < w then Nothing else Just (take w (drop (i + 1 - w) xs)) | i <- [0 .. length xs - 1] ]

meanL :: [Double] -> Double
meanL ys = sum ys / fromIntegral (length ys)

stdL :: [Double] -> Double
stdL ys = sqrt (sum [ (y - m) ^ (2 :: Int) | y <- ys ] / fromIntegral (length ys - 1))
  where m = meanL ys

onWindow :: ([Double] -> Double) -> Int -> [Double] -> [Double]
onWindow f w xs = map (maybe nanD (\ys -> if any isNaN ys then nanD else f ys)) (windowsOf w xs)

rollingMeanRef :: Int -> [Double] -> [Double]
rollingMeanRef = onWindow meanL

rollingStdRef :: Int -> [Double] -> [Double]
rollingStdRef = onWindow stdL

rollingZScoreRef :: Int -> [Double] -> [Double]
rollingZScoreRef w xs = map (maybe nanD z) (windowsOf w xs)
  where
    z ys
      | any isNaN ys = nanD
      | sd == 0 = nanD
      | otherwise = (last ys - meanL ys) / sd
      where sd = stdL ys

_unused :: VS.Vector Double
_unused = VS.empty
