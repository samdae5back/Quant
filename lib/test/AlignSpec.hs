-- | The as-of join must never show a value before its release date.
module AlignSpec (spec) where

import Data.Time.Calendar (Day, fromGregorian)
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
import Test.Hspec

import Quant.Data.Align
import Quant.Types

unsafeSeries :: [(Day, Double)] -> TimeSeries
unsafeSeries = either error id . mkTimeSeries

spec :: Spec
spec = describe "Quant.Data.Align.asOf" $ do
  let d = fromGregorian 2024 1
      -- monthly observation dated the 1st, released on the 15th
      raw = unsafeSeries [(d 1, 10), (fromGregorian 2024 2 1, 20)]
      ts = raw { tsRelease = V.fromList [d 15, fromGregorian 2024 2 15] }
      targets = V.fromList [d 2, d 14, d 15, d 31, fromGregorian 2024 2 14, fromGregorian 2024 2 15]

  it "hides a value until its release date" $ do
    let out = VS.toList (asOf targets ts)
    map isNaN (take 2 out) `shouldBe` [True, True]
    drop 2 out `shouldBe` [10, 10, 10, 20]

  it "lagRelease pushes visibility further out" $ do
    let out = VS.toList (asOfWithLag 1 targets ts)
    map isNaN (take 3 out) `shouldBe` [True, True, True]
    out !! 3 `shouldBe` 10

  it "forward-fills daily data over gaps" $ do
    let daily = unsafeSeries [(d 1, 1), (d 3, 3)]
        out = VS.toList (asOf (V.fromList [d 1, d 2, d 3, d 4]) daily)
    out `shouldBe` [1, 1, 3, 3]
