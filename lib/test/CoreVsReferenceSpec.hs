-- | The C kernels must agree with the naive Haskell reference implementations.
module CoreVsReferenceSpec (spec) where

import qualified Data.Vector.Storable as VS
import Test.Hspec
import Test.QuickCheck

import qualified Quant.Core.Series as S
import Reference.Series

-- | Finite doubles in a range where neither implementation loses precision.
newtype Series = Series [Double] deriving Show

instance Arbitrary Series where
  arbitrary = do
    n <- chooseInt (1, 60)
    Series <$> vectorOf n (choose (-1000, 1000))

-- | Equal up to tolerance, with NaN matching NaN.
agree :: Double -> Double -> Bool
agree a b
  | isNaN a && isNaN b = True
  | isNaN a || isNaN b = False
  | otherwise = abs (a - b) <= 1e-9 * max 1 (max (abs a) (abs b))

agreeAll :: [Double] -> [Double] -> Bool
agreeAll as bs = length as == length bs && and (zipWith agree as bs)

withWindow :: Int -> Series -> Gen Int
withWindow lo (Series xs) = chooseInt (lo, length xs)

spec :: Spec
spec = describe "C kernels vs Haskell reference" $ do
  it "diff" $ property $ \(Series xs) ->
    VS.toList (S.diff (VS.fromList xs)) `agreeAll` diffRef xs

  it "returns" $ property $ \(Series xs) ->
    VS.toList (S.returns (VS.fromList xs)) `agreeAll` returnsRef xs

  it "rollingMean" $ property $ \s@(Series xs) -> forAll (withWindow 1 s) $ \w ->
    VS.toList (S.rollingMean w (VS.fromList xs)) `agreeAll` rollingMeanRef w xs

  it "rollingStd" $ property $ \s@(Series xs) -> length xs >= 2 ==> forAll (withWindow 2 s) $ \w ->
    VS.toList (S.rollingStd w (VS.fromList xs)) `agreeAll` rollingStdRef w xs

  it "rollingZScore" $ property $ \s@(Series xs) -> length xs >= 2 ==> forAll (withWindow 2 s) $ \w ->
    VS.toList (S.rollingZScore w (VS.fromList xs)) `agreeAll` rollingZScoreRef w xs

  it "rollingMean propagates NaN through touching windows only" $
    let xs = VS.fromList [1, 2, 0 / 0, 4, 5, 6]
        out = VS.toList (S.rollingMean 2 xs)
    in map isNaN out `shouldBe` [True, False, True, True, False, False]
