# Quant

미국 매크로 지표로 **상태 벡터**와 **메타지수**를 만들고, 그 수치로 국면을 나눠 우량주 바스켓과 안전자산의 비중을 조절하는 개인용 퀀트 리서치 프로젝트입니다. 속도가 필요한 수치 커널은 **C**, 지표 정의와 전략과 파이프라인은 **Haskell**로 짭니다. 용도는 실제 개인 투자, 취미, 그리고 퀀트 리서처 및 개발자 포트폴리오를 겸합니다.

> 현재 상태: 골격 단계. 세 패키지가 빌드되고, C 커널은 단위 테스트와 sanitizer를 통과하며, Haskell 테스트가 C 커널을 참조 구현과 대조합니다. `data/sample`의 **합성 데이터**로 파이프라인 전체가 오프라인에서 돕니다. 합성 데이터는 난수라서 그 위의 백테스트 수치는 아무 의미가 없습니다.

---

## 1. 퀀트 시스템의 일반 구조

시스템은 데이터가 흐르는 파이프라인이고 각 단계가 모듈 하나입니다.

| 단계 | 하는 일 | 이 저장소의 모듈 |
|---|---|---|
| 데이터 | 시세와 매크로 지표 수집, 캐시, 발표일 기준 정렬 | `Quant.Data.*` |
| 시그널 | 지표를 정상 시계열로 변환하고 표준화해 종목별 또는 지표별 점수를 만듦 | `Quant.Indicator`, `Quant.State`, `Quant.MetaIndex` |
| 국면 | 상태 벡터의 기하적 특성으로 시장 국면을 판정 | `Quant.Regime` |
| 포트폴리오 구성 | 점수와 국면을 목표 비중으로 변환 | `Quant.Strategy`, `Quant.Strategies.*` |
| 실행 | 목표 비중을 체결로 바꿈. 백테스트는 시뮬레이터, 실거래는 증권사 어댑터 | `Quant.Core.Simulate`, 어댑터는 로드맵 |
| 평가 | 수익률 곡선에서 지표를 뽑고 과적합을 검증 | `Quant.Metrics`, `Quant.Report` |

전략 하나는 여섯 요소로 해부됩니다. 유니버스, 시그널, 비중 규칙, 리밸런스 주기, 체결 가정, 비용 모델. `Quant.Strategy`의 `Strategy` 레코드가 이 여섯 개를 필드로 강제합니다.

엔진은 **벡터화 방식**입니다. 전 기간의 목표 비중 행렬을 한 번에 만들고 C 시뮬레이터가 손익을 한 번에 계산합니다. 실거래도 매일 파이프라인을 다시 돌려 마지막 행의 비중을 현재 포지션과 비교하면 되므로, 백테스트와 실거래가 같은 코드를 씁니다.

설계에 못 박은 함정 세 가지:

- **미래 참조.** `weights[t]`는 t 종가에 결정되어 t+1 수익률에만 적용됩니다. 시뮬레이터 계약에 이 한 칸 시프트가 들어 있고 C 테스트가 검증합니다. 지표는 관측일이 아니라 **발표일** 기준으로 정렬됩니다 (`Quant.Data.Align`).
- **생존 편향.** 유니버스는 시점별 함수로 두도록 타입을 잡았습니다. 현재는 고정 목록입니다.
- **과적합.** 메타지수 가중치는 동일가중 또는 PCA처럼 자유 파라미터가 없는 방식이 기본입니다. 거래할 자산에 맞춰 가중치를 피팅하지 않습니다.

## 2. 이 프로젝트의 아이디어: 메타지수와 국면

지표 여러 개를 각각의 차원으로 하는 벡터에 가중치를 주어 하나의 수치를 만들고, 그 벡터 구름의 형태 변화로 국면을 읽고, 특정 지표 조합과 추이가 닮은 종목을 찾는다는 발상입니다. 기존 용어로 옮기면 세 가지가 됩니다.

| 직관 | 기존 개념 | 구현 |
|---|---|---|
| 지표 벡터의 가중합 | 금융여건지수 (NFCI, GS FCI) | `Quant.MetaIndex`: `M_t = w · s_t`, `Equal` / `PCA` / `Fixed` |
| 벡터 구름의 형태 변화 | 국면 탐지: Kritzman의 turbulence index, absorption ratio, 군집, 위상 데이터 분석 | `Quant.Regime`: Mahalanobis 거리, 고유값 집중도, 임계값 라벨 |
| 특정 조합과 닮은 종목 | 매크로 팩터 노출, 매크로 베타 | `Quant.Exposure`: 롤링 OLS 베타 벡터, 코사인 유사도 |

상태 벡터의 정의는 [docs/methodology.md](docs/methodology.md)에 고정해 두었습니다. 요약하면 지표별로 변환(수익률 또는 변화분), 롤링 z-score, 부호 통일(양수 = 위험 선호)을 거친 값이 `s_t`의 성분입니다. 기본 지표 열 개는 `Quant.Indicators`에 있습니다. S&P 500, VIX, 10년물, 장단기 스프레드, 하이일드 스프레드, 기대인플레이션, 달러지수, 원유, 신규 실업수당 청구, 금.

첫 목표는 하나입니다. 동일가중 메타지수를 만들어 NFCI와 상관을 확인하고, 그 지수로 우량주 바스켓과 단기채 비중을 조절한 결과가 S&P 500 단순 보유보다 **최대낙폭이 작은지** 보는 것입니다. 이 전략류에서 현실적인 성과는 수익률 초과가 아니라 낙폭 축소입니다.

위상 데이터 분석은 turbulence와 absorption ratio가 자리를 잡은 뒤 추가 특성 하나로 붙입니다. 단독 시그널로 기대하지 않습니다.

## 3. C와 Haskell의 분업

**C가 맡는 것** (`core/cbits`): 배열을 넣고 배열을 받는 순수 수치 커널.

- `series.c` 수익률, 변화분, 롤링 평균, 표준편차, z-score, EWMA. O(n) 러닝 섬, 상쇄 오차 방지용 시프트.
- `stats.c` 공분산, 상관, OLS (정규방정식 + Cholesky).
- `linalg.c` Cholesky, 대칭행렬 역행렬, Jacobi 고유값 분해.
- `regime.c` Mahalanobis 거리, absorption ratio.
- `simulate.c` 비중 행렬을 받아 자산곡선, 회전율, 비용을 계산.

**Haskell이 맡는 것** (`lib/src`): 판단이 들어가는 모든 것. 타입과 단위, 데이터 로딩과 정렬, 지표 정의, 전략, 백테스트 드라이버, 지표 산출, 리포트, CLI.

**경계 원칙.** 이 조합의 성패가 갈리는 지점입니다.

- 호출 단위는 시계열 전체 또는 패널 전체. 봉 하나마다 C를 부르지 않습니다.
- C API는 `double *`, 길이, 정수 반환 코드만 씁니다. 구조체, 콜백, 할당이 경계를 넘지 않습니다.
- 출력 버퍼는 Haskell이 할당합니다 (`Data.Vector.Storable`, 복사 없이 포인터 전달). 어느 쪽도 상대의 메모리를 해제하지 않습니다.
- 패널은 row-major `[T][K]`. 이 규약을 아는 Haskell 모듈은 `Quant.Core.Matrix` 하나입니다.
- `foreign import`는 `Quant.Core.FFI` 한 곳에만 있고 전부 `unsafe`입니다. 커널이 짧고 콜백이 없기 때문입니다.
- C 커널은 두 번 검증됩니다. `core/ctest`의 골든 값 테스트, 그리고 `lib/test/CoreVsReferenceSpec.hs`에서 순수 Haskell 참조 구현(`lib/test/Reference/`)과 QuickCheck로 대조.
- 행렬 루틴은 할당 없이 고정 스택 버퍼를 쓰며 최대 64차원(`QC_MAX_DIM`)입니다. 매크로 상태 벡터에는 충분하고 FFI 스레드 스택에서 안전합니다.

**솔직한 평가.** 일봉 기준 개인 투자 규모라면 순수 Haskell로도 속도는 충분합니다. C 계층의 정당성은 성능보다 학습, 포트폴리오, 그리고 같은 커널을 Python 등 다른 언어에서 재사용할 수 있다는 점에 있습니다. 그래서 C의 범위를 커널 밖으로 넓히지 않는 것이 규칙입니다. 또 Haskell에는 pandas와 matplotlib에 해당하는 탐색 도구가 없으므로 결과는 CSV와 JSON으로 떨어뜨리고 그림은 `research/`의 Python에서 그립니다.

## 4. 디렉터리 구조

```
Quant/
├── cabal.project               # packages: core/ lib/ cli/
├── Makefile                    # 작업 실행기: build test ctest asan smoke fetch state backtest install
├── core/                       # quant-core: C 커널 + FFI 바인딩
│   ├── include/qcore/          # qcore.h series.h stats.h linalg.h regime.h simulate.h
│   ├── cbits/                  # 헤더와 1:1 대응하는 C11 구현
│   ├── ctest/                  # C 단위 테스트 (의존성 없는 자체 하네스)
│   ├── Makefile                # libqcore.a / .so / .dylib 단독 빌드, C 테스트, sanitizer
│   └── src/Quant/Core/         # FFI.hs Matrix.hs Error.hs + Series Stats Linalg Regime Simulate 래퍼
├── lib/                        # quant: 도메인 라이브러리 (순수 Haskell)
│   ├── src/Quant/
│   │   ├── Types.hs            # Symbol, SeriesId, Sign, Window, Bps, TimeSeries, Panel
│   │   ├── Data/               # Csv Fred Prices Cache Calendar Align
│   │   ├── Indicator.hs        # 지표 정의 타입: 소스, 변환, 부호, 발표 지연, z 창
│   │   ├── Indicators.hs       # 기본 지표 열 개
│   │   ├── State.hs            # 상태 벡터 패널 생성
│   │   ├── MetaIndex.hs        # Equal | PCA | Fixed 가중
│   │   ├── Regime.hs           # turbulence, absorption, 국면 라벨
│   │   ├── Exposure.hs         # 종목 베타 벡터, 코사인 유사도
│   │   ├── Strategy.hs         # Strategy 레코드, 리밸런스 스케줄
│   │   ├── Strategies/         # BuyHold.hs RegimeTilt.hs
│   │   ├── Backtest.hs         # 스케줄 적용 후 C 시뮬레이터 호출
│   │   ├── Metrics.hs          # CAGR, 변동성, 샤프, 최대낙폭, 회전율
│   │   └── Report.hs           # runs/ 아래 equity.csv, summary.json
│   └── test/                   # hspec + QuickCheck, Reference/ 는 C 커널의 정답지
├── cli/app/Main.hs             # quant fetch | state | backtest | version
├── config/strategies/          # 전략 파라미터 JSON (임계값, 비중, 주기, 비용)
├── data/
│   ├── sample/                 # 합성 데이터. 오프라인 실행과 CI 용
│   ├── cache/                  # quant fetch 가 채움 (gitignore)
│   └── raw/                    # 수동 반입 원본 (gitignore)
├── runs/                       # 백테스트 결과 (gitignore)
├── research/                   # Python: 그림 그리기, 샘플 데이터 생성 스크립트
├── docs/                       # architecture.md methodology.md
└── .github/workflows/ci.yml    # ubuntu + macos 매트릭스
```

의존 방향은 아래로만 흐릅니다. `quant-cli` → `quant` → `quant-core` → `base`, `vector`.

### 코드, 설정, 데이터의 구분

| 종류 | 예 | 위치 | 읽는 시점 |
|---|---|---|---|
| 코드 | 커널, 지표 정의, 전략 로직 | 저장소, 바이너리에 컴파일됨 | 빌드 |
| 설정 | 임계값, 비중, 리밸런스 주기, 비용 | `config/` 또는 `~/.config/quant/` | 실행 |
| 데이터 | 시세, 지표 캐시, 결과 | `data/cache`, `runs/`, 설치 후엔 `~/.local/share/quant` | 실행 |

전략은 데이터가 아니라 코드입니다. 부호나 창 길이 같은 실수를 타입 검사가 잡고, git 이력이 어떤 커밋에서 어떤 결과가 나왔는지 남기기 때문입니다. 같은 전략의 파라미터 변형은 설정 파일을 늘려서 표현합니다. 비공개 운용 전략을 이 공개 저장소와 분리하려면, 별도 저장소에 `quant`에 의존하는 패키지를 하나 더 두고 그쪽 `cabal.project`가 이 저장소를 경로나 git 주소로 참조하게 하면 됩니다.

## 5. 빌드와 실행

**요구 사항.** GHC 9.4 이상과 cabal 3.8 이상 (ghcup 권장), C11 컴파일러 (Linux는 gcc, macOS는 Xcode 명령줄 도구의 clang), GNU make. Apple Silicon도 네이티브로 돕니다. CMake는 필요 없습니다.

**빌드 시스템은 cabal**입니다. C 소스는 `core/quant-core.cabal`의 `c-sources`에 나열되어 있어 cabal이 C 컴파일러를 직접 부릅니다. 최상위 `Makefile`은 자주 치는 명령의 이름표이고, `core/Makefile`은 C 커널을 Haskell 없이 따로 빌드해 sanitizer 테스트를 돌리거나 다른 언어용 공유 라이브러리를 뽑는 용도입니다.

```sh
make build          # cabal build all
make test           # C 단위 테스트 + cabal test all
make asan           # C 커널을 AddressSanitizer / UBSan 으로 실행
make smoke          # 합성 데이터로 buy-hold 와 regime-tilt 백테스트

make fetch          # FRED 지표와 가격을 data/cache 에 내려받음 (API 키 불필요)
make state          # 상태 패널과 메타지수를 runs/state.csv 로
make backtest       # config/strategies/regime-tilt.json 으로 백테스트

make install        # ~/.cabal/bin/quant 설치. cron 이나 launchd 에서 호출
```

CLI를 직접 부를 때는 실행 파일을 `exe:quant`로 지정합니다 (`quant`만 쓰면 같은 이름의 라이브러리 패키지와 겹칩니다).

```sh
cabal run exe:quant -- backtest --data data/sample --strategy buy-hold --symbols SPY
cabal run exe:quant -- backtest --data data/sample --strategy regime-tilt \
    --config config/strategies/regime-tilt.json --weighting pca
cabal run exe:quant -- state --data data/sample --out runs/state.csv
```

`backtest`는 지표를 표로 출력하고 `runs/<날짜>/<전략>/equity.csv`와 `summary.json`을 남깁니다. `state`는 상태 패널 CSV와 `.meta.csv`를 남깁니다. 노트북은 이 파일들을 읽기만 합니다.

**데이터 소스.** 매크로 지표는 FRED의 `fredgraph.csv` 엔드포인트(키 불필요), 가격은 Stooq 일봉 CSV입니다. 둘 다 `data/cache` 아래 원본 그대로 캐시됩니다. FRED 시리즈 ID는 `Quant.Indicators`에 있으니 사용 전 FRED에서 확인하세요. 이름이 바뀐 시리즈는 조용히 전부 NaN이 됩니다.

## 6. 로드맵

1. 롤링(표본 외) turbulence와 absorption. 현재 구현은 전체 표본 평균과 공분산을 써서 설명용이며 백테스트 안에서 쓰면 미래 참조입니다.
2. ALFRED 빈티지로 실제 발표일 반영. 현재는 지표별 고정 지연 일수.
3. NYSE 휴장일 캘런더 (데이터 파일로).
4. 종목별 매크로 베타 벡터와 유사도 순위를 CLI에 노출. 커널과 라이브러리 함수는 있고 명령만 없음.
5. 워크포워드 평가.
6. 증권사 어댑터와 모의투자. Linux와 macOS에서 돌리려면 REST와 웹소켓 기반 API가 필요합니다.

## 라이센스

GPL-3.0-or-later. `LICENSE` 참조.
