module MetricsSpec (spec) where

import qualified Data.Vector.Storable as VS
import Test.Hspec

import Quant.Metrics

spec :: Spec
spec = describe "Quant.Metrics" $ do
  it "maxDrawdown finds the deepest peak-to-trough fall" $
    maxDrawdown (VS.fromList [1, 1.2, 0.9, 1.1, 0.6, 1.3]) `shouldSatisfy` (\x -> abs (x - (0.6 / 1.2 - 1)) < 1e-12)

  it "maxDrawdown of a rising curve is zero" $
    maxDrawdown (VS.fromList [1, 2, 3]) `shouldBe` 0

  it "cagr of doubling over one trading year is 100%" $
    cagr (VS.fromList (replicate 252 1 ++ [2])) `shouldSatisfy` (\x -> abs (x - 1) < 1e-9)

  it "sharpe of a flat curve is zero" $
    sharpe (VS.replicate 10 1) `shouldBe` 0
