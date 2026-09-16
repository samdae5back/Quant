-- | Performance metrics on an equity curve. Cheap enough to stay in Haskell;
-- they also double as readable definitions of what each number means.
module Quant.Metrics
  ( Metrics (..)
  , metrics
  , totalReturn
  , cagr
  , annualizedVol
  , sharpe
  , maxDrawdown
  , periodsPerYear
  ) where

import qualified Data.Vector.Storable as VS

import qualified Quant.Core.Series as S

data Metrics = Metrics
  { mTotalReturn   :: Double
  , mCagr          :: Double
  , mAnnualizedVol :: Double
  , mSharpe        :: Double   -- ^ zero risk-free rate
  , mMaxDrawdown   :: Double   -- ^ negative number, e.g. -0.35
  , mAvgTurnover   :: Double   -- ^ mean per-bar turnover
  }
  deriving (Eq, Show)

-- | Trading days per year for daily bars.
periodsPerYear :: Double
periodsPerYear = 252

totalReturn :: VS.Vector Double -> Double
totalReturn eq
  | VS.length eq < 2 = 0
  | otherwise = VS.last eq / VS.head eq - 1

cagr :: VS.Vector Double -> Double
cagr eq
  | VS.length eq < 2 = 0
  | otherwise = (VS.last eq / VS.head eq) ** (periodsPerYear / years) - 1
  where years = fromIntegral (VS.length eq - 1)

finite :: VS.Vector Double -> VS.Vector Double
finite = VS.filter (not . isNaN)

annualizedVol :: VS.Vector Double -> Double
annualizedVol eq
  | VS.length rs < 2 = 0
  | otherwise = sqrt (var * periodsPerYear)
  where
    rs = finite (S.returns eq)
    mu = VS.sum rs / fromIntegral (VS.length rs)
    var = VS.sum (VS.map (\r -> (r - mu) ^ (2 :: Int)) rs) / fromIntegral (VS.length rs - 1)

sharpe :: VS.Vector Double -> Double
sharpe eq
  | VS.length rs < 2 || vol == 0 = 0
  | otherwise = (mu * periodsPerYear) / vol
  where
    rs = finite (S.returns eq)
    mu = VS.sum rs / fromIntegral (VS.length rs)
    vol = annualizedVol eq

maxDrawdown :: VS.Vector Double -> Double
maxDrawdown eq
  | VS.null eq = 0
  | otherwise = VS.minimum (VS.zipWith (\e peak -> e / peak - 1) eq (VS.scanl1 max eq))

metrics :: VS.Vector Double -> VS.Vector Double -> Metrics
metrics eq turnover = Metrics
  { mTotalReturn = totalReturn eq
  , mCagr = cagr eq
  , mAnnualizedVol = annualizedVol eq
  , mSharpe = sharpe eq
  , mMaxDrawdown = maxDrawdown eq
  , mAvgTurnover = if VS.null turnover then 0 else VS.sum turnover / fromIntegral (VS.length turnover)
  }
