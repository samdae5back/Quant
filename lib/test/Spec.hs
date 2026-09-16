module Main (main) where

import Test.Hspec

import qualified AlignSpec
import qualified BacktestSpec
import qualified CoreVsReferenceSpec
import qualified MetricsSpec

main :: IO ()
main = hspec $ do
  CoreVsReferenceSpec.spec
  AlignSpec.spec
  MetricsSpec.spec
  BacktestSpec.spec
