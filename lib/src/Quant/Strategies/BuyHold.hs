{-# LANGUAGE OverloadedStrings #-}
-- | Equal-weight buy and hold over the universe. The benchmark every other
-- strategy is measured against.
module Quant.Strategies.BuyHold
  ( buyHold
  ) where

import Quant.Core.Matrix (generate)
import Quant.Strategy
import Quant.Types

buyHold :: [Symbol] -> Bps -> Strategy
buyHold universe cost = Strategy
  { stratName = "buy-hold"
  , stratUniverse = universe
  , stratWeights = \input ->
      let t = panelLength (siPrices input)
          n = length universe
      in generate t n (\_ _ -> 1 / fromIntegral n)
  , stratRebalance = EveryBar
  , stratFill = NextClose
  , stratCosts = CostModel cost
  }
