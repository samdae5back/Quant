{-# LANGUAGE OverloadedStrings #-}
module TrendFilterSpec (spec) where

import Data.Time.Calendar (fromGregorian)
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
import Test.Hspec

import Quant.Backtest
import Quant.Core.Matrix (column)
import Quant.Strategies.TrendFilter
import Quant.Strategy
import Quant.Types

params :: TrendFilterParams
params = TrendFilterParams
  { tfRisky = Symbol "SPY"
  , tfSafe = Symbol "BIL"
  , tfSmaWindow = 3
  , tfMomentumWindow = 2
  , tfVolWindow = 2
  , tfTargetVol = 0.15
  , tfMaxWeight = 1.0
  , tfRebalance = EveryBar
  , tfCostBps = 0
  }

near :: Double -> Double -> Bool
near a b = abs (a - b) < 1e-9

spec :: Spec
spec = describe "Quant.Strategies.TrendFilter" $ do
  describe "trendFilterWeight" $ do
    it "is zero until every indicator is finite" $ do
      trendFilterWeight params 100 (0 / 0) 0.1 0.1 `shouldBe` 0
      trendFilterWeight params 100 90 (0 / 0) 0.1 `shouldBe` 0
      trendFilterWeight params 100 90 0.1 (0 / 0) `shouldBe` 0

    it "is zero when price is below the SMA or momentum is negative" $ do
      trendFilterWeight params 80 90 0.1 0.1 `shouldBe` 0
      trendFilterWeight params 100 90 (-0.05) 0.1 `shouldBe` 0

    it "scales by target over realized vol and caps at maxWeight" $ do
      trendFilterWeight params 100 90 0.1 0.30 `shouldSatisfy` near 0.5   -- 0.15 / 0.30
      trendFilterWeight params 100 90 0.1 0.05 `shouldBe` 1.0             -- capped
      trendFilterWeight params { tfMaxWeight = 0.8 } 100 90 0.1 0.05 `shouldBe` 0.8

  describe "trendFilter strategy" $ do
    it "holds the safe asset during warm-up and the risky asset in a steady uptrend" $ do
      let n = 12
          dates = V.fromList [fromGregorian 2024 1 d | d <- [1 .. n]]
          spy = VS.fromList [100 * 1.01 ^ i | i <- [0 .. n - 1 :: Int]]
          bil = VS.replicate n 100
          prices = either error id (mkPanel dates [("SPY", spy), ("BIL", bil)])
          w = stratWeights (trendFilter params) (StrategyInput prices Nothing Nothing)
          risky = VS.toList (column w 0)
          safe = VS.toList (column w 1)
      -- warm-up: sma needs 3 bars, momentum 2, vol needs 2 returns (3 prices)
      take 2 risky `shouldBe` [0, 0]
      -- steady 1% daily gain: returns are constant, realized vol is 0, so the
      -- rule falls back to the cap and is fully invested
      drop 2 risky `shouldSatisfy` all (== 1.0)
      zipWith (+) risky safe `shouldSatisfy` all (near 1.0)

    it "exits when price falls below its SMA" $ do
      let dates = V.fromList [fromGregorian 2024 1 d | d <- [1 .. 8]]
          spy = VS.fromList [100, 101, 102, 103, 104, 95, 90, 85]
          bil = VS.replicate 8 100
          prices = either error id (mkPanel dates [("SPY", spy), ("BIL", bil)])
          w = stratWeights (trendFilter params) (StrategyInput prices Nothing Nothing)
          risky = VS.toList (column w 0)
      risky !! 4 `shouldSatisfy` (> 0)      -- still trending at bar 4
      drop 6 risky `shouldBe` [0, 0]        -- below the 3-bar SMA from bar 6 on

    it "runs end to end through the backtest driver" $ do
      let n = 30
          dates = V.fromList [fromGregorian 2024 1 1 `addDaysI` i | i <- [0 .. n - 1]]
          spy = VS.fromList [100 * 1.005 ^ i | i <- [0 .. n - 1 :: Int]]
          bil = VS.replicate n 100
          prices = either error id (mkPanel dates [("SPY", spy), ("BIL", bil)])
      case runBacktest (trendFilter params) (StrategyInput prices Nothing Nothing) of
        Left e -> expectationFailure (show e)
        Right r -> VS.last (brEquity r) `shouldSatisfy` (> 1.0)
  where
    addDaysI d i = toEnum (fromEnum d + i)
