module TechnicalSpec (spec) where

import qualified Data.Vector.Storable as VS
import Test.Hspec

import Quant.Technical

near :: Double -> Double -> Bool
near a b = abs (a - b) < 1e-9

spec :: Spec
spec = describe "Quant.Technical" $ do
  it "sma is the trailing mean with a NaN warm-up" $ do
    let out = VS.toList (sma 3 (VS.fromList [1, 2, 3, 4, 5]))
    map isNaN (take 2 out) `shouldBe` [True, True]
    drop 2 out `shouldSatisfy` and . zipWith near [2, 3, 4]

  it "momentum is the trailing total return" $ do
    let out = VS.toList (momentum 2 (VS.fromList [100, 110, 121, 121]))
    map isNaN (take 2 out) `shouldBe` [True, True]
    out !! 2 `shouldSatisfy` near 0.21          -- 121 / 100 - 1
    out !! 3 `shouldSatisfy` near 0.1           -- 121 / 110 - 1

  it "momentum is NaN when the base price is missing" $ do
    let out = VS.toList (momentum 1 (VS.fromList [0 / 0, 100, 105]))
    map isNaN (take 2 out) `shouldBe` [True, True]
    out !! 2 `shouldSatisfy` near 0.05

  it "realizedVol annualises the std of daily returns" $ do
    -- alternating +10% / -10% moves: sample std of returns is 0.1 * sqrt(4/3)
    let xs = VS.fromList [100, 110, 99, 108.9, 98.01]
        out = VS.toList (realizedVol 4 xs)
        rets = [0.1, -0.1, 0.1, -0.1]
        mu = sum rets / 4
        sd = sqrt (sum [(r - mu) ^ (2 :: Int) | r <- rets] / 3)
    map isNaN (take 4 out) `shouldBe` [True, True, True, True]
    out !! 4 `shouldSatisfy` near (sd * sqrt 252)
