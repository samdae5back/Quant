{-# LANGUAGE OverloadedStrings #-}
module BacktestSpec (spec) where

import Data.Time.Calendar (fromGregorian)
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
import Test.Hspec

import Quant.Backtest
import Quant.Core.Matrix (fromRows, toRows)
import Quant.Strategies.BuyHold
import Quant.Strategy
import Quant.Types

spec :: Spec
spec = describe "Quant.Backtest" $ do
  it "applySchedule holds weights between rebalance bars and is flat before the first" $ do
    let w = fromRows [[0.1], [0.2], [0.3], [0.4]]
        held = applySchedule [1, 3] w
    map VS.toList (toRows held) `shouldBe` [[0], [0.2], [0.2], [0.4]]

  it "buy-and-hold on one asset tracks the price ratio" $ do
    let dates = V.fromList [fromGregorian 2024 1 d | d <- [1 .. 4]]
        prices = either error id (mkPanel dates [("SPY", VS.fromList [100, 110, 99, 120])])
        strat = buyHold [Symbol "SPY"] (Bps 0)
    case runBacktest strat (StrategyInput prices Nothing Nothing) of
      Left e -> expectationFailure (show e)
      Right r -> do
        VS.toList (brEquity r) `shouldSatisfy` \eq -> and (zipWith (\a b -> abs (a - b) < 1e-12) eq [1, 1.1, 0.99, 1.2])
        VS.head (brTurnover r) `shouldBe` 1

  it "rejects a universe that does not match the panel" $ do
    let dates = V.fromList [fromGregorian 2024 1 1]
        prices = either error id (mkPanel dates [("SPY", VS.fromList [100])])
        strat = buyHold [Symbol "SPY", Symbol "BIL"] (Bps 0)
    either (const True) (const False) (runBacktest strat (StrategyInput prices Nothing Nothing)) `shouldBe` True
